import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  testWidgets('probe render', (tester) async {
    const dir = '../docs/promo-video/assets/fonts';
    await _load('NotoSC', [
      '$dir/NotoSansSC_400Regular.ttf',
      '$dir/NotoSansSC_700Bold.ttf',
    ]);
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'NotoSC',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1220),
      ),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Text('循记打卡', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w700)),
            SizedBox(height: 24),
            Text('今日完成 78% · 连续 21 天', style: TextStyle(fontSize: 28)),
            SizedBox(height: 24),
            Text('Default family 默认字体 12345', style: TextStyle(fontSize: 22)),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('../docs/promo-video/assets/screens/_probe.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(data!.buffer.asUint8List());
      // ignore: avoid_print
      print('PROBE_OK size=${image.width}x${image.height} bytes=${data.lengthInBytes}');
    });
  });
}
