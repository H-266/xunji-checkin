import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/core/date_utils.dart';
import 'package:xunji_checkin/core/stats.dart';
import 'package:xunji_checkin/models/task.dart';

Task _task({
  TaskSchedule schedule = TaskSchedule.daily,
  DateTime? created,
  int intervalDays = 1,
  int monthDaysMask = 1,
  int? yearlyMonth,
  int? yearlyDay,
  int weekdayMask = 0x7F,
}) {
  final start = created ?? DateTime(2026, 1, 1);
  return Task(
    id: 1,
    title: '边界测试',
    type: TaskType.daily,
    createdAt: start.millisecondsSinceEpoch,
    schedule: schedule,
    intervalDays: intervalDays,
    monthDaysMask: monthDaysMask,
    yearlyMonth: yearlyMonth,
    yearlyDay: yearlyDay,
    weekdayMask: weekdayMask,
  );
}

void main() {
  group('周期日期边界', () {
    test('每月 31 日在短月自动跳过，长月恢复生效', () {
      final task = _task(
        schedule: TaskSchedule.monthlyDays,
        monthDaysMask: 1 << 30, // 31 日
      );
      expect(task.isScheduledOn(DateTime(2026, 2, 28)), isFalse);
      expect(task.isScheduledOn(DateTime(2026, 4, 30)), isFalse);
      expect(task.isScheduledOn(DateTime(2026, 5, 31)), isTrue);
      expect(task.isScheduledOn(DateTime(2027, 1, 31)), isTrue);
    });

    test('每月 29 日仅在闰年 2 月生效', () {
      final task = _task(
        schedule: TaskSchedule.monthlyDays,
        monthDaysMask: 1 << 28,
      );
      expect(task.isScheduledOn(DateTime(2023, 2, 28)), isFalse);
      expect(task.isScheduledOn(DateTime(2024, 2, 29)), isTrue);
      expect(task.isScheduledOn(DateTime(2026, 2, 28)), isFalse);
    });

    test('每年 2 月 29 日在平年跳过，闰年生效', () {
      final task = _task(
        schedule: TaskSchedule.yearlyDate,
        yearlyMonth: 2,
        yearlyDay: 29,
      );
      expect(task.isScheduledOn(DateTime(2023, 2, 28)), isFalse);
      expect(task.isScheduledOn(DateTime(2024, 2, 29)), isTrue);
      expect(task.isScheduledOn(DateTime(2025, 2, 28)), isFalse);
      expect(task.isScheduledOn(DateTime(2028, 2, 29)), isTrue);
    });

    test('每年 2 月 29 日的近期生效日能跨四年找到', () {
      final task = _task(
        schedule: TaskSchedule.yearlyDate,
        yearlyMonth: 2,
        yearlyDay: 29,
      );
      final dates = task.upcomingScheduleDates(
        from: DateTime(2025, 3, 1),
        count: 1,
      );
      expect(dates.single, DateTime(2028, 2, 29));
    });

    test('间隔 N 天跨闰年、跨年不偏移', () {
      final task = _task(
        schedule: TaskSchedule.intervalDays,
        intervalDays: 2,
        created: DateTime(2024, 2, 28),
      );
      expect(task.isScheduledOn(DateTime(2024, 2, 28)), isTrue);
      expect(task.isScheduledOn(DateTime(2024, 2, 29)), isFalse);
      expect(task.isScheduledOn(DateTime(2024, 3, 1)), isTrue);
      expect(task.isScheduledOn(DateTime(2024, 12, 31)), isFalse);
      expect(task.isScheduledOn(DateTime(2025, 1, 1)), isTrue);
      expect(task.isScheduledOn(DateTime(2025, 1, 2)), isFalse);
    });
  });

  group('统计口径边界', () {
    test('每年任务在非生效日不计入总数和完成数', () {
      final task = _task(
        schedule: TaskSchedule.yearlyDate,
        yearlyMonth: 2,
        yearlyDay: 29,
      );
      final normal = StatsCalculator.calculateDayCompletion(
        date: DateTime(2026, 2, 28),
        tasks: [task],
        dailyCheckins: const {},
        today: DateTime(2026, 3, 1),
      );
      expect(normal.total, 0);
      expect(normal.completed, 0);
      expect(normal.rate, 0);
      expect(normal.rate.isNaN, isFalse);

      final leap = StatsCalculator.calculateDayCompletion(
        date: DateTime(2028, 2, 29),
        tasks: [task],
        dailyCheckins: const {},
        today: DateTime(2028, 3, 1),
      );
      expect(leap.total, 1);
      expect(leap.completed, 0);
      expect(leap.rate, 0);
    });

    test('单任务连击跳过非生效日，不因休息日中断', () {
      // 2026-05-04 周一、05-07 周四、05-11 周一、05-14 周四
      final task = _task(
        schedule: TaskSchedule.weekdays,
        weekdayMask: (1 << 0) | (1 << 3), // 周一、周四
        created: DateTime(2026, 5, 4),
      );
      final stats = StatsCalculator.taskStats(
        task: task,
        dailyCheckins: {
          '2026-05-04': {1},
          '2026-05-07': {1},
          '2026-05-11': {1},
          '2026-05-14': {1},
        },
        today: DateTime(2026, 5, 14),
      );
      expect(stats.currentStreak, 4);
      expect(stats.longestStreak, 4);
      expect(stats.totalDays, 4);
    });

    test('空任务统计不产生 NaN / Infinity', () {
      final stat = StatsCalculator.calculateDayCompletion(
        date: DateTime(2026, 5, 14),
        tasks: const [],
        dailyCheckins: const {},
        today: DateTime(2026, 5, 14),
      );
      expect(stat.total, 0);
      expect(stat.rate, 0);
      expect(stat.rate.isNaN, isFalse);
      expect(stat.rate.isInfinite, isFalse);
    });
  });

  group('日期工具夏令时安全', () {
    test('weekStart 用日历日回退，不依赖 24 小时时长', () {
      // 2026-03-09 是周一，跨过美国夏令时切换日 2026-03-08。
      final monday = DateTime(2026, 3, 9);
      expect(AppDateUtils.weekStart(monday), DateTime(2026, 3, 9));
      final sunday = DateTime(2026, 3, 15);
      expect(AppDateUtils.weekStart(sunday), DateTime(2026, 3, 9));
    });
  });
}
