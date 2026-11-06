import 'package:intl/intl.dart';

import 'app_strings.dart';

/// 日期工具：全部为纯函数，不读写数据库、不修改全局状态。
///
/// 跨天重置不在这里做任何“清零”动作。每日任务的完成状态由
/// `checkins(task_id, date)` 决定；换一天后日期 key 变化，自然查不到
/// 昨天的打卡记录，所以每日任务会自动显示为未完成。
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _keyFormat = DateFormat('yyyy-MM-dd');

  /// DateTime -> `yyyy-MM-dd`，用于 checkins.date 主键。
  static String formatKey(DateTime date) => _keyFormat.format(date);

  /// 今日日期主键。传入 [now] 便于单元测试。
  static String todayKey([DateTime? now]) =>
      formatKey(dayOnly(now ?? DateTime.now()));

  /// `yyyy-MM-dd` -> 当天 00:00。
  static DateTime parseKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// 只保留年月日，时间归零，避免时分秒影响“同一天”判断。
  static DateTime dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 两个时间是否落在同一个自然日。
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 沿日历计算两个日期相差的自然日数（忽略时分秒与夏令时）。
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// 当月第一天 00:00。
  static DateTime monthStart(DateTime month) =>
      DateTime(month.year, month.month);

  /// 当月最后一天 00:00。
  ///
  /// 统计时以“天”为粒度，所以不需要 23:59:59；循环条件使用
  /// `!day.isAfter(monthEnd(month))` 即可覆盖最后一天。
  static DateTime monthEnd(DateTime month) =>
      DateTime(month.year, month.month + 1, 0);

  /// 当月天数（28~31）。
  static int daysInMonth(DateTime month) => monthEnd(month).day;

  /// 加减月份，自动处理跨年。
  static DateTime addMonths(DateTime month, int delta) =>
      DateTime(month.year, month.month + delta);

  /// 日历格子从周一开始，返回 date 所在周的周一。
  static DateTime weekStart(DateTime date) {
    final day = dayOnly(date);
    // 用年月日回退，避免夏令时下 Duration(days: N) 把周一算成周日。
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  /// 日历页使用的“月序号”，PageView 用它做稳定 index。
  static int monthIndex(DateTime month) => month.year * 12 + month.month - 1;

  /// 月序号还原为当月第一天。
  static DateTime monthFromIndex(int index) =>
      DateTime(index ~/ 12, index % 12 + 1);

  static String get _locale {
    return switch (AppStrings.languageCode) {
      'en' => 'en',
      'ja' => 'ja',
      'fr' => 'fr',
      'es' => 'es',
      _ => 'zh',
    };
  }

  /// 月份标题，例如 `2026年11月` / `November 2026`。
  static String monthTitle(DateTime month) {
    if (_locale == 'zh') return '${month.year}年${month.month}月';
    return DateFormat.yMMMM(_locale).format(month);
  }

  /// 完整日期，例如 `2026年11月4日` / `November 4, 2026`。
  static String fullDateLabel(DateTime date) {
    if (_locale == 'zh') {
      return '${date.year}年${date.month}月${date.day}日';
    }
    return DateFormat.yMMMMd(_locale).format(date);
  }

  /// `11月4日` / `Nov 4`。
  static String monthDayLabel(DateTime date) {
    if (_locale == 'zh') return '${date.month}月${date.day}日';
    return DateFormat.MMMd(_locale).format(date);
  }

  /// 完整星期，例如 `星期三` / `Wednesday`。
  static String weekdayLabel(DateTime date) {
    if (_locale == 'zh') {
      const labels = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
      return labels[date.weekday - 1];
    }
    return DateFormat.EEEE(_locale).format(date);
  }

  /// 短星期，例如 `周三` / `Wed`。
  static String shortWeekdayLabel(DateTime date) {
    if (_locale == 'zh') {
      const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return labels[date.weekday - 1];
    }
    return DateFormat.E(_locale).format(date);
  }

  /// 打卡时间，例如 `08:32`。
  static String timeLabel(DateTime date) => DateFormat('HH:mm').format(date);
}
