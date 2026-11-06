import '../core/app_strings.dart';
import '../core/date_utils.dart';
import '../core/stats.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import 'platform_service.dart';

/// CSV 导出类型。
enum CsvKind {
  checkins('打卡明细', 'checkins'),
  daily('每日统计', 'daily'),
  tasks('任务汇总', 'tasks'),
  tags('标签汇总', 'tags'),
  periods('周期汇总', 'periods');

  const CsvKind(this.label, this.slug);

  final String label;
  final String slug;
}

/// 纯本地 CSV 导出：三类数据分别生成，经 SAF 保存，不申请存储权限。
///
/// 统一使用 UTF-8 BOM，Excel/WPS 打开中文列头不会乱码；所有字段都做
/// CSV 转义，备注里的逗号、引号、换行不会破坏表格结构。
class CsvExportService {
  const CsvExportService._();

  static Future<String?> export(
    TaskProvider provider,
    CsvKind kind, {
    DateTime? now,
  }) async {
    final content = build(provider, kind, now: now);
    final stamp = AppDateUtils.formatKey(now ?? DateTime.now());
    return PlatformService.exportJson(
      json: content,
      fileName: '${AppStrings.exportPrefix}-$stamp-${kind.slug}.csv',
      mimeType: 'text/csv',
    );
  }

  static String build(TaskProvider provider, CsvKind kind, {DateTime? now}) {
    final today = now ?? DateTime.now();
    switch (kind) {
      case CsvKind.checkins:
        return _checkins(provider);
      case CsvKind.daily:
        return _daily(provider, today);
      case CsvKind.tasks:
        return _tasks(provider, today);
      case CsvKind.tags:
        return _tags(provider);
      case CsvKind.periods:
        return _periods(provider);
    }
  }

  static String _checkins(TaskProvider provider) {
    final rows = <List<String>>[
      const ['task_id', 'task_title', 'date', 'completed_at', 'remark'],
    ];
    final records = [...provider.allCheckinRecords]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.taskId.compareTo(b.taskId);
      });
    for (final record in records) {
      final task = provider.allTasks
          .where((item) => item.id == record.taskId)
          .firstOrNull;
      final time = AppDateUtils.timeLabel(
        DateTime.fromMillisecondsSinceEpoch(record.completedTs),
      );
      rows.add([
        '${record.taskId}',
        task?.title ?? 'deleted_task',
        record.date,
        time,
        record.remark ?? '',
      ]);
    }
    return _encode(rows);
  }

  static String _daily(TaskProvider provider, DateTime today) {
    final rows = <List<String>>[
      const [
        'date',
        'active_tasks',
        'completed',
        'completion_rate',
        'perfect_day',
      ],
    ];
    final first = provider.allTasks
        .map((task) => AppDateUtils.dayOnly(task.createdDate))
        .fold<DateTime?>(null, (earliest, day) {
          if (earliest == null || day.isBefore(earliest)) return day;
          return earliest;
        });
    if (first != null) {
      var cursor = first;
      final end = AppDateUtils.dayOnly(today);
      while (!cursor.isAfter(end)) {
        final stat = provider.statsFor(cursor);
        if (stat.hasTasks) {
          rows.add([
            AppDateUtils.formatKey(cursor),
            '${stat.total}',
            '${stat.completed}',
            '${(stat.rate * 100).round()}%',
            stat.isPerfect ? 'true' : 'false',
          ]);
        }
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }
    }
    return _encode(rows);
  }

  static String _tasks(TaskProvider provider, DateTime today) {
    final rows = <List<String>>[
      const [
        'task_id',
        'title',
        'type',
        'schedule',
        'schedule_params',
        'total_days',
        'current_streak',
        'longest_streak',
        'archived',
      ],
    ];
    for (final task in provider.allTasks) {
      final stats = task.type == TaskType.daily
          ? provider.taskStats(task)
          : TaskStats.empty;
      rows.add([
        '${task.id ?? ''}',
        task.title,
        task.type.dbValue,
        task.schedule.dbValue,
        _scheduleDetail(task),
        '${task.type == TaskType.todo && task.completedAt != null ? 1 : stats.totalDays}',
        '${stats.currentStreak}',
        '${task.type == TaskType.todo && task.completedAt != null ? 1 : stats.longestStreak}',
        task.isArchived ? 'true' : 'false',
      ]);
    }
    return _encode(rows);
  }

  static String _tags(TaskProvider provider) {
    final rows = <List<String>>[
      const ['tag', 'total_days', 'average_rate', 'longest_streak'],
    ];
    for (final item in provider.tagPerformance) {
      rows.add([
        item.name,
        '${item.totalDays}',
        '${item.percent}%',
        '${item.longestStreak}',
      ]);
    }
    return _encode(rows);
  }

  static String _periods(TaskProvider provider) {
    final rows = <List<String>>[
      const ['schedule', 'tasks', 'total_days'],
    ];
    for (final schedule in TaskSchedule.values) {
      final tasks = provider.allTasks
          .where(
            (task) => task.type == TaskType.daily && task.schedule == schedule,
          )
          .toList(growable: false);
      if (tasks.isEmpty) continue;
      var days = 0;
      for (final task in tasks) {
        days += provider.taskStats(task).totalDays;
      }
      rows.add([schedule.label, '${tasks.length}', '$days']);
    }
    return _encode(rows);
  }

  static String _scheduleDetail(Task task) {
    return switch (task.schedule) {
      TaskSchedule.daily => '每天',
      TaskSchedule.weeklyTarget => '每周 ${task.weeklyTarget} 天',
      TaskSchedule.weekdays => '星期掩码 ${task.weekdayMask}',
      TaskSchedule.intervalDays => '每 ${task.intervalDays} 天',
      TaskSchedule.monthlyDays => '每月掩码 ${task.monthDaysMask}',
      TaskSchedule.yearlyDate => '${task.yearlyMonth}月${task.yearlyDay}日',
    };
  }

  static String _encode(List<List<String>> rows) {
    final buffer = StringBuffer('\uFEFF');
    for (final row in rows) {
      buffer.writeln(row.map(_cell).join(','));
    }
    return buffer.toString();
  }

  static String _cell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }
}
