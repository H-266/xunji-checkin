import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/date_utils.dart';
import '../core/stats.dart';
import '../data/app_database.dart';
import '../models/tag.dart';
import '../models/task.dart';
import '../services/local_log_service.dart';

/// 任务与打卡的全局状态。
///
/// 设计原则：
/// 1. 每日任务不写“完成/未完成”字段，只看 `(taskId, todayKey)` 是否有打卡；
/// 2. 临时待办的完成状态只写 `tasks.completed_at`，完成后从今日列表过滤掉；
/// 3. 今日完成率使用“当日全部有效任务”，包含当天已完成、但已从列表消失的待办；
/// 4. 任务删除一律软归档，历史统计仍能读到归档前的数据。
class TaskProvider extends ChangeNotifier {
  TaskProvider({AppDatabase? database})
    : _db = database ?? AppDatabase.instance;

  final AppDatabase _db;

  List<Task> _tasks = <Task>[];
  Map<String, Set<int>> _checkinsByDate = <String, Set<int>>{};
  Map<String, Map<int, CheckinRecord>> _recordsByDate =
      <String, Map<int, CheckinRecord>>{};
  List<Tag> _tags = <Tag>[];
  int? _tagFilterId;
  int? _taskFilterId;
  DateTime _today = AppDateUtils.dayOnly(DateTime.now());
  bool _loading = true;
  String? _loadError;
  int _loadToken = 0;

  /// 热力月视图一次要取 42 天、年视图 371 天，同一次 build 内还会被
  /// 指标卡/详情弹窗重复查询。按“数据版本 + 日期 + 标签”缓存，
  /// notifyListeners 时版本递增并清空，保证不会展示旧统计。
  int _statVersion = 0;
  final Map<String, DayStat> _dayStatCache = <String, DayStat>{};

  /// 打卡的“轻量刷新”信号：只更新进度环与单行，不触发整页重建。
  final ValueNotifier<int> checkinRevision = ValueNotifier<int>(0);
  final Map<int, ValueNotifier<bool>> _doneNotifiers =
      <int, ValueNotifier<bool>>{};
  Timer? _checkinNotifyTimer;

  /// 勾选先改内存，60ms 内的连续操作合并成一次 DB 写入。
  /// 关键帧里不做任何 SQLite IO。
  Timer? _checkinWriteTimer;
  final Map<int, _PendingCheckin> _pendingCheckins = <int, _PendingCheckin>{};

  /// 单行完成态；勾选时只改这一个 notifier，不 notifyListeners。
  ValueListenable<bool> doneListenable(Task task, bool initial) {
    final id = task.id;
    if (id == null) return ValueNotifier<bool>(initial);
    return _doneNotifiers.putIfAbsent(id, () => ValueNotifier<bool>(initial));
  }

  /// 连续快速勾选时合并整页通知，避免每一下都重建统计/列表。
  void _scheduleCheckinNotify() {
    _statVersion++;
    _dayStatCache.clear();
    checkinRevision.value++;
    _checkinNotifyTimer?.cancel();
    _checkinNotifyTimer = Timer(const Duration(milliseconds: 600), () {
      if (hasListeners) notifyListeners();
    });
  }

  @override
  void dispose() {
    _checkinNotifyTimer?.cancel();
    _checkinWriteTimer?.cancel();
    if (_pendingCheckins.isNotEmpty) {
      unawaited(_flushCheckins());
    }
    checkinRevision.dispose();
    for (final notifier in _doneNotifiers.values) {
      notifier.dispose();
    }
    _doneNotifiers.clear();
    super.dispose();
  }

  @override
  void notifyListeners() {
    _statVersion++;
    _dayStatCache.clear();
    super.notifyListeners();
  }

  List<Task> get allTasks => List<Task>.unmodifiable(_tasks);
  List<Tag> get allTags => List<Tag>.unmodifiable(_tags);
  int? get tagFilterId => _tagFilterId;
  int? get taskFilterId => _taskFilterId;

  /// 热力/统计当前筛选标题。
  String get filterTitle {
    final tag = tagFor(_tagFilterId);
    if (tag != null) return tag.name;
    final task = _tasks.where((item) => item.id == _taskFilterId).firstOrNull;
    if (task != null) return task.title;
    return '全部任务';
  }

  bool get isLoading => _loading;
  String? get loadError => _loadError;
  DateTime get today => _today;

  /// 回收站（已归档任务），最近归档的在前。
  List<Task> get archivedTasks {
    final list = _tasks.where((task) => task.isArchived).toList();
    list.sort((a, b) => (b.archivedAt ?? 0).compareTo(a.archivedAt ?? 0));
    return List<Task>.unmodifiable(list);
  }

  List<CheckinRecord> get allCheckinRecords {
    final result = <CheckinRecord>[];
    for (final day in _recordsByDate.values) {
      result.addAll(day.values);
    }
    result.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.taskId.compareTo(b.taskId);
    });
    return result;
  }

  Tag? tagFor(int? id) {
    if (id == null) return null;
    for (final tag in _tags) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  String? remarkFor(int? taskId, DateTime date) {
    if (taskId == null) return null;
    return _recordsByDate[AppDateUtils.formatKey(date)]?[taskId]?.remark;
  }

  void setTagFilter(int? tagId) {
    if (_tagFilterId == tagId && _taskFilterId == null) return;
    _tagFilterId = tagId;
    _taskFilterId = null;
    notifyListeners();
  }

  void setTaskFilter(int? taskId) {
    if (_taskFilterId == taskId && _tagFilterId == null) return;
    _taskFilterId = taskId;
    _tagFilterId = null;
    notifyListeners();
  }

  void clearStatFilter() {
    if (_tagFilterId == null && _taskFilterId == null) return;
    _tagFilterId = null;
    _taskFilterId = null;
    notifyListeners();
  }

  List<Task> get visibleDailyTasks {
    return dailyTasks
        .where((task) => _tagFilterId == null || task.tagId == _tagFilterId)
        .toList(growable: false);
  }

  List<Task> get visibleTodoTasks {
    return todoTasks
        .where((task) => _tagFilterId == null || task.tagId == _tagFilterId)
        .toList(growable: false);
  }

  /// 今日显示的每日任务（含已完成）。
  List<Task> get dailyTasks {
    return _tasks
        .where((task) {
          return task.type == TaskType.daily &&
              !task.isArchived &&
              StatsCalculator.isTaskActiveOn(task, _today, today: _today);
        })
        .toList(growable: false);
  }

  /// 今日显示的临时待办：包含已逾期但尚未完成的，逾期项弱高亮。
  List<Task> get todoTasks {
    return _tasks
        .where((task) {
          if (task.type != TaskType.todo ||
              task.isArchived ||
              task.completedAt != null) {
            return false;
          }
          if (StatsCalculator.isTaskActiveOn(task, _today, today: _today)) {
            return true;
          }
          final due = task.dueDate;
          return due != null && AppDateUtils.dayOnly(due).isBefore(_today);
        })
        .toList(growable: false);
  }

  /// 今日统计：包含当天已完成、已经从列表消失的临时待办。
  /// 今日页只跟随标签筛选；热力/统计的单任务筛选不影响今日清单。
  DayStat get todayStat => statsFor(_today, tagId: _tagFilterId);

  int get completedDailyCount =>
      dailyTasks.where((task) => isDailyDone(task)).length;

  bool isDailyDone(Task task, {DateTime? date}) {
    final taskId = task.id;
    if (taskId == null) return false;
    final day = date ?? _today;
    return _checkinsByDate[AppDateUtils.formatKey(day)]?.contains(taskId) ??
        false;
  }

  bool isTodoDone(Task task) => task.completedAt != null;

  /// 启动时加载全部任务与全部打卡。
  ///
  /// 数据量很小；一次载入后打卡直接改内存，热力月历翻页不再查库。
  Future<void> load() async {
    final token = ++_loadToken;
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      final tasks = await _db.loadAllTasks();
      final records = await _db.loadAllCheckins();
      final tags = await _db.loadTags();
      if (token != _loadToken) return;

      _tasks = _sortTasks(tasks);
      _recordsByDate = _groupRecords(records);
      _checkinsByDate = _groupCheckins(records);
      _tags = tags;
      // 删除/导入后旧筛选可能指向不存在的数据，启动时归零。
      if (!_tags.any((tag) => tag.id == _tagFilterId)) _tagFilterId = null;
      if (!_tasks.any((task) => task.id == _taskFilterId)) _taskFilterId = null;
      _today = AppDateUtils.dayOnly(DateTime.now());
    } catch (error) {
      if (token != _loadToken) return;
      _loadError = '数据加载失败：$error';
      debugPrint(_loadError);
      unawaited(LocalLogService.log('数据库加载失败', error: error));
    } finally {
      if (token == _loadToken) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> reload() => load();

  /// 跨天刷新：只换“今天”的日期，不修改数据库。
  ///
  /// 新一天没有 checkins 记录，所以每日任务自然显示为未完成；
  /// 昨天的记录仍然用于历史热力图。
  void refreshToday() {
    final nowDay = AppDateUtils.dayOnly(DateTime.now());
    if (AppDateUtils.isSameDay(nowDay, _today)) return;
    _today = nowDay;
    notifyListeners();
  }

  List<Task> tasksForTag(int? tagId) {
    if (tagId == null) return List<Task>.unmodifiable(_tasks);
    return _tasks.where((task) => task.tagId == tagId).toList(growable: false);
  }

  /// 热力/统计维度筛选：单任务优先，其次单标签，最后全部。
  List<Task> tasksForFilter({int? tagId, int? taskId}) {
    if (taskId != null) {
      return _tasks.where((task) => task.id == taskId).toList(growable: false);
    }
    return tasksForTag(tagId);
  }

  /// 统计页当前生效的任务集合（跟随全局筛选项）。
  List<Task> get _analysisTasks =>
      tasksForFilter(tagId: _tagFilterId, taskId: _taskFilterId);

  DayStat statsFor(DateTime date, {int? tagId, int? taskId}) {
    final key =
        '$_statVersion|${AppDateUtils.formatKey(date)}|${tagId ?? 'all'}|${taskId ?? 'all'}';
    final cached = _dayStatCache[key];
    if (cached != null) return cached;
    final stat = StatsCalculator.calculateDayCompletion(
      date: date,
      tasks: tasksForFilter(tagId: tagId, taskId: taskId),
      dailyCheckins: _checkinsByDate,
      today: _today,
    );
    _dayStatCache[key] = stat;
    return stat;
  }

  final Map<String, MonthStats> _monthStatsCache = <String, MonthStats>{};

  MonthStats monthStats(DateTime month, {int? tagId, int? taskId}) {
    final key =
        '$_statVersion|${month.year}-${month.month}|${tagId ?? 'all'}|${taskId ?? 'all'}';
    final cached = _monthStatsCache[key];
    if (cached != null) return cached;
    final value = StatsCalculator.getMonthStats(
      month: month,
      tasks: tasksForFilter(tagId: tagId, taskId: taskId),
      dailyCheckins: _checkinsByDate,
      today: _today,
    );
    if (_monthStatsCache.length > 36) _monthStatsCache.clear();
    _monthStatsCache[key] = value;
    return value;
  }

  PeriodCompletion periodStats(
    DateTime start,
    DateTime end, {
    int? tagId,
    int? taskId,
  }) => StatsCalculator.periodStats(
    start: start,
    end: end,
    tasks: tasksForFilter(tagId: tagId, taskId: taskId),
    dailyCheckins: _checkinsByDate,
    today: _today,
  );

  /// 任务累计天数/最长连续排行（每日任务取历史，待办按完成计 1 天）。
  List<TaskRanking> get taskRankings {
    final result = <TaskRanking>[];
    for (final task in _analysisTasks) {
      if (task.type == TaskType.daily) {
        final stats = taskStats(task);
        if (stats.totalDays > 0) {
          result.add(
            TaskRanking(
              task: task,
              totalDays: stats.totalDays,
              longestStreak: stats.longestStreak,
            ),
          );
        }
      } else if (task.completedAt != null) {
        result.add(TaskRanking(task: task, totalDays: 1, longestStreak: 1));
      }
    }
    result.sort((a, b) {
      final byTotal = b.totalDays.compareTo(a.totalDays);
      return byTotal != 0
          ? byTotal
          : b.longestStreak.compareTo(a.longestStreak);
    });
    return result;
  }

  /// 全局全勤连续天数（有任务且全部完成）。
  int get currentPerfectStreak => StatsCalculator.currentPerfectStreak(
    tasks: _analysisTasks,
    dailyCheckins: _checkinsByDate,
    today: _today,
  );

  List<DayStat> get last30Days => StatsCalculator.recentDays(
    days: 30,
    tasks: _analysisTasks,
    dailyCheckins: _checkinsByDate,
    today: _today,
  );

  List<double> get last12WeekRates => StatsCalculator.recentWeekRates(
    weeks: 12,
    tasks: _analysisTasks,
    dailyCheckins: _checkinsByDate,
    today: _today,
  );

  /// 最近一年按标签汇总：累计打卡天数、平均完成率、最长连续。
  List<TagPerformance> get tagPerformance {
    final result = <TagPerformance>[];
    // 按年月日回退，避免夏令时让“最近一年”少/多一天。
    final start = DateTime(_today.year, _today.month, _today.day - 364);
    for (final tag in _tags) {
      var activeDays = 0;
      var completedDays = 0;
      var rateSum = 0.0;
      var best = 0;
      var streak = 0;
      var cursor = start;
      final tagTasks = tasksForTag(tag.id);
      while (!cursor.isAfter(_today)) {
        final stat = StatsCalculator.calculateDayCompletion(
          date: cursor,
          tasks: tagTasks,
          dailyCheckins: _checkinsByDate,
          today: _today,
        );
        if (stat.hasTasks) {
          activeDays++;
          rateSum += stat.rate;
          if (stat.completed > 0) {
            completedDays++;
            streak++;
            if (streak > best) best = streak;
          } else {
            streak = 0;
          }
        }
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }
      result.add(
        TagPerformance(
          tagId: tag.id!,
          name: tag.name,
          totalDays: completedDays,
          averageRate: activeDays == 0 ? 0 : rateSum / activeDays,
          longestStreak: best,
        ),
      );
    }
    result.sort((a, b) => b.totalDays.compareTo(a.totalDays));
    return result;
  }

  /// 类型维度：任务数量与累计完成量；完成率取最近 30 天平均。
  TypePerformance get typePerformance {
    final daily = _analysisTasks
        .where((task) => task.type == TaskType.daily)
        .toList();
    final todo = _analysisTasks
        .where((task) => task.type == TaskType.todo)
        .toList();
    final start = DateTime(_today.year, _today.month, _today.day - 29);
    var dailyActive = 0;
    var todoActive = 0;
    var dailyRate = 0.0;
    var todoRate = 0.0;
    var cursor = start;
    while (!cursor.isAfter(_today)) {
      final d = StatsCalculator.calculateDayCompletion(
        date: cursor,
        tasks: daily,
        dailyCheckins: _checkinsByDate,
        today: _today,
      );
      final t = StatsCalculator.calculateDayCompletion(
        date: cursor,
        tasks: todo,
        dailyCheckins: _checkinsByDate,
        today: _today,
      );
      if (d.hasTasks) {
        dailyActive++;
        dailyRate += d.rate;
      }
      if (t.hasTasks) {
        todoActive++;
        todoRate += t.rate;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return TypePerformance(
      dailyTotal: daily.length,
      dailyDone: _checkinsByDate.values.fold(
        0,
        (sum, ids) =>
            sum + ids.where((id) => daily.any((task) => task.id == id)).length,
      ),
      todoTotal: todo.length,
      todoDone: todo.where((task) => task.completedAt != null).length,
      dailyRate: dailyActive == 0 ? 0 : dailyRate / dailyActive,
      todoRate: todoActive == 0 ? 0 : todoRate / todoActive,
    );
  }

  /// 0~23 点的打卡频次；包含每日打卡与已完成待办。
  HourDistribution get hourDistribution {
    final counts = List<int>.filled(24, 0);
    final ids = _analysisTasks.map((task) => task.id).whereType<int>().toSet();
    for (final record in allCheckinRecords) {
      if (!ids.contains(record.taskId)) continue;
      final ts = record.completedTs;
      if (ts <= 0) continue;
      counts[DateTime.fromMillisecondsSinceEpoch(ts).hour]++;
    }
    for (final task in _analysisTasks) {
      final ts = task.completedAt;
      if (task.type == TaskType.todo && ts != null) {
        counts[DateTime.fromMillisecondsSinceEpoch(ts).hour]++;
      }
    }
    return HourDistribution(counts);
  }

  /// 周期表现：一年内最长全勤、最长空窗、最佳月份、平均完成率。
  PeriodPerformance get periodPerformance {
    var cursor = DateTime(_today.year, _today.month, _today.day - 364);
    var streak = 0;
    var bestStreak = 0;
    final completedDates = <DateTime>[];
    while (!cursor.isAfter(_today)) {
      final stat = StatsCalculator.calculateDayCompletion(
        date: cursor,
        tasks: _analysisTasks,
        dailyCheckins: _checkinsByDate,
        today: _today,
      );
      if (stat.hasTasks && stat.isPerfect) {
        streak++;
        if (streak > bestStreak) bestStreak = streak;
      } else if (stat.hasTasks) {
        streak = 0;
      }
      if (stat.completed > 0) completedDates.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    var longestGap = 0;
    for (var i = 1; i < completedDates.length; i++) {
      final gap = AppDateUtils.daysBetween(
        completedDates[i - 1],
        completedDates[i],
      );
      if (gap - 1 > longestGap) longestGap = gap - 1;
    }

    var bestMonth = DateTime(_today.year, _today.month);
    var bestRate = -1.0;
    var rateSum = 0.0;
    var monthCount = 0;
    for (var i = 0; i < 24; i++) {
      final month = DateTime(_today.year, _today.month - i);
      final stats = monthStats(month);
      if (stats.activeDays == 0) continue;
      rateSum += stats.averageRate;
      monthCount++;
      if (stats.averageRate > bestRate) {
        bestRate = stats.averageRate;
        bestMonth = stats.month;
      }
    }

    return PeriodPerformance(
      longestPerfectStreak: bestStreak,
      longestGapDays: longestGap,
      bestMonth: monthCount == 0 ? null : bestMonth,
      bestMonthRate: bestRate < 0 ? 0 : bestRate,
      averageRate: monthCount == 0 ? 0 : rateSum / monthCount,
    );
  }

  List<Task> searchTasks(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <Task>[];
    return _tasks
        .where(
          (task) => !task.isArchived && task.title.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  /// 有任意完成任务的自然日数量（按天去重）。
  int get totalCheckinDays =>
      _checkinsByDate.values.where((ids) => ids.isNotEmpty).length;

  /// 全局最长连续打卡天数：连续自然日至少完成一项任务。
  int get overallLongestStreak {
    final keys =
        _checkinsByDate.entries
            .where((entry) => entry.value.isNotEmpty)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    if (keys.isEmpty) return 0;
    var longest = 1;
    var running = 1;
    var previous = AppDateUtils.parseKey(keys.first);
    for (var i = 1; i < keys.length; i++) {
      final current = AppDateUtils.parseKey(keys[i]);
      final expected = DateTime(
        previous.year,
        previous.month,
        previous.day + 1,
      );
      if (AppDateUtils.isSameDay(current, expected)) {
        running++;
      } else if (!AppDateUtils.isSameDay(current, previous)) {
        running = 1;
      }
      if (running > longest) longest = running;
      previous = current;
    }
    return longest;
  }

  /// 某一年的“有完成”天数，供年度热力图摘要使用。
  int completedDaysInYear(int year) => StatsCalculator.completedDayCount(
    tasks: _analysisTasks,
    dailyCheckins: _checkinsByDate,
    year: year,
    today: _today,
  );

  /// 每日任务打卡 / 取消打卡。
  Future<void> toggleDaily(Task task) async {
    final taskId = task.id;
    if (taskId == null || task.type != TaskType.daily) {
      throw ArgumentError('只能对已保存的每日任务打卡');
    }

    final key = AppDateUtils.formatKey(_today);
    final current = _checkinsByDate[key] ?? const <int>{};
    final isDone = current.contains(taskId);

    CheckinRecord? record;
    if (isDone) {
      final next = <int>{...current}..remove(taskId);
      _writeCheckinDay(key, next);
      _recordsByDate[key]?.remove(taskId);
    } else {
      final existing = _recordsByDate[key]?[taskId];
      record = CheckinRecord(
        taskId: taskId,
        date: key,
        completedTs: DateTime.now().millisecondsSinceEpoch,
        remark: existing?.remark,
      );
      _writeCheckinDay(key, <int>{...current, taskId});
      _writeRecord(record);
    }
    _pendingCheckins[taskId] = _PendingCheckin(
      date: key,
      done: !isDone,
      record: record,
    );
    _checkinWriteTimer?.cancel();
    _checkinWriteTimer = Timer(
      // 连续勾选时先只更新内存，手停 300ms 后再批量落库，
      // 让快速连点期间完全不产生磁盘写入。
      const Duration(milliseconds: 300),
      () => unawaited(_flushCheckins()),
    );

    _doneNotifiers[taskId]?.value = !isDone;
    _scheduleCheckinNotify();
  }

  Future<void> _flushCheckins() async {
    if (_pendingCheckins.isEmpty) return;
    final batch = Map<int, _PendingCheckin>.from(_pendingCheckins);
    _pendingCheckins.clear();
    try {
      for (final entry in batch.entries) {
        final pending = entry.value;
        if (pending.done) {
          await _db.setCheckin(pending.record!);
        } else {
          await _db.deleteCheckin(entry.key, pending.date);
        }
      }
    } catch (error) {
      unawaited(LocalLogService.log('打卡批量写入失败', error: error));
      // 写失败时以数据库为准回滚 UI，避免内存状态与持久化不一致。
      await reload();
    }
  }

  /// 指定历史日期补卡 / 取消补卡。未来日期由 UI 与服务层双重拦截。
  Future<void> toggleDailyOn(Task task, DateTime date, {String? remark}) async {
    final taskId = task.id;
    if (taskId == null || task.type != TaskType.daily) {
      throw ArgumentError('只能对已保存的打卡任务补卡');
    }
    final day = AppDateUtils.dayOnly(date);
    if (day.isAfter(_today)) throw ArgumentError('不能给未来日期补卡');
    // createdDate 含时分秒；补卡按自然日判断，创建当天也应允许。
    if (day.isBefore(AppDateUtils.dayOnly(task.createdDate))) {
      throw ArgumentError('不能早于任务创建日');
    }
    if (!task.isScheduledOn(day)) throw ArgumentError('该日期不在任务生效周期内');

    final key = AppDateUtils.formatKey(day);
    final current = _checkinsByDate[key] ?? const <int>{};
    final isDone = current.contains(taskId);

    if (isDone) {
      await _db.deleteCheckin(taskId, key);
      _writeCheckinDay(key, <int>{...current}..remove(taskId));
      _recordsByDate[key]?.remove(taskId);
    } else {
      final existing = _recordsByDate[key]?[taskId];
      final clean = remark?.trim();
      final record = CheckinRecord(
        taskId: taskId,
        date: key,
        completedTs: DateTime.now().millisecondsSinceEpoch,
        remark: clean == null || clean.isEmpty ? existing?.remark : clean,
      );
      await _db.setCheckin(record);
      _writeCheckinDay(key, <int>{...current, taskId});
      _writeRecord(record);
    }
    notifyListeners();
  }

  /// 热力日详情/任务详情的统一入口：按任务类型切换完成状态。
  ///
  /// 每日任务写 checkins；临时待办写 completedAt。未来日期统一拒绝。
  Future<void> toggleTaskOn(Task task, DateTime date, {String? remark}) {
    if (task.isDaily) return toggleDailyOn(task, date, remark: remark);
    return toggleTodoOn(task, date);
  }

  /// 历史/今日切换临时待办完成状态。
  ///
  /// 补到过去日期时把 completedAt 落在当天中午，统计仍按自然日归属。
  Future<void> toggleTodoOn(Task task, DateTime date) async {
    final taskId = task.id;
    if (taskId == null || task.type != TaskType.todo) {
      throw ArgumentError('只能操作已保存的临时待办');
    }
    final day = AppDateUtils.dayOnly(date);
    if (day.isAfter(_today)) throw ArgumentError('不能给未来日期补卡');
    if (day.isBefore(AppDateUtils.dayOnly(task.createdDate))) {
      throw ArgumentError('不能早于任务创建日');
    }
    final due = task.dueDate;
    if (due != null && day.isAfter(AppDateUtils.dayOnly(due))) {
      throw ArgumentError('该日期已超过截止日');
    }

    final completed = task.completedDate;
    final isDoneOnDay =
        completed != null && AppDateUtils.isSameDay(completed, day);
    final timestamp = isDoneOnDay
        ? null
        : (AppDateUtils.isSameDay(day, _today)
              ? DateTime.now().millisecondsSinceEpoch
              : day.add(const Duration(hours: 12)).millisecondsSinceEpoch);
    await _db.updateTaskCompletedAt(taskId, timestamp);
    _replaceTask(task.copyWith(completedAt: timestamp));
    notifyListeners();
  }

  /// 打卡完成时间：每日任务读 checkins，临时待办读 completedAt。
  DateTime? completionAtFor(Task task, DateTime date) {
    final id = task.id;
    if (id == null) return null;
    if (task.isDaily) {
      final cached = _recordsByDate[AppDateUtils.formatKey(date)]?[id];
      if (cached != null) {
        return DateTime.fromMillisecondsSinceEpoch(cached.completedTs);
      }
      return null;
    }
    final completed = task.completedDate;
    if (completed == null) return null;
    return AppDateUtils.isSameDay(completed, date) ? completed : null;
  }

  /// 置顶/取消置顶。负数 sort_order 编码置顶，且保留置顶组内原顺序。
  Future<void> togglePin(Task task) async {
    final id = task.id;
    if (id == null) return;
    final nextOrder = task.isPinned
        ? task.sortOrder + Task.pinnedOffset
        : -Task.pinnedOffset + task.sortOrder.clamp(0, 999999);
    final next = task.copyWith(sortOrder: nextOrder);
    await _db.updateSortOrders(<Task>[next]);
    _replaceTask(next);
    _tasks = _sortTasks(_tasks);
    notifyListeners();
  }

  /// 开启设置后，把完成超过 [days] 天的临时待办软归档。
  /// 归档不删历史；回收站仍可恢复。
  Future<void> autoArchiveCompletedTodos(int days) async {
    if (days <= 0) return;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final targets = _tasks
        .where(
          (task) =>
              task.isTodo &&
              !task.isArchived &&
              task.completedAt != null &&
              task.completedAt! < cutoff,
        )
        .toList(growable: false);
    if (targets.isEmpty) return;
    await batchArchiveTasks(targets);
  }

  /// 批量更新任务属性；数据库事务失败时抛出，内存不变。
  Future<void> batchUpdateTasks(List<Task> updated) async {
    if (updated.isEmpty) return;
    final cleaned = <Task>[
      for (final task in updated)
        task.copyWith(
          title: task.title.trim(),
          weeklyTarget: task.weeklyTarget.clamp(1, 7),
          weekdayMask: task.weekdayMask & 0x7F,
        ),
    ];
    await _db.batchUpdateTasks(cleaned);
    final byId = <int, Task>{
      for (final task in cleaned)
        if (task.id != null) task.id!: task,
    };
    _tasks = _sortTasks(
      _tasks.map((task) => byId[task.id] ?? task).toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> batchArchiveTasks(List<Task> tasks) async {
    final ids = <int>[
      for (final task in tasks)
        if (task.id != null) task.id!,
    ];
    if (ids.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batchArchiveTasks(ids, now);
    _tasks = _tasks
        .map(
          (task) =>
              ids.contains(task.id) ? task.copyWith(archivedAt: now) : task,
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<List<String>> checkIntegrity() => _db.checkIntegrity();

  Future<void> repairIntegrity() async {
    await _db.repairIntegrity();
    await reload();
  }

  /// 完成临时待办：写 completedAt，完成后从今日列表消失。
  Future<void> completeTodo(Task task) async {
    final taskId = task.id;
    if (taskId == null || task.type != TaskType.todo) {
      throw ArgumentError('只能完成已保存的临时待办');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.updateTaskCompletedAt(taskId, now);
    _replaceTask(task.copyWith(completedAt: now));
    notifyListeners();
  }

  /// 撤销完成：重新出现在今日列表。
  Future<void> undoCompleteTodo(Task task) async {
    final taskId = task.id;
    if (taskId == null || task.type != TaskType.todo) {
      throw ArgumentError('只能撤销临时待办');
    }
    await _db.updateTaskCompletedAt(taskId, null);
    _replaceTask(task.copyWith(completedAt: null));
    notifyListeners();
  }

  /// 新建任务。每日任务从今天开始生效；待办创建后立即出现在今日列表。
  Future<Task> addTask({
    required String title,
    required TaskType type,
    TaskSchedule schedule = TaskSchedule.daily,
    int weeklyTarget = 7,
    int weekdayMask = 0x7F,
    int intervalDays = 1,
    int monthDaysMask = 0x1,
    int? yearlyMonth,
    int? yearlyDay,
    int? tagId,
    String? reminderTime,
    bool reminderEnabled = false,
    DateTime? dueDate,
    bool reminderEffectiveOnly = false,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('任务名称不能为空');
    _validateSchedule(
      type: type,
      schedule: schedule,
      weekdayMask: weekdayMask,
      intervalDays: intervalDays,
      monthDaysMask: monthDaysMask,
      yearlyMonth: yearlyMonth,
      yearlyDay: yearlyDay,
    );

    final now = DateTime.now();
    final nextOrder = _tasks.fold<int>(
      0,
      (maxOrder, task) => task.sortOrder > maxOrder ? task.sortOrder : maxOrder,
    );

    final draft = Task(
      title: cleanTitle,
      type: type,
      createdAt: now.millisecondsSinceEpoch,
      sortOrder: nextOrder + 1,
      schedule: type == TaskType.daily ? schedule : TaskSchedule.daily,
      weeklyTarget: weeklyTarget.clamp(1, 7),
      weekdayMask: weekdayMask & 0x7F,
      intervalDays: intervalDays.clamp(1, 365),
      monthDaysMask: monthDaysMask & 0x7FFFFFFF,
      yearlyMonth: yearlyMonth,
      yearlyDay: yearlyDay,
      tagId: tagId,
      reminderTime: reminderTime,
      reminderEnabled: reminderEnabled && reminderTime != null,
      dueAt: type == TaskType.todo && dueDate != null
          ? AppDateUtils.dayOnly(dueDate).millisecondsSinceEpoch
          : null,
      reminderEffectiveOnly: reminderEffectiveOnly,
    );

    final id = await _db.insertTask(draft);
    final created = draft.copyWith(id: id);
    _tasks = _sortTasks(<Task>[..._tasks, created]);
    notifyListeners();
    return created;
  }

  /// 周期配置在进入数据库前统一校验，避免“永不生效”的脏任务。
  void _validateSchedule({
    required TaskType type,
    required TaskSchedule schedule,
    required int weekdayMask,
    required int intervalDays,
    required int monthDaysMask,
    required int? yearlyMonth,
    required int? yearlyDay,
  }) {
    if (type != TaskType.daily) return;
    if (schedule == TaskSchedule.weekdays && (weekdayMask & 0x7F) == 0) {
      throw ArgumentError('至少选择一个生效星期');
    }
    if (schedule == TaskSchedule.intervalDays &&
        (intervalDays < 1 || intervalDays > 365)) {
      throw ArgumentError('间隔天数需在 1~365 之间');
    }
    if (schedule == TaskSchedule.monthlyDays &&
        (monthDaysMask & 0x7FFFFFFF) == 0) {
      throw ArgumentError('至少选择一个每月日期');
    }
    if (schedule == TaskSchedule.yearlyDate) {
      final month = yearlyMonth;
      final day = yearlyDay;
      if (month == null || month < 1 || month > 12) {
        throw ArgumentError('每年周期月份无效');
      }
      final maxDay = AppDateUtils.daysInMonth(DateTime(2024, month));
      if (day == null || day < 1 || day > maxDay) {
        throw ArgumentError('每年周期日期无效');
      }
    }
  }

  /// 编辑任务的全部可编辑属性。
  Future<void> updateTask(Task updated) async {
    final id = updated.id;
    if (id == null) throw ArgumentError('任务尚未保存');
    final cleanTitle = updated.title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('任务名称不能为空');
    _validateSchedule(
      type: updated.type,
      schedule: updated.schedule,
      weekdayMask: updated.weekdayMask,
      intervalDays: updated.intervalDays,
      monthDaysMask: updated.monthDaysMask,
      yearlyMonth: updated.yearlyMonth,
      yearlyDay: updated.yearlyDay,
    );
    final next = updated.copyWith(
      title: cleanTitle,
      weeklyTarget: updated.weeklyTarget.clamp(1, 7),
      weekdayMask: updated.weekdayMask & 0x7F,
      intervalDays: updated.intervalDays.clamp(1, 365),
      monthDaysMask: updated.monthDaysMask & 0x7FFFFFFF,
    );
    await _db.updateTask(next);
    _replaceTask(next);
    notifyListeners();
  }

  /// 保存某天打卡备注；没有打卡记录时不做无意义的插入。
  Future<void> setRemark(Task task, DateTime date, String? remark) async {
    final id = task.id;
    if (id == null) return;
    final key = AppDateUtils.formatKey(date);
    final record = _recordsByDate[key]?[id];
    if (record == null) return;
    final clean = remark?.trim().isEmpty == true ? null : remark?.trim();
    await _db.updateCheckinRemark(id, key, clean);
    _writeRecord(record.copyWith(remark: clean, clearRemark: clean == null));
    notifyListeners();
  }

  /// 修改某天打卡的完成时间；日期不变，只调整时分。
  Future<void> setCompletionTime(
    Task task,
    DateTime date,
    int hour,
    int minute,
  ) async {
    final id = task.id;
    if (id == null) return;
    final day = AppDateUtils.dayOnly(date);
    final key = AppDateUtils.formatKey(day);
    final ts = DateTime(
      day.year,
      day.month,
      day.day,
      hour,
      minute,
    ).millisecondsSinceEpoch;

    if (task.isDaily) {
      final record = _recordsByDate[key]?[id];
      if (record == null) return;
      await _db.updateCheckinTime(id, key, ts);
      _writeRecord(record.copyWith(completedTs: ts));
    } else {
      final completedAt = task.completedAt;
      if (completedAt == null ||
          !AppDateUtils.isSameDay(
            DateTime.fromMillisecondsSinceEpoch(completedAt),
            day,
          )) {
        return;
      }
      await _db.updateTaskCompletedAt(id, ts);
      _replaceTask(task.copyWith(completedAt: ts));
    }
    notifyListeners();
  }

  TaskStats taskStats(Task task) => StatsCalculator.taskStats(
    task: task,
    dailyCheckins: _checkinsByDate,
    today: _today,
  );

  /// 只重排当前可见的每日任务，其余任务顺序保持在后。
  ///
  /// UI 按“每日打卡 / 临时待办”分组展示，因此拖拽只改变每日组内的
  /// 相对顺序，不会把待办混进打卡组。
  Future<void> reorderVisibleDaily(List<Task> orderedDaily) async {
    final ids = <int>{
      for (final task in orderedDaily)
        if (task.id != null) task.id!,
    };
    final tail = _tasks.where((task) => !ids.contains(task.id)).toList();
    final pinnedIds = <int>{
      for (final task in orderedDaily)
        if (task.isPinned && task.id != null) task.id!,
    };
    await reorderTasks(<Task>[...orderedDaily, ...tail]);
    if (pinnedIds.isEmpty) return;

    // 拖拽会统一写正数顺序；这里重新把置顶任务编码成负数，保留置顶状态。
    final pinned = _tasks
        .where((task) => task.id != null && pinnedIds.contains(task.id))
        .toList(growable: false);
    final updates = <Task>[
      for (var i = 0; i < pinned.length; i++)
        pinned[i].copyWith(sortOrder: -Task.pinnedOffset + i),
    ];
    await _db.updateSortOrders(updates);
    final byId = <int, Task>{for (final task in updates) task.id!: task};
    _tasks = _sortTasks(
      _tasks.map((task) => byId[task.id] ?? task).toList(growable: false),
    );
    notifyListeners();
  }

  /// 拖拽排序后同步内存与 SQLite。
  Future<void> reorderTasks(List<Task> ordered) async {
    final updates = <Task>[];
    for (var i = 0; i < ordered.length; i++) {
      final task = ordered[i];
      if (task.id == null) continue;
      updates.add(task.copyWith(sortOrder: i + 1));
    }
    await _db.updateSortOrders(updates);
    final byId = <int, Task>{for (final task in updates) task.id!: task};
    _tasks = _sortTasks(
      _tasks.map((task) => byId[task.id] ?? task).toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> restoreTask(Task task) async {
    final id = task.id;
    if (id == null) return;
    await _db.restoreTask(id);
    _replaceTask(task.copyWith(archivedAt: null));
    notifyListeners();
  }

  Future<void> batchRestoreTasks(List<int> ids) async {
    if (ids.isEmpty) return;
    await _db.batchRestoreTasks(ids);
    final set = ids.toSet();
    _tasks = _tasks
        .map(
          (task) =>
              set.contains(task.id) ? task.copyWith(archivedAt: null) : task,
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> batchDeleteTasksPermanently(List<int> ids) async {
    if (ids.isEmpty) return;
    await _db.batchDeleteTasksPermanently(ids);
    final set = ids.toSet();
    _tasks = _tasks.where((task) => !set.contains(task.id)).toList();
    _checkinsByDate = <String, Set<int>>{
      for (final entry in _checkinsByDate.entries)
        if (entry.value.any(set.contains))
          entry.key: <int>{
            for (final id in entry.value)
              if (!set.contains(id)) id,
          }
        else
          entry.key: entry.value,
    };
    _recordsByDate = <String, Map<int, CheckinRecord>>{
      for (final entry in _recordsByDate.entries)
        entry.key: <int, CheckinRecord>{
          for (final record in entry.value.entries)
            if (!set.contains(record.key)) record.key: record.value,
        },
    };
    notifyListeners();
  }

  /// 回收站里的彻底删除：任务与它的打卡记录一起删除。
  Future<void> deleteTaskPermanently(Task task) async {
    final id = task.id;
    if (id == null) return;
    await _db.deleteTaskPermanently(id);
    _tasks = _tasks.where((item) => item.id != id).toList(growable: false);
    _checkinsByDate = <String, Set<int>>{
      for (final entry in _checkinsByDate.entries)
        if (entry.value.contains(id))
          entry.key: <int>{...entry.value}..remove(id)
        else
          entry.key: entry.value,
    };
    _recordsByDate = <String, Map<int, CheckinRecord>>{
      for (final entry in _recordsByDate.entries)
        entry.key: <int, CheckinRecord>{...entry.value}..remove(id),
    };
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 标签
  // ---------------------------------------------------------------------------

  Future<Tag> addTag(String name, {int color = 0xFF3B6FD4}) async {
    final clean = _validateTagName(name);
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.insertTag(
      Tag(name: clean, color: color, createdAt: createdAt),
    );
    final created = Tag(
      id: id,
      name: clean,
      color: color,
      createdAt: createdAt,
    );
    _tags = _sortTags(<Tag>[created, ..._tags]);
    notifyListeners();
    return created;
  }

  Future<void> renameTag(Tag tag, String name) async {
    final id = tag.id;
    if (id == null) throw ArgumentError('标签尚未保存');
    final clean = _validateTagName(name, exceptId: id);
    final updated = tag.copyWith(name: clean);
    await _db.updateTag(updated);
    _tags = _tags.map((item) => item.id == id ? updated : item).toList();
    notifyListeners();
  }

  /// 校验标签名：去空格、禁止空/超长/忽略大小写重名。
  String _validateTagName(String name, {int? exceptId}) {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('标签名称不能为空');
    if (clean.length > 20) throw ArgumentError('标签名称最多 20 个字符');
    final lower = clean.toLowerCase();
    if (_tags.any(
      (tag) => tag.id != exceptId && tag.name.toLowerCase() == lower,
    )) {
      throw ArgumentError('标签已存在');
    }
    return clean;
  }

  List<Tag> _sortTags(List<Tag> tags) {
    final sorted = <Tag>[...tags];
    sorted.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : (b.id ?? 0).compareTo(a.id ?? 0);
    });
    return sorted;
  }

  Future<void> toggleTagPinned(Tag tag) async {
    final id = tag.id;
    if (id == null) return;
    final updated = tag.copyWith(pinned: !tag.pinned);
    await _db.updateTag(updated);
    _tags = _sortTags(
      _tags.map((item) => item.id == id ? updated : item).toList(),
    );
    notifyListeners();
  }

  Future<void> deleteTag(Tag tag) async {
    final id = tag.id;
    if (id == null) return;
    await _db.deleteTag(id);
    _tags = _tags.where((item) => item.id != id).toList();
    _tasks = _tasks
        .map((task) => task.tagId == id ? task.copyWith(tagId: null) : task)
        .toList(growable: false);
    if (_tagFilterId == id) _tagFilterId = null;
    notifyListeners();
  }

  Future<void> renameTask(Task task, String title) async {
    final taskId = task.id;
    final cleanTitle = title.trim();
    if (taskId == null) throw ArgumentError('任务尚未保存');
    if (cleanTitle.isEmpty) throw ArgumentError('任务名称不能为空');

    await _db.updateTaskTitle(taskId, cleanTitle);
    _replaceTask(task.copyWith(title: cleanTitle));
    notifyListeners();
  }

  /// 软归档；不删除任务和打卡，历史热力图仍能显示归档前的记录。
  Future<void> archiveTask(Task task) async {
    final taskId = task.id;
    if (taskId == null) throw ArgumentError('任务尚未保存');

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.archiveTask(taskId, now);
    _replaceTask(task.copyWith(archivedAt: now));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------

  List<Task> _sortTasks(Iterable<Task> tasks) {
    final list = List<Task>.from(tasks);
    list.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return list;
  }

  Map<String, Set<int>> _groupCheckins(List<CheckinRecord> records) {
    final map = <String, Set<int>>{};
    for (final record in records) {
      map.putIfAbsent(record.date, () => <int>{}).add(record.taskId);
    }
    return map;
  }

  Map<String, Map<int, CheckinRecord>> _groupRecords(
    List<CheckinRecord> records,
  ) {
    final map = <String, Map<int, CheckinRecord>>{};
    for (final record in records) {
      map.putIfAbsent(
        record.date,
        () => <int, CheckinRecord>{},
      )[record.taskId] = record;
    }
    return map;
  }

  void _writeRecord(CheckinRecord record) {
    final next = <String, Map<int, CheckinRecord>>{..._recordsByDate};
    final day = <int, CheckinRecord>{...?next[record.date]};
    day[record.taskId] = record;
    next[record.date] = day;
    _recordsByDate = next;
  }

  void _writeCheckinDay(String key, Set<int> ids) {
    final next = Map<String, Set<int>>.from(_checkinsByDate);
    if (ids.isEmpty) {
      next.remove(key);
    } else {
      next[key] = Set<int>.unmodifiable(ids);
    }
    _checkinsByDate = next;
  }

  void _replaceTask(Task updated) {
    final id = updated.id;
    if (id == null) return;
    _tasks = _tasks
        .map((task) => task.id == id ? updated : task)
        .toList(growable: false);
  }
}

class _PendingCheckin {
  const _PendingCheckin({
    required this.date,
    required this.done,
    required this.record,
  });

  final String date;
  final bool done;
  final CheckinRecord? record;
}
