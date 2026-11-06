// Interaction states for the promo: dialog, progressive check-in, swipe,
// search, create-task sheet, and every home-widget card size.
// Each scene normalises the demo data to the state it needs *before* pumping,
// so tests stay independent of execution order.
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

List<double> norm(WidgetTester t, Finder f) {
  final r = t.getRect(f.first);
  return [r.left / kLogicalW, r.top / kLogicalH, r.width / kLogicalW, r.height / kLogicalH];
}

void record(WidgetTester t, String name, Finder f) {
  if (f.evaluate().isEmpty) {
    // ignore: avoid_print
    print('RECT_MISS $name');
    return;
  }
  rects[name] = norm(t, f);
}

/// Toggle today's tasks until exactly [want] of them are done.
Future<void> setDone(WidgetTester t, TaskProvider p, int want) async {
  await t.runAsync(() async {
    var done = p.dailyTasks.where(p.isDailyDone).length;
    for (final task in p.dailyTasks) {
      if (done >= want) break;
      if (p.isDailyDone(task)) continue;
      await p.toggleDaily(task);
      done++;
    }
    for (final task in p.dailyTasks) {
      if (done <= want) break;
      if (!p.isDailyDone(task)) continue;
      await p.toggleDaily(task);
      done--;
    }
  });
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
    originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // The widget config page has a real 2.5px Row overflow; it must not fail
      // an export run.
      if (details.exceptionAsString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
  });

  tearDownAll(() async {
    final file = File('$promoRoot/assets/raw/rects.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(rects));
    // ignore: avoid_print
    print('RECTS_WRITTEN ${rects.length}');
  });

  Future<void> scene(
    WidgetTester tester, {
    int tab = 0,
    Widget? page,
    int doneCount = -1,
    required Future<void> Function(WidgetTester, TaskProvider) body,
  }) async {
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
      if (doneCount >= 0) await setDone(tester, tasks, doneCount);
      await pumpApp(tester, wrapProviders(PromoApp(tab: tab, page: page), tasks, settings));
      await body(tester, tasks);
    } finally {
      debugDisableShadows = true;
    }
  }

  testWidgets('heatmap dialog', (t) async {
    await scene(t, tab: 1, body: (t, p) async {
      await t.tap(find.byTooltip('上个月'));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('15').first);
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      record(t, 'dialog', find.byType(AlertDialog));
      await shoot(t, 'assets/raw/heatmap_oct_dlg.png');

      final row = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(InkWell),
      );
      // ignore: avoid_print
      print('DIALOG_INKWELLS ${row.evaluate().length}');
      if (row.evaluate().isNotEmpty) {
        await t.tap(row.first);
        await t.pump(const Duration(milliseconds: 600));
        await t.pump(const Duration(milliseconds: 600));
        await shoot(t, 'assets/raw/heatmap_oct_dlg_done.png');
      }
    });
  });

  testWidgets('today 1', (t) async {
    await scene(t, doneCount: 1, body: (t, p) async {
      final circles = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('check-'),
      );
      for (var i = 0; i < circles.evaluate().length; i++) {
        rects['check_$i'] = norm(t, circles.at(i));
      }
      record(t, 'ring', find.byWidgetPredicate((w) => w.runtimeType.toString() == 'ProgressRing'));
      record(t, 'fab', find.byType(FloatingActionButton));
      await shoot(t, 'assets/raw/today_1.png');
    });
  });

  for (var n = 2; n <= 5; n++) {
    testWidgets('today $n', (t) async {
      await scene(t, doneCount: n, body: (t, p) async {
        await shoot(t, 'assets/raw/today_$n.png');
      });
    });
  }

  testWidgets('widgets full', (t) async {
    await scene(t, tab: 2, doneCount: 5, body: (t, p) async {
      final card = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CheckinPreview');
      final heat = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_HeatmapPreview');
      record(t, 'card_checkin_4x2', card);
      record(t, 'card_heatmap', heat);
      await shoot(t, 'assets/raw/widgets_full.png');
    });
  });

  for (final size in ['2×1', '2×2']) {
    testWidgets('widgets $size', (t) async {
      await scene(t, tab: 2, doneCount: 5, body: (t, p) async {
        final card = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CheckinPreview');
        await t.tap(find.text(size).first);
        await t.pump(const Duration(milliseconds: 400));
        record(t, 'card_checkin_${size.replaceAll('×', 'x')}', card);
        await shoot(t, 'assets/raw/widgets_${size.replaceAll('×', 'x')}.png');
      });
    });
  }

  testWidgets('widgets heat', (t) async {
    await scene(t, tab: 2, doneCount: 5, body: (t, p) async {
      // The heat card sits below the fold; park it mid-screen so it can be
      // cropped whole.
      final heat = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_HeatmapPreview');
      await Scrollable.ensureVisible(t.element(heat), alignment: 0.5, duration: Duration.zero);
      await t.pump(const Duration(milliseconds: 300));
      record(t, 'card_heatmap_hi', heat);
      await shoot(t, 'assets/raw/widgets_heat.png');
    });
  });

  testWidgets('swipe', (t) async {
    await scene(t, doneCount: 1, body: (t, p) async {
      final target = t.getCenter(find.text('读书 30 分钟'));
      final g = await t.startGesture(target);
      await g.moveBy(const Offset(-40, 0));
      await t.pump(const Duration(milliseconds: 40));
      await g.moveBy(const Offset(-52, 0));
      await t.pump(const Duration(milliseconds: 140));
      await shoot(t, 'assets/raw/today_swipe.png');
      await g.up();
      await t.pump(const Duration(milliseconds: 400));
    });
  });

  testWidgets('search', (t) async {
    await scene(t, body: (t, p) async {
      final ctx = t.element(find.byType(TodayScreen));
      final theme = promoTheme(AppTheme.build(hue: 220, brightness: Brightness.dark));
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(builder: (_) => Theme(data: theme, child: const TaskSearchScreen())),
      );
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await shoot(t, 'assets/raw/today_search.png');
    });
  });

  testWidgets('create sheet', (t) async {
    await scene(t, doneCount: 1, body: (t, p) async {
      await t.tap(find.byType(FloatingActionButton));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      record(t, 'sheet', find.byType(BottomSheet));
      await shoot(t, 'assets/raw/create_sheet.png');
    });
  });
}
