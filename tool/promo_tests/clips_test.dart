// Pure feature-demo clips: one PNG per frame at 30fps while real gestures run
// against the real app. No camera moves, no captions, no transitions - what you
// see is what the app painted.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xunji_checkin/data/app_database.dart';
import 'package:xunji_checkin/models/task.dart';
import 'package:xunji_checkin/providers/settings_provider.dart';
import 'package:xunji_checkin/providers/task_provider.dart';

import 'promo_kit.dart';

const int _frameUs = 33333;
const int _flushMs = 7;

class Clip {
  Clip(this.t, this.name) {
    // Stale frames from an earlier, longer run would otherwise be encoded too.
    final d = Directory(dir);
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
  final WidgetTester t;
  final String name;
  int i = 0;

  String get dir => '$promoRoot/assets/clips/$name';

  Future<void> _shot() async {
    final boundary = kRootKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final path = '$dir/f${i.toString().padLeft(4, '0')}.png';
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: kDpr);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  /// One 30fps frame. Real async work (sqlite writes behind a tap) is flushed
  /// between pumps, otherwise the UI would never show the result.
  Future<void> frame() async {
    await t.pump(const Duration(microseconds: _frameUs));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: _flushMs)),
    );
    i++;
    await _shot();
  }

  Future<void> frames(int n) async {
    for (var k = 0; k < n; k++) {
      await frame();
    }
  }

  Future<void> tap(Finder f) async {
    await t.tap(f);
    await frames(2);
  }

  void clearSnack() {
    final scaffold = find.byType(Scaffold);
    if (scaffold.evaluate().isEmpty) return;
    ScaffoldMessenger.of(scaffold.evaluate().first).removeCurrentSnackBar();
  }

  /// Tap, then drop the "已打卡「…」/ 写备注" snackbar before it slides into
  /// frame, so a clip shows only the list and the progress ring. The snackbar
  /// only appears after the tap's sqlite write flushes, so we sweep twice.
  Future<void> tapCheck(Finder f, {int after = 16}) async {
    await t.tap(f);
    await t.pump(const Duration(microseconds: _frameUs));
    clearSnack();
    await frames(2);
    clearSnack();
    await frames(1);
    clearSnack();
    await frames(after);
  }
}

Finder navTab(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(label),
);

/// Day number inside the month grid (metric numbers above the grid collide
/// with day numbers, so pick the one that actually sits in the grid).
Finder gridDay(WidgetTester t, int day) {
  final all = find.text('$day');
  final n = all.evaluate().length;
  for (var i = 0; i < n; i++) {
    final rect = t.getRect(all.at(i));
    if (rect.top > 360) return all.at(i);
  }
  return all.first;
}

Future<void> typeText(
  WidgetTester t,
  Clip c,
  String text, {
  int steps = 4,
}) async {
  for (var s = 1; s <= steps; s++) {
    final n = (text.length * s / steps).ceil();
    await t.enterText(find.byType(TextField).first, text.substring(0, n));
    await c.frames(2);
  }
}

Future<void> scene(
  WidgetTester t,
  String name,
  Future<void> Function(WidgetTester, TaskProvider, Clip) body, {
  int tab = 0,
  int done = 1,
  bool live = false,
  int target = 0,
}) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    // The widget config page paints a real 2.5px Row overflow; ignore it.
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  debugDisableShadows = false;
  try {
    late TaskProvider p;
    late SettingsProvider s;
    await t.runAsync(() async {
      await AppDatabase.instance.close();
      await bootDb();
      await seedDemo();
      final r = await bootProviders();
      p = r[0] as TaskProvider;
      s = r[1] as SettingsProvider;
    });
    await t.runAsync(() async {
      var have = p.dailyTasks.where(p.isDailyDone).length;
      for (final task in p.dailyTasks) {
        if (have >= done) break;
        if (p.isDailyDone(task)) continue;
        await p.toggleDaily(task);
        have++;
      }
      for (final task in p.dailyTasks) {
        if (have <= done) break;
        if (!p.isDailyDone(task)) continue;
        await p.toggleDaily(task);
        have--;
      }
    });
    await prepDevice(t);
    await pumpApp(t, wrapProviders(PromoApp(tab: tab, live: live), p, s));
    final c = Clip(t, name);
    await c.frames(4);
    await body(t, p, c);
    // Hold the final state so the clip ends on a settled result.
    if (target > c.i) await c.frames(target - c.i);
  } finally {
    debugDisableShadows = true;
    FlutterError.onError = original;
  }
}

void main() {
  setUpAll(() async {
    await loadPromoFonts();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (call) async => null,
        );
  });

  testWidgets('01 today checkin', (t) async {
    await scene(t, '01_today_checkin', (t, p, c) async {
      await c.frames(8);
      for (final idx in [1, 2, 3]) {
        final id = p.dailyTasks[idx].id;
        await c.tapCheck(find.byKey(ValueKey<String>('check-$id')), after: 24);
      }
      await c.frames(16);
    }, target: 106);
  });

  testWidgets('02 checkin backfill', (t) async {
    await scene(t, '02_checkin_backfill', (t, p, c) async {
      await c.frames(8);
      await c.tap(find.byTooltip('上个月'));
      await c.frames(14);
      final now = DateTime.now();
      final month = DateTime(now.year, now.month - 1);
      var target = DateTime(month.year, month.month, 12);
      for (var d = 8; d <= 24; d++) {
        final date = DateTime(month.year, month.month, d);
        final n = p.dailyTasks.where((x) => p.isDailyDone(x, date: date)).length;
        if (n >= 1 && n <= 2) {
          target = date;
          break;
        }
      }
      await c.tap(gridDay(t, target.day));
      await c.frames(14);
      for (final task in p.dailyTasks) {
        if (p.isDailyDone(task, date: target)) continue;
        await c.tap(
          find
              .ancestor(
                of: find.text(task.title),
                matching: find.byType(InkWell),
              )
              .first,
        );
        await c.frames(10);
      }
      await c.frames(6);
      await c.tap(find.text('知道了').first);
      await c.frames(16);
      await c.frames(16);
    }, tab: 1, target: 136);
  });

  testWidgets('03 tag filter', (t) async {
    await scene(t, '03_tag_filter', (t, p, c) async {
      await c.frames(8);
      await c.tap(find.byTooltip('上个月'));
      await c.frames(16);
      // Filter sheet: 全部任务 / 按标签 / 按单个任务
      await c.tap(find.byIcon(Icons.filter_alt_outlined));
      await c.frames(18);
      await c.tap(find.text('学习').first);
      await c.frames(24);
      await c.tap(find.byTooltip('清除筛选'));
      await c.frames(20);
    }, tab: 1, target: 132);
  });

  testWidgets('04 year heatmap', (t) async {
    await scene(t, '04_year_heatmap', (t, p, c) async {
      await c.frames(8);
      await c.tap(find.byTooltip('年度热力图'));
      await c.frames(18);
      // A drag on the horizontal week strip is unreliable; drive the real
      // ScrollPosition instead so the year grid glides the way a finger would.
      final strip = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      );
      final rect = t.getRect(strip.first);
      final g = await t.startGesture(rect.center);
      for (var s = 0; s < 14; s++) {
        await g.moveBy(const Offset(-30, 0));
        await c.frames(1);
      }
      await g.up();
      await c.frames(26);
    }, tab: 1, target: 94);
  });

  testWidgets('05 global search', (t) async {
    await scene(t, '05_global_search', (t, p, c) async {
      await c.frames(8);
      final g = await t.startGesture(const Offset(196, 320));
      for (var s = 0; s < 8; s++) {
        await g.moveBy(const Offset(0, 34));
        await c.frames(1);
      }
      await c.frames(2);
      await g.up();
      await c.frames(22);
      await typeText(t, c, '跑');
      await c.frames(14);
      await c.frames(12);
    }, target: 122);
  });

  testWidgets('06 create task', (t) async {
    await scene(t, '06_create_task', (t, p, c) async {
      await c.frames(8);
      await c.tap(find.byType(FloatingActionButton));
      await c.frames(18);
      await c.tap(find.byType(TextField).first);
      await c.frames(4);
      await typeText(t, c, '早睡 23:00', steps: 4);
      await c.frames(6);
      await c.tap(find.text('重复周期').first);
      await c.frames(18);
      await c.tap(find.text('工作日').first);
      await c.frames(10);
      await c.tap(find.text('完成').first);
      await c.frames(12);
      await c.tapCheck(find.text('添加任务').first, after: 18);
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, -230));
      await c.frames(10);
      await c.frames(12);
    }, target: 140);
  });

  testWidgets('07 repeat cycle', (t) async {
    await scene(t, '07_repeat_cycle', (t, p, c) async {
      await c.frames(8);
      await c.tap(find.byType(FloatingActionButton));
      await c.frames(14);
      await c.tap(find.text('重复周期').first);
      await c.frames(18);
      for (final preset in ['隔天', '工作日', '每月 1 号', '每年今天']) {
        await c.tap(find.text(preset).first);
        await c.frames(9);
      }
      await c.tap(find.byType(DropdownButtonFormField<TaskSchedule>).first);
      await c.frames(14);
      await c.tap(find.text('自定义星期').first);
      await c.frames(14);
      await c.tap(find.widgetWithText(FilterChip, '一').first);
      await c.frames(8);
      await c.tap(find.widgetWithText(FilterChip, '三').first);
      await c.frames(8);
      await c.tap(find.text('完成').first);
      await c.frames(12);
    }, target: 140);
  });

  testWidgets('08 task archive', (t) async {
    await scene(t, '08_task_archive', (t, p, c) async {
      await c.frames(8);
      final target = t.getCenter(find.text('读书 30 分钟'));
      final g = await t.startGesture(target);
      for (var s = 0; s < 3; s++) {
        await g.moveBy(const Offset(-34, 0));
        await c.frames(2);
      }
      await c.frames(8);
      await g.moveBy(const Offset(-20, 0));
      await c.frames(3);
      await g.up();
      await c.frames(12);
      await c.tapCheck(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('归档'),
        ),
        after: 16,
      );
      await c.frames(16);
    }, target: 96);
  });

  testWidgets('09 widget preview', (t) async {
    await scene(t, '09_widget_preview', tab: 2, done: 4, (t, p, c) async {
      await c.frames(10);
      await c.tap(find.text('2×1').first);
      await c.frames(16);
      await c.tap(find.text('2×2').first);
      await c.frames(16);
      await c.tap(find.text('4×4').first);
      await c.frames(18);
      await c.frames(12);
    }, target: 130);
  });

  testWidgets('10 widget sync', (t) async {
    await scene(t, '10_widget_sync', live: true, done: 2, (t, p, c) async {
      await c.frames(8);
      await c.tap(navTab('小组件'));
      await c.frames(18);
      await c.frames(12);
      await c.tap(navTab('今日'));
      await c.frames(14);
      // Only the 4th row is reachable above the nav bar; the 5th sits under it.
      final id = p.dailyTasks[3].id;
      await c.tapCheck(find.byKey(ValueKey<String>('check-$id')), after: 24);
      await c.tap(navTab('小组件'));
      await c.frames(24);
      await c.frames(20);
    }, target: 150);
  });
}
