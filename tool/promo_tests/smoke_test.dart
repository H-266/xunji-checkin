import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/providers/settings_provider.dart';
import 'package:xunji_checkin/providers/task_provider.dart';

import 'promo_kit.dart';

void main() {
  testWidgets('smoke', (t) async {
    print('S1 fonts');
    await loadPromoFonts();
    print('S2 db');
    await t.runAsync(() async {
      await bootDb();
      await seedDemo();
    });
    print('S3 providers');
    late TaskProvider p;
    late SettingsProvider s;
    await t.runAsync(() async {
      final r = await bootProviders();
      p = r[0] as TaskProvider;
      s = r[1] as SettingsProvider;
    });
    print('S4 pump');
    await prepDevice(t);
    await pumpApp(t, wrapProviders(PromoApp(), p, s));
    print('S5 frame');
    await t.pump(const Duration(microseconds: 33333));
    final boundary =
        kRootKey.currentContext!.findRenderObject()! as dynamic;
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 3);
      final b = await img.toByteData(format: ui.ImageByteFormat.png);
      print('S6 png ' + b!.lengthInBytes.toString());
    });
    print('S7 done');
  });
}
