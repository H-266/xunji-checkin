import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'platform_service.dart';

/// 纯本地轻量错误日志。
///
/// 只记录崩溃、数据库异常、导入导出失败等需要排查的问题，不记录普通
/// 交互；最多保留 64KB，超出后保留最近一半，避免无限增长。
class LocalLogService {
  LocalLogService._();

  static const int _maxBytes = 64 * 1024;
  static File? _file;

  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/xunji_error.log');
    } catch (error) {
      debugPrint('日志初始化失败：$error');
    }
  }

  static Future<void> log(
    String message, {
    Object? error,
    StackTrace? stack,
  }) async {
    try {
      final file = _file;
      if (file == null) return;
      final now = DateTime.now().toIso8601String();
      final buffer = StringBuffer('[$now] $message');
      if (error != null) buffer.write(' | $error');
      if (stack != null) buffer.write('\n$stack');
      buffer.writeln();
      await file.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
      final length = await file.length();
      if (length > _maxBytes) {
        final content = await file.readAsString();
        await file.writeAsString(content.substring(content.length ~/ 2));
      }
    } catch (logError) {
      debugPrint('写日志失败：$logError');
    }
  }

  static Future<String> read() async {
    try {
      final file = _file;
      if (file == null || !await file.exists()) return '';
      return await file.readAsString();
    } catch (error) {
      return '读取日志失败：$error';
    }
  }

  static Future<void> clear() async {
    try {
      final file = _file;
      if (file != null && await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('清空日志失败：$error');
    }
  }

  static Future<String?> export() async {
    final content = await read();
    if (content.isEmpty) return null;
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 10)
        .replaceAll('-', '');
    return PlatformService.exportJson(
      json: content,
      fileName: 'xunji-error-$stamp.log',
      mimeType: 'text/plain',
    );
  }
}
