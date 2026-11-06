// Exports promo page states as 3x PNGs (real UI, real data). Post-processing
// scales them to the film's 1080x2400 canvas.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xunji_checkin/providers/settings_provider.dart';
import 'package:xunji_checkin/providers/task_provider.dart';
import 'package:xunji_checkin/screens/stats_screen.dart';
import 'package:xunji_checkin/screens/year_heatmap_screen.dart';

import 'promo_kit.dart';

void main() {
  setUpAll(() async {
    await loadPromoFonts();
    await bootDb();
    await seedDemo();
    // ignore: avoid_print
    print('SEED_OK');
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (call) async => null,
        );
  });

  Future<void> scene(
    WidgetTester tester, {
    required String out,
    int tab = 0,
    Widget? page,
    double width = kLogicalW,
    double height = kLogicalH,
    required Future<void> Function(WidgetTester, TaskProvider) body,
  }) async {
    debugDisableShadows = false;
    try {
      await prepDevice(tester, width: width, height: height);
      late TaskProvider tasks;
      late SettingsProvider settings;
      await tester.runAsync(() async {
        final p = await bootProviders();
        tasks = p[0] as TaskProvider;
        settings = p[1] as SettingsProvider;
      });
      await pumpApp(
        tester,
        wrapProviders(PromoApp(tab: tab, page: page), tasks, settings),
        width: width,
        height: height,
      );
      await body(tester, tasks);
      await shoot(tester, out);
    } finally {
      debugDisableShadows = true;
    }
  }

  testWidgets('today', (t) => scene(t,
      out: 'assets/raw/today.png', body: (t, p) async {}));

  testWidgets('heatmap', (t) => scene(t,
      out: 'assets/raw/heatmap.png', tab: 1, body: (t, p) async {}));

  testWidgets('heatmap_oct', (t) => scene(t, out: 'assets/raw/heatmap_oct.png',
      tab: 1, body: (t, p) async {
    await t.tap(find.byTooltip('上个月'));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
  }));

  testWidgets('heatmap_oct_study', (t) => scene(t,
      out: 'assets/raw/heatmap_oct_study.png', tab: 1,
      body: (t, p) async {
    await t.tap(find.byTooltip('上个月'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('全部任务'));
    await t.pumpAndSettle();
    await t.tap(find.text('学习').last);
    await t.pumpAndSettle();
  }));

  testWidgets('year_end', (t) => scene(t,
      out: 'assets/raw/year_end.png',
      page: const YearHeatmapScreen(), body: (t, p) async {
    final grid = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
    );
    final scrollable = find.descendant(
      of: grid.first,
      matching: find.byType(Scrollable),
    );
    final state = t.state<ScrollableState>(scrollable.first);
    state.position.jumpTo(state.position.maxScrollExtent);
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
  }));

  testWidgets('stats', (t) => scene(t, out: 'assets/raw/stats.png',
      page: const StatsScreen(), body: (t, p) async {}));

  testWidgets('settings', (t) => scene(t,
      out: 'assets/raw/settings.png', tab: 3, body: (t, p) async {}));

  testWidgets('widgets', (t) => scene(t,
      out: 'assets/raw/widgets.png', tab: 2, body: (t, p) async {}));
}
