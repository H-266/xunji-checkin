import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/core/date_utils.dart';
import 'package:xunji_checkin/core/stats.dart';
import 'package:xunji_checkin/models/task.dart';

void main() {
  group('日期工具', () {
    test('formatKey / isSameDay 只按自然日判断', () {
      final a = DateTime(2026, 11, 4, 23, 59);
      final b = DateTime(2026, 11, 4, 0, 1);
      expect(AppDateUtils.formatKey(a), '2026-11-04');
      expect(AppDateUtils.isSameDay(a, b), isTrue);
      expect(AppDateUtils.isSameDay(a, DateTime(2026, 11, 5)), isFalse);
    });

    test('月份边界与天数', () {
      expect(AppDateUtils.monthStart(DateTime(2026, 2, 18)), DateTime(2026, 2));
      expect(
        AppDateUtils.monthEnd(DateTime(2026, 2, 18)),
        DateTime(2026, 2, 28),
      );
      expect(AppDateUtils.daysInMonth(DateTime(2024, 2)), 29);
      expect(
        AppDateUtils.monthFromIndex(
          AppDateUtils.monthIndex(DateTime(2026, 11)),
        ),
        DateTime(2026, 11),
      );
    });
  });

  group('任务有效期', () {
    test('每日任务创建日到归档日前一天有效', () {
      final task = _daily(
        id: 1,
        createdAt: DateTime(2026, 11, 1, 9),
        archivedAt: DateTime(2026, 11, 5, 15),
      );

      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 10, 31)),
        isFalse,
      );
      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 1)),
        isTrue,
      );
      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 4)),
        isTrue,
      );
      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 5)),
        isFalse,
      );
    });

    test('未完成待办只计入到今天，不提前影响未来', () {
      final task = _todo(id: 2, createdAt: DateTime(2026, 11, 2));
      final today = DateTime(2026, 11, 4);

      expect(
        StatsCalculator.isTaskActiveOn(
          task,
          DateTime(2026, 11, 1),
          today: today,
        ),
        isFalse,
      );
      expect(
        StatsCalculator.isTaskActiveOn(
          task,
          DateTime(2026, 11, 4),
          today: today,
        ),
        isTrue,
      );
      expect(
        StatsCalculator.isTaskActiveOn(
          task,
          DateTime(2026, 11, 5),
          today: today,
        ),
        isFalse,
      );
    });

    test('已完成待办创建日到完成日（含）有效', () {
      final task = _todo(
        id: 3,
        createdAt: DateTime(2026, 11, 2),
        completedAt: DateTime(2026, 11, 3, 18),
      );

      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 2)),
        isTrue,
      );
      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 3)),
        isTrue,
      );
      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 4)),
        isFalse,
      );
    });
  });

  group('单日完成率', () {
    test('每日任务看当天打卡，待办只在完成日算完成', () {
      final daily = _daily(id: 1, createdAt: DateTime(2026, 11, 1));
      final todoDone = _todo(
        id: 2,
        createdAt: DateTime(2026, 11, 4, 9),
        completedAt: DateTime(2026, 11, 4, 12),
      );
      final todoPending = _todo(id: 3, createdAt: DateTime(2026, 11, 4, 10));
      final checkins = <String, Set<int>>{
        '2026-11-04': <int>{1},
      };

      final stat = StatsCalculator.calculateDayCompletion(
        date: DateTime(2026, 11, 4),
        tasks: [daily, todoDone, todoPending],
        dailyCheckins: checkins,
        today: DateTime(2026, 11, 4),
      );

      expect(stat.total, 3);
      expect(stat.completed, 2);
      expect(stat.rate, closeTo(2 / 3, 0.0001));
      expect(stat.percent, 67);
      expect(stat.isPerfect, isFalse);
      expect(stat.entries.length, 3);
    });

    test('无任务返回 0，不出现 0/0 全勤', () {
      final stat = StatsCalculator.calculateDayCompletion(
        date: DateTime(2026, 11, 4),
        tasks: const [],
        dailyCheckins: const {},
        today: DateTime(2026, 11, 4),
      );

      expect(stat.total, 0);
      expect(stat.completed, 0);
      expect(stat.rate, 0);
      expect(stat.isPerfect, isFalse);
    });

    test('当天完成的待办仍计入总数和完成数', () {
      final todo = _todo(
        id: 8,
        createdAt: DateTime(2026, 11, 4, 8),
        completedAt: DateTime(2026, 11, 4, 9),
      );

      final stat = StatsCalculator.calculateDayCompletion(
        date: DateTime(2026, 11, 4),
        tasks: [todo],
        dailyCheckins: const {},
        today: DateTime(2026, 11, 4),
      );

      expect(stat.total, 1);
      expect(stat.completed, 1);
      expect(stat.isPerfect, isTrue);
    });
  });

  group('月度统计', () {
    test('月平均只对有任务的天求平均，未来日期不参与', () {
      final daily = _daily(id: 1, createdAt: DateTime(2026, 11, 1));
      final todo = _todo(
        id: 2,
        createdAt: DateTime(2026, 11, 2, 9),
        completedAt: DateTime(2026, 11, 2, 18),
      );
      final checkins = <String, Set<int>>{
        '2026-11-01': <int>{1},
        '2026-11-02': <int>{1},
      };

      final stats = StatsCalculator.getMonthStats(
        month: DateTime(2026, 11),
        tasks: [daily, todo],
        dailyCheckins: checkins,
        today: DateTime(2026, 11, 3),
      );

      // 11/1: 1/1；11/2: 2/2；11/3: 0/1（待办已在 11/2 完成，不再计入）
      expect(stats.activeDays, 3);
      expect(stats.perfectDays, 2);
      expect(stats.daysWithCompletion, 2);
      expect(stats.averageRate, closeTo(2 / 3, 0.0001));
    });

    test('归档不破坏归档前的历史', () {
      final daily = _daily(
        id: 1,
        createdAt: DateTime(2026, 11, 1),
        archivedAt: DateTime(2026, 11, 3, 10),
      );
      final checkins = <String, Set<int>>{
        '2026-11-01': <int>{1},
      };

      final stats = StatsCalculator.getMonthStats(
        month: DateTime(2026, 11),
        tasks: [daily],
        dailyCheckins: checkins,
        today: DateTime(2026, 11, 4),
      );

      expect(stats.activeDays, 2); // 11/1、11/2
      expect(stats.perfectDays, 1);
      expect(stats.daysWithCompletion, 1);
      expect(stats.averageRate, 0.5);
    });

    test('未来月份为空', () {
      final stats = StatsCalculator.getMonthStats(
        month: DateTime(2026, 12),
        tasks: [_daily(id: 1, createdAt: DateTime(2026, 11, 1))],
        dailyCheckins: const {},
        today: DateTime(2026, 11, 4),
      );

      expect(stats.averageRate, 0);
      expect(stats.perfectDays, 0);
      expect(stats.daysWithCompletion, 0);
      expect(stats.activeDays, 0);
    });
  });

  group('计划日与任务统计', () {
    test('自定义星期在非计划日不计入当天总数', () {
      final task = Task(
        id: 9,
        title: '周一三五',
        type: TaskType.daily,
        createdAt: DateTime(2026, 11, 2).millisecondsSinceEpoch,
        schedule: TaskSchedule.weekdays,
        weekdayMask: 0x15, // 周一、周三、周五
      );

      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 2)),
        isTrue,
      );
      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 3)),
        isFalse,
      );
      final stat = StatsCalculator.calculateDayCompletion(
        date: DateTime(2026, 11, 3),
        tasks: [task],
        dailyCheckins: const {},
        today: DateTime(2026, 11, 6),
      );
      expect(stat.total, 0);
      expect(stat.rate, 0);
    });

    test('单任务连续 / 最长 / 累计天数', () {
      final task = _daily(id: 1, createdAt: DateTime(2026, 11, 1));
      final checkins = <String, Set<int>>{
        for (var day = 1; day <= 8; day++)
          AppDateUtils.formatKey(DateTime(2026, 11, day)): {1},
      };
      final stats = StatsCalculator.taskStats(
        task: task,
        dailyCheckins: checkins,
        today: DateTime(2026, 11, 8),
      );
      expect(stats.currentStreak, 8);
      expect(stats.longestStreak, 8);
      expect(stats.totalDays, 8);
    });

    test('年度全勤天数只统计有任务的完美日', () {
      final task = _daily(id: 1, createdAt: DateTime(2026, 1, 1));
      final checkins = <String, Set<int>>{
        '2026-01-01': {1},
        '2026-01-02': {1},
        '2025-12-31': {1},
      };
      expect(
        StatsCalculator.completedDayCount(
          tasks: [task],
          dailyCheckins: checkins,
          year: 2026,
          today: DateTime(2026, 12, 31),
        ),
        2,
      );
    });
  });
}

Task _daily({
  required int id,
  required DateTime createdAt,
  DateTime? archivedAt,
}) {
  return Task(
    id: id,
    title: '每日 $id',
    type: TaskType.daily,
    createdAt: createdAt.millisecondsSinceEpoch,
    archivedAt: archivedAt?.millisecondsSinceEpoch,
  );
}

Task _todo({
  required int id,
  required DateTime createdAt,
  DateTime? completedAt,
}) {
  return Task(
    id: id,
    title: '待办 $id',
    type: TaskType.todo,
    createdAt: createdAt.millisecondsSinceEpoch,
    completedAt: completedAt?.millisecondsSinceEpoch,
  );
}
