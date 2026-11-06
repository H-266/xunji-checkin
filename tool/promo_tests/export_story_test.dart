// Story states for the promo: the day cell backfill arc on the month grid,
// a typed search, and the repeat-period picker.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xunji_checkin/providers/settings_provider.dart';
import 'package:xunji_checkin/providers/task_provider.dart';
import 'package:xunji_checkin/screens/task_search_screen.dart';
import 'package:xunji_checkin/screens/today_screen.dart';
import 'package:xunji_checkin/theme/app_theme.dart';

import 'promo_kit.dart';

final Map<String, List<double>> rects = {};

void record(WidgetTester t, String name, Finder f) {
  if (f.evaluate().isEmpty) {
    // ignore: avoid_print
    print('RECT_MISS $name');
    return;
  }
  final r = t.getRect(f.first);
  rects[name] = [r.left / kLogicalW, r.top / kLogicalH, r.width / kLogicalW, r.height / kLogicalH];
}

void main() {
  late dynamic originalOnError;

  setUpAll(() async {
    await loadPromoFonts();
    await bootDb();
    await seedDemo();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async => null);
  });

  tearDownAll(() async {
    final file = File('$promoRoot/assets/raw/rects.json');
    final old = await file.exists() ? jsonDecode(await file.readAsString()) as Map<String, dynamic> : <String, dynamic>{};
    old.addAll(rects);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(old));
    // ignore: avoid_print
    print('RECTS_WRITTEN ${rects.length}');
  });

  Future<void> scene(
    WidgetTester tester, {
    int tab = 0,
    int doneCount = -1,
    required Future<void> Function(WidgetTester, TaskProvider) body,
  }) async {
    originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    debugDisableShadows = false;
    try {
      await prepDevice(tester);
      late TaskProvider tasks;
      late SettingsProvider settings;
      await tester.runAsync(() async {
        final p = await bootProviders();
        tasks = p[0] as TaskProvider;
        settings = p[1] as SettingsProvider;
      });
      if (doneCount >= 0) {
        await tester.runAsync(() async {
          var done = tasks.dailyTasks.where(tasks.isDailyDone).length;
          for (final task in tasks.dailyTasks) {
            if (done >= doneCount) break;
            if (tasks.isDailyDone(task)) continue;
            await tasks.toggleDaily(task);
            done++;
          }
        });
      }
      await pumpApp(tester, wrapProviders(PromoApp(tab: tab), tasks, settings));
      await body(tester, tasks);
    } finally {
      debugDisableShadows = true;
      FlutterError.onError = originalOnError;
    }
  }

  testWidgets('cell backfill', (t) async {
    await scene(t, tab: 1, body: (t, p) async {
      await t.tap(find.byTooltip('上个月'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      record(t, 'cell_12', find.text('12'));

      final date = DateTime(2026, 10, 12);
      await t.runAsync(() async {
        var off = 0;
        for (final task in p.dailyTasks) {
          if (off >= 2) break;
          if (!p.isDailyDone(task, date: date)) continue;
          await p.toggleDailyOn(task, date);
          off++;
        }
      });
      await t.pump(const Duration(milliseconds: 300));
      await shoot(t, 'assets/raw/heatmap_oct_part.png');

      await t.tap(find.text('12').first);
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      record(t, 'dialog_box', find.byType(Dialog));
      await shoot(t, 'assets/raw/dlg_partial.png');

      await t.runAsync(() async {
        for (final task in p.dailyTasks) {
          if (p.isDailyDone(task, date: date)) continue;
          await p.toggleDailyOn(task, date);
        }
      });
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await shoot(t, 'assets/raw/dlg_full.png');

      await t.tap(find.text('知道了').first);
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await shoot(t, 'assets/raw/heatmap_oct_full.png');
    });
  });

  testWidgets('search typed', (t) async {
    await scene(t, doneCount: 1, body: (t, p) async {
      final ctx = t.element(find.byType(TodayScreen));
      final theme = promoTheme(AppTheme.build(hue: 220, brightness: Brightness.dark));
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(builder: (_) => Theme(data: theme, child: const TaskSearchScreen())),
      );
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await t.enterText(field.first, '跑');
        await t.pump(const Duration(milliseconds: 400));
        await t.pump(const Duration(milliseconds: 400));
      }
      await shoot(t, 'assets/raw/search_q.png');
    });
  });

  testWidgets('create sheet period', (t) async {
    await scene(t, doneCount: 1, body: (t, p) async {
      await t.tap(find.byType(FloatingActionButton));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      final row = find.text('重复周期');
      if (row.evaluate().isNotEmpty) {
        await t.tap(row.first);
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));
      }
      await shoot(t, 'assets/raw/create_period.png');
    });
  });
}
