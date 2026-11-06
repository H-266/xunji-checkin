import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xunji_checkin/services/platform_service.dart';

/// 真机 SAF 导出烟测：调用系统文件选择器，返回保存后的 content URI。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export JSON through SAF', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('SAF export test'))),
    );
    final uri = await PlatformService.exportJson(
      json: '{"app":"xunji-saf-test","format_version":1}',
      fileName: 'xunji-saf-test.json',
    );
    expect(uri, isNotNull);
    // ignore: avoid_print
    print('SAF_EXPORT_URI=$uri');
  });
}
