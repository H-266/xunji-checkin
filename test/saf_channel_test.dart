import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/services/platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.xunji.checkin/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('JSON 导出通过 SAF 通道传递文件名与 MIME', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return 'content://xunji/export.json';
    });

    final uri = await PlatformService.exportJson(
      json: '{"app":"循记打卡"}',
      fileName: '循记打卡-2026-11-06.json',
    );

    expect(uri, 'content://xunji/export.json');
    expect(captured?.method, 'exportJson');
    final args = Map<String, Object?>.from(captured?.arguments as Map);
    expect(args['fileName'], '循记打卡-2026-11-06.json');
    expect(args['mimeType'], 'application/json');
    expect(args['json'], contains('循记打卡'));
  });

  test('CSV 导出允许显式 MIME，取消返回 null', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return null;
    });

    final uri = await PlatformService.exportJson(
      json: 'a,b\n1,2',
      fileName: 'x.csv',
      mimeType: 'text/csv',
    );

    expect(uri, isNull);
    final args = Map<String, Object?>.from(captured?.arguments as Map);
    expect(args['mimeType'], 'text/csv');
  });

  test('JSON 导入通过 SAF 通道并返回文本', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => '{"format_version":1}',
    );
    final text = await PlatformService.importJson();
    expect(text, '{"format_version":1}');
  });
}
