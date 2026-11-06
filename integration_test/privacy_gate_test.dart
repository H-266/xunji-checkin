import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xunji_checkin/main.dart' as app;

/// 真机冒烟：首次安装必须停在隐私同意门，未勾选时按钮禁用。
/// 运行前清除 App 数据：
///   adb shell pm clear com.xunji.checkin
///   flutter test integration_test/privacy_gate_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('privacy gate blocks first launch until accepted', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('同意并继续'), findsOneWidget);

    FilledButton agree() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '同意并继续'),
    );
    expect(agree().onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(agree().onPressed, isNotNull);
  });
}
