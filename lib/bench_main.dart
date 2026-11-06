// 真机性能测试专用入口，不参与正式 APK 构建。
//
// 用法：
//   flutter run --profile -t lib/bench_main.dart
//
// 首次启动会向本地数据库补 100 条每日任务，用于滑动/连续打卡/年度
// 热力图测试；任务标题以 Bench- 开头，方便识别和清理。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'main.dart';
import 'models/task.dart';
import 'providers/settings_provider.dart';
import 'providers/task_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 真机 Profile 帧耗时：build/raster/total 全部写入 logcat，
  // 用 adb logcat -s flutter 采集，不依赖第三方 profiler。
  WidgetsBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      debugPrint(
        'BENCH_FRAME build=${timing.buildDuration.inMicroseconds} '
        'raster=${timing.rasterDuration.inMicroseconds} '
        'total=${timing.totalSpan.inMicroseconds}',
      );
    }
  });
  final db = AppDatabase.instance;
  // 性能测试不需要新手引导遮挡首屏。
  await db.setSetting('onboarding_seen', '1');
  await db.setSetting('privacy_accepted', '1');
  final existing = await db.loadAllTasks();
  final seeded = existing
      .where((task) => task.title.startsWith('Bench-'))
      .length;
  final today = DateTime.now();
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final createdAt = yesterday.millisecondsSinceEpoch;
  if (seeded < 100) {
    for (var i = seeded; i < 100; i++) {
      await db.insertTask(
        Task(
          title: 'Bench-${(i + 1).toString().padLeft(3, '0')}',
          type: TaskType.daily,
          createdAt: createdAt,
          sortOrder: i,
        ),
      );
    }
  }
  // 给昨天准备 100 条已完成记录，用于测“日详情一次渲染 100 行”的帧耗时；
  // 今天仍是 0/100，不影响连续勾选测试。
  final yesterdayKey =
      '${yesterday.year.toString().padLeft(4, '0')}-'
      '${yesterday.month.toString().padLeft(2, '0')}-'
      '${yesterday.day.toString().padLeft(2, '0')}';
  final benchTasks = (await db.loadAllTasks())
      .where((task) => task.title.startsWith('Bench-'))
      .toList();
  for (final task in benchTasks) {
    if (task.id == null) continue;
    if (task.createdAt > createdAt) {
      await db.updateTask(task.copyWith(createdAt: createdAt));
    }
    await db.setCheckin(
      CheckinRecord(
        taskId: task.id!,
        date: yesterdayKey,
        completedTs: yesterday.millisecondsSinceEpoch,
      ),
    );
  }

  final taskProvider = TaskProvider();
  await taskProvider.load();
  final settingsProvider = SettingsProvider();
  await settingsProvider.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<TaskProvider>.value(value: taskProvider),
      ],
      child: const XunjiApp(),
    ),
  );

  // 真机无法稳定用 adb 点中列表行，这里走与 Checkbox 完全相同的
  // Provider 更新路径，连点 3 轮、每轮 20 次，采集真实 UI 帧。
  // 只有显式 --dart-define=AUTO_CHECKIN=true 时才运行，避免污染
  // 日详情/滚动等其他测量。
  const autoCheckin = bool.fromEnvironment('AUTO_CHECKIN');
  const autoTheme = bool.fromEnvironment('AUTO_THEME');
  if (autoTheme) {
    Future<void>.delayed(const Duration(seconds: 2), () async {
      debugPrint('BENCH_THEME_START');
      await settingsProvider.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await settingsProvider.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      debugPrint('BENCH_THEME_END');
    });
  }

  if (autoCheckin) {
    Future<void>.delayed(const Duration(seconds: 2), () async {
      final daily = taskProvider.dailyTasks.take(20).toList();
      for (var round = 1; round <= 3; round++) {
        debugPrint('BENCH_CHECK_START round=$round');
        for (final task in daily) {
          await taskProvider.toggleDaily(task);
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
        debugPrint('BENCH_CHECK_END round=$round');
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    });
  }
}
