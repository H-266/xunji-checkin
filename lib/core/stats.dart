import '../models/task.dart';
import 'date_utils.dart';

/// 某一天的一条任务明细，供热力图日详情弹窗展示。
class DayTaskEntry {
  final Task task;
  final bool done;

  const DayTaskEntry({required this.task, required this.done});
}

/// 单日统计结果。
class DayStat {
  final DateTime date;
  final int total;
  final int completed;
  final List<DayTaskEntry> entries;

  const DayStat({
    required this.date,
    required this.total,
    required this.completed,
    required this.entries,
  });

  factory DayStat.empty(DateTime date) => DayStat(
    date: AppDateUtils.dayOnly(date),
    total: 0,
    completed: 0,
    entries: const <DayTaskEntry>[],
  );

  bool get hasTasks => total > 0;
  bool get isPerfect => total > 0 && completed == total;
  int get remaining => total - completed;

  /// 0.0 ~ 1.0，无任务时为 0。
  double get rate => total == 0 ? 0 : completed / total;

  /// 0 ~ 100 的整数，只用于文案和颜色分档。
  int get percent => (rate * 100).round();
}

/// 一段日期内的汇总，用于环比分析。
class PeriodCompletion {
  const PeriodCompletion({
    required this.start,
    required this.end,
    required this.total,
    required this.completed,
    required this.activeDays,
    required this.perfectDays,
  });

  final DateTime start;
  final DateTime end;
  final int total;
  final int completed;
  final int activeDays;
  final int perfectDays;

  double get rate => total == 0 ? 0 : completed / total;
  int get percent => (rate * 100).round();
}

/// 任务累计排行项。
class TaskRanking {
  const TaskRanking({
    required this.task,
    required this.totalDays,
    required this.longestStreak,
  });

  final Task task;
  final int totalDays;
  final int longestStreak;
}

/// 标签维度汇总。
class TagPerformance {
  const TagPerformance({
    required this.tagId,
    required this.name,
    required this.totalDays,
    required this.averageRate,
    required this.longestStreak,
  });

  final int tagId;
  final String name;
  final int totalDays;
  final double averageRate;
  final int longestStreak;

  int get percent => (averageRate * 100).round();
}

/// 类型维度汇总。
class TypePerformance {
  const TypePerformance({
    required this.dailyTotal,
    required this.dailyDone,
    required this.todoTotal,
    required this.todoDone,
    required this.dailyRate,
    required this.todoRate,
  });

  final int dailyTotal;
  final int dailyDone;
  final int todoTotal;
  final int todoDone;
  final double dailyRate;
  final double todoRate;
}

/// 一天中的打卡时段分布。
class HourDistribution {
  const HourDistribution(this.counts);

  /// 下标 0~23，表示 0 点~23 点。
  final List<int> counts;

  int get total => counts.fold(0, (sum, value) => sum + value);
  int get peakHour {
    var best = 0;
    for (var hour = 1; hour < counts.length; hour++) {
      if (counts[hour] > counts[best]) best = hour;
    }
    return best;
  }
}

/// 周期表现卡片数据。
class PeriodPerformance {
  const PeriodPerformance({
    required this.longestPerfectStreak,
    required this.longestGapDays,
    required this.bestMonth,
    required this.bestMonthRate,
    required this.averageRate,
  });

  final int longestPerfectStreak;
  final int longestGapDays;
  final DateTime? bestMonth;
  final double bestMonthRate;
  final double averageRate;

  int get bestMonthPercent => (bestMonthRate * 100).round();
  int get averagePercent => (averageRate * 100).round();
}

/// 月度统计结果。
class MonthStats {
  final DateTime month;
  final double averageRate;
  final int perfectDays;
  final int daysWithCompletion;

  /// 有有效任务的天数，月平均只对这些天求平均，避免“没有安排任务”的
  /// 空白日把平均值稀释。
  final int activeDays;

  const MonthStats({
    required this.month,
    required this.averageRate,
    required this.perfectDays,
    required this.daysWithCompletion,
    required this.activeDays,
  });

  factory MonthStats.empty(DateTime month) => MonthStats(
    month: AppDateUtils.monthStart(month),
    averageRate: 0,
    perfectDays: 0,
    daysWithCompletion: 0,
    activeDays: 0,
  );

  int get averagePercent => (averageRate * 100).round();
}

/// 单个每日任务的统计结果。
///
/// 连击只计算“排班日”：自定义星期任务跳过未选中的星期，
/// 因此不会因为休息日没打卡而断掉连击。
class TaskStats {
  final int currentStreak;
  final int longestStreak;
  final int totalDays;
  final int weeklyDone;
  final int weeklyTarget;

  const TaskStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDays,
    required this.weeklyDone,
    required this.weeklyTarget,
  });

  static const empty = TaskStats(
    currentStreak: 0,
    longestStreak: 0,
    totalDays: 0,
    weeklyDone: 0,
    weeklyTarget: 7,
  );

  bool get weeklyGoalReached => weeklyDone >= weeklyTarget;
}

/// 纯函数统计核心，不依赖 Flutter、不读写数据库，可直接单元测试。
class StatsCalculator {
  StatsCalculator._();

  /// 任务在 [date] 当天是否计入“有效任务总数”。
  ///
  /// - 每日任务：创建日 ~ 归档日前一天，每天都计入；
  /// - 临时待办：创建日 ~ 完成日（含）计入；未完成待办只计入到今天，
  ///   不会提前影响未来日期。
  static bool isTaskActiveOn(Task task, DateTime date, {DateTime? today}) {
    final day = AppDateUtils.dayOnly(date);
    final createdDay = AppDateUtils.dayOnly(task.createdDate);
    if (day.isBefore(createdDay)) return false;

    final archivedAt = task.archivedAt;
    if (archivedAt != null) {
      // 归档当天起不再计入；归档前的历史仍保留。
      final archivedDay = AppDateUtils.dayOnly(
        DateTime.fromMillisecondsSinceEpoch(archivedAt),
      );
      if (!day.isBefore(archivedDay)) return false;
    }

    if (task.type == TaskType.daily) {
      // 自定义星期任务在非排班日不进入分母，避免拉低完成率。
      return task.isScheduledOn(day);
    }

    final dueDay = task.dueDate == null
        ? null
        : AppDateUtils.dayOnly(task.dueDate!);
    final completedAt = task.completedAt;
    if (completedAt != null) {
      final completedDay = AppDateUtils.dayOnly(
        DateTime.fromMillisecondsSinceEpoch(completedAt),
      );
      // 完成日当天仍计入；设了截止日的待办最晚只统计到截止日。
      if (dueDay != null && day.isAfter(dueDay)) return false;
      return !day.isAfter(completedDay);
    }

    final currentDay = AppDateUtils.dayOnly(today ?? DateTime.now());
    // 逾期未完成不再进入“今天”的分母，避免永久拖低完成率；
    // 截止日当天仍然计入，并显示为未完成。
    if (dueDay != null && day.isAfter(dueDay)) return false;
    return !day.isAfter(currentDay);
  }

  /// 任务在 [date] 当天是否“已完成”。
  ///
  /// 每日任务看 checkins；临时待办只在完成日当天算完成——
  /// 完成日之前的日期虽然计入总数，但当时确实还没做完，不能算完成。
  static bool isTaskDoneOn(
    Task task,
    DateTime date,
    Map<String, Set<int>> dailyCheckins,
  ) {
    final taskId = task.id;
    if (taskId == null) return false;

    if (task.type == TaskType.daily) {
      final ids = dailyCheckins[AppDateUtils.formatKey(date)];
      return ids?.contains(taskId) ?? false;
    }

    final completedAt = task.completedAt;
    if (completedAt == null) return false;
    final completedDay = AppDateUtils.dayOnly(
      DateTime.fromMillisecondsSinceEpoch(completedAt),
    );
    return AppDateUtils.isSameDay(completedDay, date);
  }

  /// 计算单日完成率。
  ///
  /// 注意：当天完成的临时待办已经从“今日列表”消失，但它仍然计入
  /// 当天总数和完成数，否则完成待办反而会让完成率下降。
  static DayStat calculateDayCompletion({
    required DateTime date,
    required List<Task> tasks,
    required Map<String, Set<int>> dailyCheckins,
    DateTime? today,
  }) {
    final day = AppDateUtils.dayOnly(date);
    final entries = <DayTaskEntry>[];

    for (final task in tasks) {
      if (!isTaskActiveOn(task, day, today: today)) continue;
      entries.add(
        DayTaskEntry(task: task, done: isTaskDoneOn(task, day, dailyCheckins)),
      );
    }

    final completed = entries.where((entry) => entry.done).length;
    return DayStat(
      date: day,
      total: entries.length,
      completed: completed,
      entries: List<DayTaskEntry>.unmodifiable(entries),
    );
  }

  /// 月度三个指标：平均完成率、全勤天数、有完成的天数。
  ///
  /// 当前月只统计到今天，未来日期不参与；没有有效任务的天不进入平均。
  static MonthStats getMonthStats({
    required DateTime month,
    required List<Task> tasks,
    required Map<String, Set<int>> dailyCheckins,
    DateTime? today,
  }) {
    final start = AppDateUtils.monthStart(month);
    final end = AppDateUtils.monthEnd(month);
    final currentDay = AppDateUtils.dayOnly(today ?? DateTime.now());

    if (start.isAfter(currentDay)) {
      return MonthStats.empty(month);
    }

    var rateSum = 0.0;
    var activeDays = 0;
    var perfectDays = 0;
    var daysWithCompletion = 0;

    var cursor = start;
    final lastDay = end.isAfter(currentDay) ? currentDay : end;
    while (!cursor.isAfter(lastDay)) {
      final stat = calculateDayCompletion(
        date: cursor,
        tasks: tasks,
        dailyCheckins: dailyCheckins,
        today: currentDay,
      );

      if (stat.hasTasks) {
        activeDays++;
        rateSum += stat.rate;
      }
      if (stat.isPerfect) perfectDays++;
      if (stat.completed > 0) daysWithCompletion++;

      // 用年月日构造下一天，避免夏令时环境下 Duration(days: 1) 的偏差。
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    return MonthStats(
      month: start,
      averageRate: activeDays == 0 ? 0 : rateSum / activeDays,
      perfectDays: perfectDays,
      daysWithCompletion: daysWithCompletion,
      activeDays: activeDays,
    );
  }

  /// 任意起止日期的汇总（用于本月/上周等环比）。
  ///
  /// 只统计截至今天的日期，未来不参与；没有任务的天不进入全勤。
  static PeriodCompletion periodStats({
    required DateTime start,
    required DateTime end,
    required List<Task> tasks,
    required Map<String, Set<int>> dailyCheckins,
    DateTime? today,
  }) {
    final currentDay = AppDateUtils.dayOnly(today ?? DateTime.now());
    final from = AppDateUtils.dayOnly(start);
    var to = AppDateUtils.dayOnly(end);
    if (to.isAfter(currentDay)) to = currentDay;
    if (from.isAfter(to)) {
      return PeriodCompletion(
        start: from,
        end: from,
        total: 0,
        completed: 0,
        activeDays: 0,
        perfectDays: 0,
      );
    }

    var total = 0;
    var completed = 0;
    var activeDays = 0;
    var perfectDays = 0;
    var cursor = from;
    while (!cursor.isAfter(to)) {
      final stat = calculateDayCompletion(
        date: cursor,
        tasks: tasks,
        dailyCheckins: dailyCheckins,
        today: currentDay,
      );
      total += stat.total;
      completed += stat.completed;
      if (stat.hasTasks) activeDays++;
      if (stat.isPerfect) perfectDays++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    return PeriodCompletion(
      start: from,
      end: to,
      total: total,
      completed: completed,
      activeDays: activeDays,
      perfectDays: perfectDays,
    );
  }

  /// 单任务连击、累计天数与本周进度。
  ///
  /// 只读取已有打卡记录，不新增任何表；归档后仍能展示历史。
  static TaskStats taskStats({
    required Task task,
    required Map<String, Set<int>> dailyCheckins,
    DateTime? today,
  }) {
    final taskId = task.id;
    if (taskId == null || task.type != TaskType.daily) {
      return TaskStats.empty;
    }

    final currentDay = AppDateUtils.dayOnly(today ?? DateTime.now());
    final createdDay = AppDateUtils.dayOnly(task.createdDate);
    final archiveDay = task.archivedAt == null
        ? null
        : AppDateUtils.dayOnly(
            DateTime.fromMillisecondsSinceEpoch(task.archivedAt!),
          );
    // 用年月日构造，避免夏令时导致 Duration(days: 1) 偏移。
    var end = archiveDay == null
        ? currentDay
        : DateTime(archiveDay.year, archiveDay.month, archiveDay.day - 1);
    if (end.isAfter(currentDay)) end = currentDay;
    if (end.isBefore(createdDay)) return TaskStats.empty;

    bool done(DateTime day) {
      return dailyCheckins[AppDateUtils.formatKey(day)]?.contains(taskId) ??
          false;
    }

    bool active(DateTime day) => isTaskActiveOn(task, day, today: currentDay);

    var longest = 0;
    var running = 0;
    var total = 0;
    var cursor = createdDay;
    while (!cursor.isAfter(end)) {
      if (active(cursor)) {
        if (done(cursor)) {
          total++;
          running++;
          if (running > longest) longest = running;
        } else {
          running = 0;
        }
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    // 今日还没打卡时，连击从昨天开始算，避免“今天没打就归零”的挫败感。
    var streakCursor = currentDay;
    if (streakCursor.isAfter(end)) streakCursor = end;
    if (!streakCursor.isBefore(createdDay) &&
        active(streakCursor) &&
        !done(streakCursor)) {
      streakCursor = DateTime(
        streakCursor.year,
        streakCursor.month,
        streakCursor.day - 1,
      );
    }
    var current = 0;
    while (!streakCursor.isBefore(createdDay)) {
      if (!active(streakCursor)) {
        streakCursor = DateTime(
          streakCursor.year,
          streakCursor.month,
          streakCursor.day - 1,
        );
        continue;
      }
      if (!done(streakCursor)) break;
      current++;
      streakCursor = DateTime(
        streakCursor.year,
        streakCursor.month,
        streakCursor.day - 1,
      );
    }

    final weekStart = AppDateUtils.weekStart(currentDay);
    var weeklyDone = 0;
    var weekCursor = weekStart;
    while (!weekCursor.isAfter(currentDay)) {
      if (active(weekCursor) && done(weekCursor)) weeklyDone++;
      weekCursor = DateTime(
        weekCursor.year,
        weekCursor.month,
        weekCursor.day + 1,
      );
    }

    return TaskStats(
      currentStreak: current,
      longestStreak: longest,
      totalDays: total,
      weeklyDone: weeklyDone,
      weeklyTarget: task.weeklyTarget,
    );
  }

  /// 当前“全局全勤”连续天数。
  ///
  /// 只统计有任务且全部完成的天；没有任务的天直接跳过，不算断签。
  /// 今天尚未全勤时从昨天开始，避免上午打开 App 就显示 0。
  static int currentPerfectStreak({
    required List<Task> tasks,
    required Map<String, Set<int>> dailyCheckins,
    DateTime? today,
  }) {
    final currentDay = AppDateUtils.dayOnly(today ?? DateTime.now());
    var cursor = currentDay;
    var streak = 0;
    for (var i = 0; i < 3660; i++) {
      final stat = calculateDayCompletion(
        date: cursor,
        tasks: tasks,
        dailyCheckins: dailyCheckins,
        today: currentDay,
      );
      if (!stat.hasTasks) {
        cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
        continue;
      }
      if (!stat.isPerfect) {
        if (i == 0) {
          cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
          continue;
        }
        break;
      }
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  /// 最近 [days] 天的单日统计，按日期升序。
  static List<DayStat> recentDays({
    required int days,
    required List<Task> tasks,
    required Map<String, Set<int>> dailyCheckins,
    DateTime? today,
  }) {
    final currentDay = AppDateUtils.dayOnly(today ?? DateTime.now());
    return <DayStat>[
      for (var i = days - 1; i >= 0; i--)
        calculateDayCompletion(
          date: DateTime(currentDay.year, currentDay.month, currentDay.day - i),
          tasks: tasks,
          dailyCheckins: dailyCheckins,
          today: currentDay,
        ),
    ];
  }

  /// 最近 [weeks] 周的完成率（按周一到周日聚合）。
  static List<double> recentWeekRates({
    required int weeks,
    required List<Task> tasks,
    required Map<String, Set<int>> dailyCheckins,
    DateTime? today,
  }) {
    final currentDay = AppDateUtils.dayOnly(today ?? DateTime.now());
    final thisMonday = AppDateUtils.weekStart(currentDay);
    final result = <double>[];
    for (var w = weeks - 1; w >= 0; w--) {
      final start = DateTime(
        thisMonday.year,
        thisMonday.month,
        thisMonday.day - w * 7,
      );
      var total = 0;
      var completed = 0;
      for (var d = 0; d < 7; d++) {
        final day = DateTime(start.year, start.month, start.day + d);
        if (day.isAfter(currentDay)) break;
        final stat = calculateDayCompletion(
          date: day,
          tasks: tasks,
          dailyCheckins: dailyCheckins,
          today: currentDay,
        );
        total += stat.total;
        completed += stat.completed;
      }
      result.add(total == 0 ? 0 : completed / total);
    }
    return result;
  }

  /// 某一年内所有已完成打卡的日期数（按天去重）。
  static int completedDayCount({
    required List<Task> tasks,
    required Map<String, Set<int>> dailyCheckins,
    required int year,
    DateTime? today,
  }) {
    final currentDay = AppDateUtils.dayOnly(today ?? DateTime.now());
    var cursor = DateTime(year);
    final end = DateTime(year, 12, 31);
    var count = 0;
    while (!cursor.isAfter(end) && !cursor.isAfter(currentDay)) {
      final stat = calculateDayCompletion(
        date: cursor,
        tasks: tasks,
        dailyCheckins: dailyCheckins,
        today: currentDay,
      );
      if (stat.completed > 0) count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return count;
  }
}
