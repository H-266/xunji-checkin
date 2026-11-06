import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/app_strings.dart';
import '../core/date_utils.dart';
import '../data/app_database.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import 'platform_service.dart';

/// 本地 JSON 备份。
///
/// 数据直接来自 SQLite，不经过网络；文件写入使用 Android SAF，
/// 因此不需要申请任何存储权限。
class ExportService {
  ExportService._();

  static Future<ExportOutcome> export({
    required SettingsProvider settings,
  }) async {
    final json = await buildJson(settings: settings);
    final fileName =
        '${AppStrings.exportPrefix}-${AppDateUtils.formatKey(DateTime.now())}.json';
    final uri = await PlatformService.exportJson(
      json: json,
      fileName: fileName,
    );
    return ExportOutcome(uri: uri, cancelled: uri == null);
  }

  /// 生成与手动导出完全一致的 JSON，供自动备份复用。
  static Future<String> buildJson({required SettingsProvider settings}) async {
    final db = AppDatabase.instance;
    final tasks = await db.loadAllTasks();
    final checkins = await db.loadAllCheckins();
    final tags = await db.loadTags();
    final storedSettings = await db.loadSettings();

    final payload = <String, Object?>{
      'app': '循记打卡',
      'format_version': 1,
      // 使用 UTC + Z，确保导出的时间戳是带时区的标准 ISO-8601。
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tasks': tasks.map(_taskToJson).toList(growable: false),
      'tags': tags
          .map(
            (tag) => <String, Object?>{
              'id': tag.id,
              'name': tag.name,
              'color': tag.color,
              'created_at': tag.createdAt,
            },
          )
          .toList(growable: false),
      'checkins': checkins
          .map(
            (record) => <String, Object?>{
              'task_id': record.taskId,
              'date': record.date,
              'completed_ts': record.completedTs,
              'remark': record.remark,
            },
          )
          .toList(growable: false),
      // 即使用户从未改过设置，也导出当前生效值，便于日后恢复。
      'settings': <String, Object?>{
        ...storedSettings,
        'heatmap_hue':
            storedSettings['heatmap_hue'] ?? settings.hue.toStringAsFixed(1),
        'theme_mode': storedSettings['theme_mode'] ?? settings.themeMode.name,
        'font_scale':
            storedSettings['font_scale'] ??
            settings.fontScale.toStringAsFixed(2),
      },
    };

    // JSON 序列化可能包含数百条任务/打卡，放到后台 isolate，
    // 避免导出/自动备份时卡住 UI 线程。
    return compute(_encodeJson, payload);
  }

  static Map<String, Object?> _taskToJson(Task task) {
    return <String, Object?>{
      'id': task.id,
      'title': task.title,
      'type': task.type.dbValue,
      'created_at': task.createdAt,
      'completed_at': task.completedAt,
      'archived_at': task.archivedAt,
      'sort_order': task.sortOrder,
      'schedule_type': task.schedule.dbValue,
      'weekly_target': task.weeklyTarget,
      'weekday_mask': task.weekdayMask,
      'tag_id': task.tagId,
      'reminder_time': task.reminderTime,
      'reminder_enabled': task.reminderEnabled,
      'reminder_effective_only': task.reminderEffectiveOnly,
      'due_at': task.dueAt,
    };
  }
}

String _encodeJson(Map<String, Object?> payload) =>
    const JsonEncoder.withIndent('  ').convert(payload);

class ExportOutcome {
  const ExportOutcome({required this.uri, required this.cancelled});

  final String? uri;
  final bool cancelled;

  bool get success => !cancelled && uri != null;
}
