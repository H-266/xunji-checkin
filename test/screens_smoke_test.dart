import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:xunji_checkin/core/date_utils.dart';
import 'package:xunji_checkin/l10n/app_localizations.dart';
import 'package:xunji_checkin/core/stats.dart';
import 'package:xunji_checkin/models/task.dart';
import 'package:xunji_checkin/providers/settings_provider.dart';
import 'package:xunji_checkin/providers/task_provider.dart';
import 'package:xunji_checkin/screens/heatmap_screen.dart';
import 'package:xunji_checkin/screens/settings_screen.dart';
import 'package:xunji_checkin/screens/today_screen.dart';
import 'package:xunji_checkin/theme/app_theme.dart';

/// 用内存数据替代 SQLite，让页面测试不依赖 path_provider / 真机。
class _FakeTaskProvider extends TaskProvider {
  _FakeTaskProvider({
    required List<Task> tasks,
    required Map<String, Set<int>> checkins,
    required DateTime today,
  }) : _fakeTasks = [...tasks],
       _checkins = {...checkins},
       _fakeToday = today;

  final List<Task> _fakeTasks;
  final Map<String, Set<int>> _checkins;
  final DateTime _fakeToday;
  int _nextId = 100;

  @override
  bool get isLoading => false;

  @override
  String? get loadError => null;

  @override
  DateTime get today => _fakeToday;

  @override
  DayStat get todayStat => StatsCalculator.calculateDayCompletion(
    date: _fakeToday,
    tasks: _fakeTasks,
    dailyCheckins: _checkins,
    today: _fakeToday,
  );

  @override
  List<Task> get dailyTasks => _fakeTasks
      .where(
        (task) =>
            task.type == TaskType.daily &&
            !task.isArchived &&
            StatsCalculator.isTaskActiveOn(task, _fakeToday, today: _fakeToday),
      )
      .toList();

  @override
  List<Task> get todoTasks => _fakeTasks
      .where(
        (task) =>
            task.type == TaskType.todo &&
            !task.isArchived &&
            task.completedAt == null &&
            StatsCalculator.isTaskActiveOn(task, _fakeToday, today: _fakeToday),
      )
      .toList();

  @override
  bool isDailyDone(Task task, {DateTime? date}) {
    final id = task.id;
    if (id == null) return false;
    final day = date ?? _fakeToday;
    return _checkins[AppDateUtils.formatKey(day)]?.contains(id) ?? false;
  }

  @override
  DayStat statsFor(DateTime date, {int? tagId, int? taskId}) =>
      StatsCalculator.calculateDayCompletion(
        date: date,
        tasks: _fakeTasks,
        dailyCheckins: _checkins,
        today: _fakeToday,
      );

  @override
  MonthStats monthStats(DateTime month, {int? tagId, int? taskId}) =>
      StatsCalculator.getMonthStats(
        month: month,
        tasks: _fakeTasks,
        dailyCheckins: _checkins,
        today: _fakeToday,
      );

  @override
  Future<void> reload() async {}

  @override
  Future<void> toggleDaily(Task task) async {
    final id = task.id;
    if (id == null) return;
    final key = AppDateUtils.formatKey(_fakeToday);
    final ids = {...?_checkins[key]};
    if (!ids.remove(id)) ids.add(id);
    if (ids.isEmpty) {
      _checkins.remove(key);
    } else {
      _checkins[key] = ids;
    }
    notifyListeners();
  }

  @override
  Future<void> completeTodo(Task task) async {
    final id = task.id;
    if (id == null) return;
    _replace(task.copyWith(completedAt: _fakeToday.millisecondsSinceEpoch));
    notifyListeners();
  }

  @override
  Future<void> undoCompleteTodo(Task task) async {
    final id = task.id;
    if (id == null) return;
    _replace(task.copyWith(completedAt: null));
    notifyListeners();
  }

  @override
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
    final task = Task(
      id: _nextId++,
      title: title.trim(),
      type: type,
      createdAt: _fakeToday.millisecondsSinceEpoch,
      sortOrder: _fakeTasks.length + 1,
      schedule: schedule,
      weeklyTarget: weeklyTarget,
      weekdayMask: weekdayMask,
      intervalDays: intervalDays,
      monthDaysMask: monthDaysMask,
      yearlyMonth: yearlyMonth,
      yearlyDay: yearlyDay,
      tagId: tagId,
      reminderTime: reminderTime,
      reminderEnabled: reminderEnabled,
      dueAt: dueDate?.millisecondsSinceEpoch,
      reminderEffectiveOnly: reminderEffectiveOnly,
    );
    _fakeTasks.add(task);
    notifyListeners();
    return task;
  }

  @override
  Future<void> renameTask(Task task, String title) async {
    _replace(task.copyWith(title: title.trim()));
    notifyListeners();
  }

  @override
  Future<void> archiveTask(Task task) async {
    _replace(task.copyWith(archivedAt: _fakeToday.millisecondsSinceEpoch));
    notifyListeners();
  }

  void _replace(Task updated) {
    final index = _fakeTasks.indexWhere((task) => task.id == updated.id);
    if (index >= 0) _fakeTasks[index] = updated;
  }
}

Widget _wrap(TaskProvider tasks, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TaskProvider>.value(value: tasks),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.build(hue: 152, brightness: Brightness.light),
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  final today = DateTime(2026, 11, 4);
  final daily = Task(
    id: 1,
    title: 'Drink',
    type: TaskType.daily,
    createdAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
    sortOrder: 1,
  );
  final todo = Task(
    id: 2,
    title: 'Run',
    type: TaskType.todo,
    createdAt: DateTime(2026, 11, 3).millisecondsSinceEpoch,
    sortOrder: 2,
  );

  testWidgets('今日页展示两类任务并允许勾选与新建', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tasks = _FakeTaskProvider(
      tasks: [daily, todo],
      checkins: {
        AppDateUtils.formatKey(today): {1},
      },
      today: today,
    );

    await tester.pumpWidget(_wrap(tasks, const TodayScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Drink'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('50%'), findsWidgets);

    // 勾选第二条（Run）：待办从列表消失，但今日统计应变成 2/2。
    await tester.tap(find.byKey(const ValueKey<String>('check-2')));
    await tester.pumpAndSettle();
    expect(tasks.todayStat.completed, 2);
    expect(find.text('100%'), findsWidgets);

    await tester.tap(find.text('新建任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Walk');
    await tester.tap(find.text('添加任务'));
    await tester.pumpAndSettle();
    expect(find.text('Walk'), findsOneWidget);
  });

  testWidgets('热力页展示月指标与日详情弹窗', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tasks = _FakeTaskProvider(
      tasks: [
        daily,
        todo.copyWith(completedAt: today.millisecondsSinceEpoch),
      ],
      checkins: {
        AppDateUtils.formatKey(today): {1},
      },
      today: today,
    );

    await tester.pumpWidget(_wrap(tasks, const HeatmapScreen()));
    await tester.pumpAndSettle();

    expect(find.text('每一天，一格'), findsOneWidget);
    expect(find.text('2026年11月'), findsOneWidget);
    // 11/1~11/3 有任务但未完成，11/4 两项全完成，月平均为 25%。
    expect(find.text('25%'), findsOneWidget);

    // 月历第 2 行第 4 格是 11 月 4 日；点格子文字即可命中 InkWell。
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(find.text('2026年11月4日'), findsOneWidget);
    expect(find.text('星期三 · 完成 2/2'), findsOneWidget);
    expect(find.text('Drink'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
  });

  testWidgets('设置页展示外观 / 数据 / 保活三组入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tasks = _FakeTaskProvider(
      tasks: [daily],
      checkins: {
        AppDateUtils.formatKey(today): {1},
      },
      today: today,
    );

    await tester.pumpWidget(_wrap(tasks, const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('按自己的习惯来'), findsOneWidget);
    expect(find.text('外观设置'), findsOneWidget);

    // ListView 懒构建，逐段滚动验证通用设置、数据与保活入口。
    await tester.scrollUntilVisible(
      find.text('数据管理'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('数据管理'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('导出 JSON 备份'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('导出 JSON 备份'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('保活帮助'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('保活帮助'), findsOneWidget);
  });
}
