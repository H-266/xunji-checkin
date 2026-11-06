import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/core/date_utils.dart';
import 'package:xunji_checkin/core/stats.dart';
import 'package:xunji_checkin/models/task.dart';

void main() {
  group('置顶任务排序', () {
    test('负偏移量编码可识别置顶并保持相对顺序', () {
      final first = _daily(sortOrder: -Task.pinnedOffset + 1);
      final second = _daily(sortOrder: -Task.pinnedOffset + 2);
      final normal = _daily(sortOrder: 3);

      expect(first.isPinned, isTrue);
      expect(second.isPinned, isTrue);
      expect(normal.isPinned, isFalse);
      expect(first.sortOrder, lessThan(second.sortOrder));
    });
  });

  group('环比统计', () {
    test('汇总完成数、全勤天与有效天', () {
      final task = _daily(createdAt: DateTime(2026, 11, 1, 8));
      final start = DateTime(2026, 11, 1);
      final end = DateTime(2026, 11, 3);
      final result = StatsCalculator.periodStats(
        start: start,
        end: end,
        tasks: [task],
        dailyCheckins: {
          '2026-11-01': {1},
          '2026-11-03': {1},
        },
        today: DateTime(2026, 11, 3, 20),
      );

      expect(result.total, 3);
      expect(result.completed, 2);
      expect(result.activeDays, 3);
      expect(result.perfectDays, 2);
      expect(result.rate, closeTo(2 / 3, 1e-9));
    });

    test('开始日晚于结束日时返回空统计', () {
      final result = StatsCalculator.periodStats(
        start: DateTime(2026, 11, 4),
        end: DateTime(2026, 11, 3),
        tasks: const [],
        dailyCheckins: const {},
        today: DateTime(2026, 11, 4),
      );
      expect(result.total, 0);
      expect(result.activeDays, 0);
    });
  });

  test('完成时间格式化到分钟', () {
    expect(AppDateUtils.timeLabel(DateTime(2026, 11, 5, 9, 7)), '09:07');
  });
}

Task _daily({int id = 1, DateTime? createdAt, int sortOrder = 1}) {
  return Task(
    id: id,
    title: '每日任务$id',
    type: TaskType.daily,
    createdAt: (createdAt ?? DateTime(2026, 11, 1)).millisecondsSinceEpoch,
    sortOrder: sortOrder,
  );
}
