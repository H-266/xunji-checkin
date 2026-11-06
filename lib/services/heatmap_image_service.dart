import '../core/app_strings.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/date_utils.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import 'platform_service.dart';

/// 把热力图导出成长图（PNG），通过 SAF 保存，不申请存储权限。
///
/// 使用 Canvas 直接绘制，不依赖截图/RepaintBoundary，因此在任何页面
/// 都能生成固定 1080 宽的清晰图片。
class HeatmapImageService {
  HeatmapImageService._();

  static const double width = 1080;

  static Future<String?> exportMonth({
    required TaskProvider provider,
    required DateTime month,
    required double hue,
    required bool dark,
    int? tagId,
    int? taskId,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bg = dark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FC);
    final surface = dark ? const Color(0xFF141D30) : Colors.white;
    final text = dark ? const Color(0xFFF1F5FF) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFA9B6CE) : const Color(0xFF5B6B85);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, 1500),
      Paint()..color = bg,
    );
    _text(canvas, '循记打卡', 60, 74, 30, text, bold: true);
    _text(
      canvas,
      '${AppDateUtils.monthTitle(month)} · 完成率热力图',
      60,
      126,
      46,
      text,
      bold: true,
    );
    _text(canvas, '纯本地记录 · 一格一天', 60, 190, 22, sub);

    final stats = provider.monthStats(month, tagId: tagId, taskId: taskId);
    _metric(canvas, 60, 246, '月平均完成率', '${stats.averagePercent}%', text, sub);
    _metric(canvas, 400, 246, '全勤天数', '${stats.perfectDays}', text, sub);
    _metric(
      canvas,
      720,
      246,
      '有完成的天',
      '${stats.daysWithCompletion}',
      text,
      sub,
    );

    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(48, 330, 984, 980),
      const Radius.circular(34),
    );
    canvas.drawRRect(card, Paint()..color = surface);

    for (var i = 0; i < 7; i++) {
      _text(
        canvas,
        AppStrings.weekdayShort(i),
        130 + i * 120,
        370,
        24,
        sub,
        align: TextAlign.center,
        width: 80,
      );
    }

    final first = AppDateUtils.monthStart(month);
    final leading = first.weekday - 1;
    final days = AppDateUtils.daysInMonth(month);
    final today = provider.today;
    const cell = 104.0;
    const gap = 10.0;
    const startX = 70.0;
    const startY = 412.0;
    for (var day = 1; day <= days; day++) {
      final date = DateTime(month.year, month.month, day);
      final index = leading + day - 1;
      final row = index ~/ 7;
      final col = index % 7;
      final x = startX + col * (cell + gap);
      final y = startY + row * (cell + gap);
      final stat = provider.statsFor(date, tagId: tagId, taskId: taskId);
      final future = date.isAfter(today);
      final color = future
          ? (dark ? const Color(0xFF1B2436) : const Color(0xFFEFF3F9))
          : AppTheme.heatColor(
              hue: hue,
              rate: stat.rate,
              isDark: dark,
              hasTasks: stat.hasTasks,
            );
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, cell, cell),
        const Radius.circular(18),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      if (!future && stat.isPerfect) {
        canvas.drawRRect(
          rect.deflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = dark ? Colors.white : const Color(0xFF1F3A8A),
        );
      }
      _text(
        canvas,
        '$day',
        x + 10,
        y + 10,
        22,
        future
            ? sub.withValues(alpha: 0.7)
            : (stat.isPerfect
                  ? (dark ? Colors.black : Colors.white)
                  : (dark ? text : text)),
        bold: true,
      );
    }

    _text(canvas, '循记打卡 · 纯离线 · 数据只在本机', 60, 1410, 24, sub);
    _text(canvas, '完成率 0% —— 100%', 780, 1410, 22, sub);

    final image = await recorder.endRecording().toImage(width.toInt(), 1500);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    return PlatformService.saveImage(
      bytes: data.buffer.asUint8List(),
      fileName:
          'xunji-heatmap-${month.year}-${month.month.toString().padLeft(2, '0')}.png',
    );
  }

  static Future<String?> exportYear({
    required TaskProvider provider,
    required int year,
    required double hue,
    required bool dark,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bg = dark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FC);
    final text = dark ? const Color(0xFFF1F5FF) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFA9B6CE) : const Color(0xFF5B6B85);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, 1560),
      Paint()..color = bg,
    );
    _text(canvas, '循记打卡', 56, 70, 30, text, bold: true);
    _text(canvas, '$year 年 · 全年热力图', 56, 120, 46, text, bold: true);
    _text(canvas, '纯本地记录 · 一格一天', 56, 184, 22, sub);

    const cell = 27.0;
    const gap = 7.0;
    for (var m = 1; m <= 12; m++) {
      final col = (m - 1) % 4;
      final row = (m - 1) ~/ 4;
      final ox = 56.0 + col * 248;
      final oy = 240.0 + row * 410;
      _text(canvas, '$m 月', ox, oy, 24, text, bold: true);
      final first = DateTime(year, m, 1);
      final leading = first.weekday - 1;
      final days = AppDateUtils.daysInMonth(first);
      for (var day = 1; day <= days; day++) {
        final date = DateTime(year, m, day);
        final index = leading + day - 1;
        final r = index ~/ 7;
        final c = index % 7;
        final x = ox + c * (cell + gap);
        final y = oy + 18 + r * (cell + gap);
        final stat = provider.statsFor(date);
        final future = date.isAfter(provider.today);
        final color = future
            ? (dark ? const Color(0xFF1B2436) : const Color(0xFFEFF3F9))
            : AppTheme.heatColor(
                hue: hue,
                rate: stat.rate,
                isDark: dark,
                hasTasks: stat.hasTasks,
              );
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cell, cell),
          const Radius.circular(5),
        );
        canvas.drawRRect(rect, Paint()..color = color);
        if (!future && stat.isPerfect) {
          canvas.drawRRect(
            rect.deflate(1),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = dark ? Colors.white : const Color(0xFF1F3A8A),
          );
        }
      }
    }
    _text(canvas, '循记打卡 · 纯离线 · 数据只在本机', 56, 1500, 23, sub);
    final image = await recorder.endRecording().toImage(width.toInt(), 1560);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    return PlatformService.saveImage(
      bytes: data.buffer.asUint8List(),
      fileName: 'xunji-heatmap-$year.png',
    );
  }

  static void _metric(
    Canvas canvas,
    double x,
    double y,
    String label,
    String value,
    Color text,
    Color sub,
  ) {
    _text(canvas, value, x, y, 54, text, bold: true);
    _text(canvas, label, x, y + 70, 22, sub);
  }

  static void _text(
    Canvas canvas,
    String value,
    double x,
    double y,
    double size,
    Color color, {
    bool bold = false,
    TextAlign align = TextAlign.left,
    double? width,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: AppStrings.tr(value),
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: width ?? double.infinity);
    painter.paint(canvas, Offset(x, y));
  }
}
