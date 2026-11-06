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
    title: '周期测试',
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
  test('间隔天数从创建日起循环', () {
    final task = _task(
      schedule: TaskSchedule.intervalDays,
      intervalDays: 3,
      created: DateTime(2026, 1, 1),
    );
    expect(task.isScheduledOn(DateTime(2026, 1, 1)), isTrue);
    expect(task.isScheduledOn(DateTime(2026, 1, 2)), isFalse);
    expect(task.isScheduledOn(DateTime(2026, 1, 3)), isFalse);
    expect(task.isScheduledOn(DateTime(2026, 1, 4)), isTrue);
  });

  test('每月多选日期与不存在的日期自动跳过', () {
    final task = _task(
      schedule: TaskSchedule.monthlyDays,
      monthDaysMask: (1 << 0) | (1 << 30), // 1 号、31 号
    );
    expect(task.isScheduledOn(DateTime(2026, 4, 1)), isTrue);
    expect(task.isScheduledOn(DateTime(2026, 4, 30)), isFalse);
    expect(task.isScheduledOn(DateTime(2026, 4, 29)), isFalse);
    expect(task.isScheduledOn(DateTime(2026, 5, 31)), isTrue);
  });

  test('每年固定日期只在该月日生效，闰年 2 月 29 日', () {
    final task = _task(
      schedule: TaskSchedule.yearlyDate,
      yearlyMonth: 2,
      yearlyDay: 29,
    );
    expect(task.isScheduledOn(DateTime(2024, 2, 29)), isTrue);
    expect(task.isScheduledOn(DateTime(2026, 2, 28)), isFalse);
    expect(task.isScheduledOn(DateTime(2026, 3, 1)), isFalse);
  });

  test('upcomingScheduleDates 返回未来生效日', () {
    final task = _task(
      schedule: TaskSchedule.monthlyDays,
      monthDaysMask: (1 << 0) | (1 << 14), // 1 号、15 号
    );
    final dates = task.upcomingScheduleDates(
      from: DateTime(2026, 5, 10),
      count: 3,
    );
    expect(dates.map(AppDateUtils.formatKey).toList(), [
      '2026-05-15',
      '2026-06-01',
      '2026-06-15',
    ]);
  });

  test('非生效日不计入当天总数与完成率', () {
    final task = _task(
      schedule: TaskSchedule.weekdays,
      weekdayMask: 1 << 0, // 仅周一
      created: DateTime(2026, 5, 1),
    );
    final tuesday = StatsCalculator.calculateDayCompletion(
      date: DateTime(2026, 5, 5),
      tasks: [task],
      dailyCheckins: const {},
      today: DateTime(2026, 5, 10),
    );
    expect(tuesday.total, 0);
    expect(tuesday.rate, 0);

    final monday = StatsCalculator.calculateDayCompletion(
      date: DateTime(2026, 5, 4),
      tasks: [task],
      dailyCheckins: {
        '2026-05-04': {1},
      },
      today: DateTime(2026, 5, 10),
    );
    expect(monday.total, 1);
    expect(monday.rate, 1);
  });

  test('旧版数据缺省字段映射为每日周期', () {
    final task = Task.fromMap({
      'id': 9,
      'title': '旧任务',
      'type': 'daily',
      'created_at': DateTime(2025, 1, 1).millisecondsSinceEpoch,
      'sort_order': 0,
    });
    expect(task.schedule, TaskSchedule.daily);
    expect(task.intervalDays, 1);
    expect(task.monthDaysMask, 1);
    expect(task.isScheduledOn(DateTime(2027, 8, 1)), isTrue);
  });
}
