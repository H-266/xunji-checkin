import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/core/date_utils.dart';
import 'package:xunji_checkin/core/stats.dart';
import 'package:xunji_checkin/models/task.dart';

void main() {
  group('待办截止日', () {
    test('截止日当天仍计入，逾期后不再计入今日分母', () {
      final task = _todo(
        id: 1,
        created: DateTime(2026, 11, 1),
        due: DateTime(2026, 11, 3),
      );
      final today = DateTime(2026, 11, 5);

      expect(
        StatsCalculator.isTaskActiveOn(
          task,
          DateTime(2026, 11, 1),
          today: today,
        ),
        isTrue,
      );
      expect(
        StatsCalculator.isTaskActiveOn(
          task,
          DateTime(2026, 11, 3),
          today: today,
        ),
        isTrue,
      );
      expect(
        StatsCalculator.isTaskActiveOn(
          task,
          DateTime(2026, 11, 4),
          today: today,
        ),
        isFalse,
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
  });

  group('自定义星期', () {
    test('非排班日不进入每日任务分母', () {
      final task = _weeklyMonday(id: 1, created: DateTime(2026, 11, 1));

      expect(task.isScheduledOn(DateTime(2026, 11, 2)), isTrue);
      expect(task.isScheduledOn(DateTime(2026, 11, 3)), isFalse);
      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 2)),
        isTrue,
      );
      expect(
        StatsCalculator.isTaskActiveOn(task, DateTime(2026, 11, 3)),
        isFalse,
      );
    });

    test('月统计只平均排班日，周一打卡得到 100%', () {
      final task = _weeklyMonday(id: 1, created: DateTime(2026, 11, 1));
      final checkins = <String, Set<int>>{
        AppDateUtils.formatKey(DateTime(2026, 11, 2)): {1},
      };

      final stats = StatsCalculator.getMonthStats(
        month: DateTime(2026, 11),
        tasks: [task],
        dailyCheckins: checkins,
        today: DateTime(2026, 11, 4),
      );
      expect(stats.activeDays, 1);
      expect(stats.perfectDays, 1);
      expect(stats.averageRate, 1);
    });

    test('补卡日期可回填历史且只影响目标日期', () {
      final task = _daily(id: 1, created: DateTime(2026, 11, 1));
      final checkins = <String, Set<int>>{
        AppDateUtils.formatKey(DateTime(2026, 11, 2)): {1},
      };
      final day = StatsCalculator.calculateDayCompletion(
        date: DateTime(2026, 11, 2),
        tasks: [task],
        dailyCheckins: checkins,
        today: DateTime(2026, 11, 4),
      );
      expect(day.total, 1);
      expect(day.completed, 1);
      expect(day.isPerfect, isTrue);
    });

    test('自定义星期的单任务连击跳过休息日', () {
      final task = Task(
        id: 1,
        title: '周一、周三',
        type: TaskType.daily,
        createdAt: DateTime(2026, 11, 2).millisecondsSinceEpoch,
        schedule: TaskSchedule.weekdays,
        // 周一 bit0 + 周三 bit2
        weekdayMask: 0x05,
      );
      final checkins = <String, Set<int>>{
        AppDateUtils.formatKey(DateTime(2026, 11, 2)): {1},
        AppDateUtils.formatKey(DateTime(2026, 11, 4)): {1},
      };

      final stats = StatsCalculator.taskStats(
        task: task,
        dailyCheckins: checkins,
        today: DateTime(2026, 11, 4),
      );
      expect(stats.currentStreak, 2);
      expect(stats.longestStreak, 2);
      expect(stats.totalDays, 2);
    });
  });

  group('全局全勤与趋势', () {
    test('没有任务的日子不打断全勤', () {
      final task = _weeklyMonday(id: 1, created: DateTime(2026, 10, 26));
      final checkins = <String, Set<int>>{
        AppDateUtils.formatKey(DateTime(2026, 10, 26)): {1},
        AppDateUtils.formatKey(DateTime(2026, 11, 2)): {1},
      };

      expect(
        StatsCalculator.currentPerfectStreak(
          tasks: [task],
          dailyCheckins: checkins,
          today: DateTime(2026, 11, 4),
        ),
        2,
      );
    });

    test('最近一周趋势按任务总量加权', () {
      final task = _daily(id: 1, created: DateTime(2026, 11, 1));
      final checkins = <String, Set<int>>{
        AppDateUtils.formatKey(DateTime(2026, 11, 2)): {1},
      };
      final rates = StatsCalculator.recentWeekRates(
        weeks: 1,
        tasks: [task],
        dailyCheckins: checkins,
        today: DateTime(2026, 11, 3),
      );
      expect(rates, hasLength(1));
      // 本周 11/2 完成、11/3 未完成 → 2 个任务日里完成 1 个。
      expect(rates.single, closeTo(0.5, 0.0001));
    });
  });
}

Task _daily({required int id, required DateTime created}) => Task(
  id: id,
  title: '每日 $id',
  type: TaskType.daily,
  createdAt: created.millisecondsSinceEpoch,
);

Task _todo({
  required int id,
  required DateTime created,
  required DateTime due,
}) => Task(
  id: id,
  title: '待办 $id',
  type: TaskType.todo,
  createdAt: created.millisecondsSinceEpoch,
  dueAt: due.millisecondsSinceEpoch,
);

Task _weeklyMonday({required int id, required DateTime created}) => Task(
  id: id,
  title: '周一任务 $id',
  type: TaskType.daily,
  createdAt: created.millisecondsSinceEpoch,
  schedule: TaskSchedule.weekdays,
  weekdayMask: 0x01,
);
