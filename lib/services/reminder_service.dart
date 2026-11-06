import '../core/date_utils.dart';
import '../models/task.dart';
import 'platform_service.dart';

/// 本地提醒同步。
///
/// 不依赖任何云服务，也不申请精确闹钟权限；原生侧使用
/// `setAndAllowWhileIdle` 的普通闹钟，系统可能延迟几分钟。
class ReminderService {
  ReminderService._();

  /// 把所有启用提醒的未归档任务交给原生侧重新排程。
  ///
  /// 每日任务按天重复；临时待办只提醒一次。`effective_only` 为 true 时，
  /// 原生侧会跳过自定义周期里的非生效日。
  static Future<void> sync(List<Task> tasks) async {
    final payload = <Map<String, Object?>>[];
    for (final task in tasks) {
      if (task.isArchived ||
          !task.reminderEnabled ||
          task.reminderTime == null ||
          task.id == null) {
        continue;
      }
      payload.add(<String, Object?>{
        'id': task.id,
        'title': task.title,
        'time': task.reminderTime,
        'repeat': task.isDaily,
        'effective_only':
            task.isDaily &&
            task.reminderEffectiveOnly &&
            task.schedule != TaskSchedule.daily &&
            task.schedule != TaskSchedule.weeklyTarget,
        'schedule': task.schedule.dbValue,
        'weekday_mask': task.weekdayMask,
        'interval_days': task.intervalDays,
        'month_days_mask': task.monthDaysMask,
        'yearly_month': task.yearlyMonth,
        'yearly_day': task.yearlyDay,
        'created_date': AppDateUtils.formatKey(task.createdDate),
      });
    }
    await PlatformService.syncReminders(payload);
  }

  static Future<bool> ensurePermission() async {
    if (await PlatformService.areNotificationsEnabled()) return true;
    return PlatformService.requestNotificationPermission();
  }
}
