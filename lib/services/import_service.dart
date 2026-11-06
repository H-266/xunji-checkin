import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';

/// 导入方式。
enum ImportMode { overwrite, append }

/// 校验后的备份内容。所有字段仍是原始 Map，真正写库前不会碰现有数据。
class ImportPreview {
  final List<Map<String, Object?>> tasks;
  final List<Map<String, Object?>> checkins;
  final List<Map<String, Object?>> tags;
  final Map<String, String> settings;
  final String exportedAt;

  const ImportPreview({
    required this.tasks,
    required this.checkins,
    required this.tags,
    required this.settings,
    required this.exportedAt,
  });

  int get taskCount => tasks.length;
  int get checkinCount => checkins.length;
  int get tagCount => tags.length;
}

class ImportException implements Exception {
  final String message;
  const ImportException(this.message);
  @override
  String toString() => message;
}

class ImportResult {
  final int tasks;
  final int checkins;
  final int tags;
  const ImportResult({
    required this.tasks,
    required this.checkins,
    required this.tags,
  });
}

/// JSON 备份导入。
///
/// 设计原则：
/// 1. 先完整校验，再在一个事务里写入；异常时现有数据不受影响。
/// 2. 追加导入会重新分配任务 id，并重写 checkins 的外键。
/// 3. 覆盖导入保留“新手引导已看过”标记，避免用户被再次打扰。
class ImportService {
  ImportService._();

  static const int _maxTasks = 20000;
  static const int _maxCheckins = 300000;

  /// 在后台 isolate 解析，导入大文件时主线程保持可交互。
  static Future<ImportPreview> parseAsync(String raw) => compute(parse, raw);

  static ImportPreview parse(String raw) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const ImportException('文件不是有效的 JSON');
    }
    if (decoded is! Map) {
      throw const ImportException('备份根节点必须是 JSON 对象');
    }
    final root = decoded.cast<String, Object?>();
    final version = root['format_version'];
    if (version is! num || version.toInt() != 1) {
      throw const ImportException('暂不支持这个备份版本');
    }

    final rawTasks = _list(root['tasks'], 'tasks');
    final rawCheckins = _list(root['checkins'], 'checkins');
    final rawTags = _list(root['tags'], 'tags');
    if (rawTasks.length > _maxTasks || rawCheckins.length > _maxCheckins) {
      throw const ImportException('备份数据量异常，已停止导入');
    }

    final taskIds = <int>{};
    final tasks = <Map<String, Object?>>[];
    for (final item in rawTasks) {
      final map = _map(item, 'tasks');
      final id = _int(map['id'], 'tasks.id');
      if (id == null || id <= 0) {
        throw const ImportException('任务 id 无效');
      }
      if (!taskIds.add(id)) {
        throw ImportException('任务 id 重复：$id');
      }
      final title = _string(map['title'], 'tasks.title');
      final type = _string(map['type'], 'tasks.type');
      if (title == null || title.trim().isEmpty) {
        throw const ImportException('存在没有标题的任务');
      }
      if (type != 'daily' && type != 'todo') {
        throw ImportException('任务类型无效：$type');
      }
      tasks.add(<String, Object?>{
        'id': id,
        'title': title.trim(),
        'type': type,
        'created_at': _int(map['created_at'], 'tasks.created_at') ?? 0,
        'completed_at': _int(map['completed_at'], 'tasks.completed_at'),
        'archived_at': _int(map['archived_at'], 'tasks.archived_at'),
        'sort_order': _int(map['sort_order'], 'tasks.sort_order') ?? 0,
        'schedule_type': _schedule(map['schedule_type']),
        'weekly_target':
            (_int(map['weekly_target'], 'tasks.weekly_target') ?? 7).clamp(
              1,
              7,
            ),
        'weekday_mask':
            (_int(map['weekday_mask'], 'tasks.weekday_mask') ?? 127) & 0x7F,
        // 旧备份没有这些字段时给出每日/1 号默认值，保持向前兼容。
        'interval_days':
            (_int(map['interval_days'], 'tasks.interval_days') ?? 1).clamp(
              1,
              365,
            ),
        'month_days_mask':
            (_int(map['month_days_mask'], 'tasks.month_days_mask') ?? 1) &
            0x7FFFFFFF,
        'yearly_month': _int(map['yearly_month'], 'tasks.yearly_month'),
        'yearly_day': _int(map['yearly_day'], 'tasks.yearly_day'),
        'tag_id': _int(map['tag_id'], 'tasks.tag_id'),
        'reminder_time': _string(map['reminder_time'], 'tasks.reminder_time'),
        'reminder_enabled':
            (_int(map['reminder_enabled'], 'tasks.reminder_enabled') ?? 0) != 0
            ? 1
            : 0,
        'reminder_effective_only':
            (_int(
                      map['reminder_effective_only'],
                      'tasks.reminder_effective_only',
                    ) ??
                    0) !=
                0
            ? 1
            : 0,
        'due_at': _int(map['due_at'], 'tasks.due_at'),
      });
    }

    final tags = <Map<String, Object?>>[];
    for (final item in rawTags) {
      final map = _map(item, 'tags');
      final id = _int(map['id'], 'tags.id');
      final name = _string(map['name'], 'tags.name');
      if (id == null || name == null || name.trim().isEmpty) {
        throw const ImportException('标签数据无效');
      }
      tags.add(<String, Object?>{
        'id': id,
        'name': name.trim(),
        'color': _int(map['color'], 'tags.color') ?? 0xFF3B6FD4,
        'created_at': _int(map['created_at'], 'tags.created_at') ?? 0,
      });
    }

    final checkins = <Map<String, Object?>>[];
    for (final item in rawCheckins) {
      final map = _map(item, 'checkins');
      final taskId = _int(map['task_id'], 'checkins.task_id');
      final date = _string(map['date'], 'checkins.date');
      final completedTs = _int(map['completed_ts'], 'checkins.completed_ts');
      if (taskId == null || date == null || completedTs == null) {
        throw const ImportException('打卡记录字段不完整');
      }
      if (!_validDateKey(date)) {
        throw ImportException('打卡日期格式错误：$date');
      }
      if (!taskIds.contains(taskId)) {
        throw ImportException('打卡记录引用了不存在的任务：$taskId');
      }
      checkins.add(<String, Object?>{
        'task_id': taskId,
        'date': date,
        'completed_ts': completedTs,
        'remark': _string(map['remark'], 'checkins.remark'),
      });
    }

    final settings = <String, String>{};
    final rawSettings = root['settings'];
    if (rawSettings is Map) {
      for (final entry in rawSettings.entries) {
        if (entry.key is String && entry.value != null) {
          settings[entry.key as String] = entry.value.toString();
        }
      }
    }

    return ImportPreview(
      tasks: tasks,
      checkins: checkins,
      tags: tags,
      settings: settings,
      exportedAt: root['exported_at']?.toString() ?? '',
    );
  }

  static Future<ImportResult> apply(
    ImportPreview preview,
    ImportMode mode,
  ) async {
    final db = await AppDatabase.instance.database;
    late ImportResult result;
    await db.transaction((txn) async {
      if (mode == ImportMode.overwrite) {
        await txn.delete('checkins');
        await txn.delete('tasks');
        await txn.delete('tags');
        for (final tag in preview.tags) {
          await txn.insert(
            'tags',
            tag,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final task in preview.tasks) {
          await txn.insert(
            'tasks',
            task,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final checkin in preview.checkins) {
          await txn.insert(
            'checkins',
            checkin,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final entry in preview.settings.entries) {
          if (entry.key == 'onboarding_seen') continue;
          await txn.insert('settings', <String, Object?>{
            'key': entry.key,
            'value': entry.value,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await txn.insert('settings', <String, Object?>{
          'key': 'onboarding_seen',
          'value': '1',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        result = ImportResult(
          tasks: preview.tasks.length,
          checkins: preview.checkins.length,
          tags: preview.tags.length,
        );
      } else {
        final tagMap = <int, int>{};
        for (final tag in preview.tags) {
          final oldId = tag['id'] as int;
          final name = tag['name'] as String;
          final existing = await txn.query(
            'tags',
            columns: <String>['id'],
            where: 'name = ?',
            whereArgs: <Object?>[name],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            tagMap[oldId] = existing.first['id'] as int;
          } else {
            final newTag = Map<String, Object?>.from(tag)..remove('id');
            final newId = await txn.insert('tags', newTag);
            tagMap[oldId] = newId;
          }
        }

        final taskMap = <int, int>{};
        for (final task in preview.tasks) {
          final oldId = task['id'] as int;
          final oldTag = task['tag_id'] as int?;
          final copy = Map<String, Object?>.from(task)
            ..remove('id')
            ..['tag_id'] = oldTag == null ? null : tagMap[oldTag];
          final newId = await txn.insert('tasks', copy);
          taskMap[oldId] = newId;
        }
        for (final checkin in preview.checkins) {
          final oldId = checkin['task_id'] as int;
          final newId = taskMap[oldId];
          if (newId == null) continue;
          await txn.insert('checkins', <String, Object?>{
            ...checkin,
            'task_id': newId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        result = ImportResult(
          tasks: taskMap.length,
          checkins: preview.checkins.length,
          tags: tagMap.length,
        );
      }
    });
    return result;
  }

  static List<Object?> _list(Object? value, String field) {
    if (value == null) return const <Object?>[];
    if (value is! List) {
      throw ImportException('$field 必须是数组');
    }
    return value;
  }

  static Map<String, Object?> _map(Object? value, String field) {
    if (value is! Map) throw ImportException('$field 中存在无效对象');
    return value.cast<String, Object?>();
  }

  static String? _string(Object? value, String field) {
    if (value == null) return null;
    if (value is! String) throw ImportException('$field 必须是字符串');
    return value;
  }

  static int? _int(Object? value, String field) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    throw ImportException('$field 必须是数字');
  }

  static String _schedule(Object? value) {
    return switch (value) {
      'weeklyTarget' || 'weekly' => 'weeklyTarget',
      'weekdays' || 'custom' => 'weekdays',
      'intervalDays' || 'interval' => 'intervalDays',
      'monthlyDays' || 'monthly' => 'monthlyDays',
      'yearlyDate' || 'yearly' => 'yearlyDate',
      _ => 'daily',
    };
  }

  static bool _validDateKey(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    // DateTime.parse 会把 2026-02-30 归一化成 3 月 2 日，
    // 因此必须比对归一化后的年月日，拒绝不存在的日期。
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    final parts = value.split('-').map(int.parse).toList();
    return parsed.year == parts[0] &&
        parsed.month == parts[1] &&
        parsed.day == parts[2];
  }
}
