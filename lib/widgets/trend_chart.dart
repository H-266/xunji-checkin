import '../core/app_strings.dart';
import '../core/app_motion.dart';
import '../widgets/l_text.dart';

import 'package:flutter/material.dart';

import '../core/date_utils.dart';
import '../core/stats.dart';
import '../theme/app_theme.dart';

/// 纯 Canvas 绘制的完成趋势：顶部 12 周柱状，底部 30 天折线。
///
/// 不依赖任何图表库，点按任一区域可查看该周/该日的具体数据。
class TrendChart extends StatelessWidget {
  final List<double> weeks;
  final List<DayStat> days;
  final double hue;

  const TrendChart({
    super.key,
    required this.weeks,
    required this.days,
    required this.hue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _onTap(context, details.localPosition, constraints.maxWidth),
              child: SizedBox(
                height: 260,
                width: double.infinity,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) =>
                      ClipRect(clipper: _RevealClipper(value), child: child),
                  child: CustomPaint(
                    painter: _TrendPainter(
                      weeks: weeks,
                      days: days,
                      hue: hue,
                      isDark: isDark,
                      textColor: theme.colorScheme.onSurfaceVariant,
                      gridColor: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onTap(BuildContext context, Offset position, double width) {
    if (position.dy < 130) {
      final index = ((position.dx - 18) / ((width - 36) / 12)).floor().clamp(
        0,
        weeks.length - 1,
      );
      showAppSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _DetailTile(
          title: index == weeks.length - 1
              ? '本周'
              : '${weeks.length - index} 周前',
          lines: [
            '完成率 ${(weeks[index] * 100).round()}%',
            '按该周 7 天的有效任务与完成数汇总。',
          ],
        ),
      );
      return;
    }
    final index = ((position.dx - 18) / ((width - 36) / 30)).floor().clamp(
      0,
      days.length - 1,
    );
    final stat = days[index];
    showAppSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DetailTile(
        title: AppDateUtils.fullDateLabel(stat.date),
        lines: [
          '完成 ${stat.completed}/${stat.total} · ${stat.percent}%',
          '有效任务只统计当天计划内的任务。',
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> weeks;
  final List<DayStat> days;
  final double hue;
  final bool isDark;
  final Color textColor;
  final Color gridColor;

  _TrendPainter({
    required this.weeks,
    required this.days,
    required this.hue,
    required this.isDark,
    required this.textColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = 18.0;
    final right = size.width - 18;
    final width = right - left;

    _label(canvas, '最近 12 周', Offset(left, 0), textColor, 11, bold: true);
    _label(canvas, '最近 30 天', Offset(left, 146), textColor, 11, bold: true);

    // 顶部柱状图。
    final barArea = Rect.fromLTWH(left, 20, width, 98);
    final barWidth = barArea.width / 12;
    for (var i = 0; i < weeks.length; i++) {
      final value = weeks[i].clamp(0.0, 1.0);
      final bar = Rect.fromLTWH(
        barArea.left + i * barWidth + 3,
        barArea.bottom - 88 * value,
        barWidth - 6,
        88 * value,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(4)),
        Paint()
          ..color = AppTheme.heatColor(
            hue: hue,
            rate: value,
            isDark: isDark,
            hasTasks: value > 0,
          ),
      );
    }
    canvas.drawLine(
      Offset(left, barArea.bottom),
      Offset(right, barArea.bottom),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    // 底部折线图。
    final lineArea = Rect.fromLTWH(left, 166, width, 82);
    for (final ratio in [0.0, 0.5, 1.0]) {
      final y = lineArea.bottom - lineArea.height * ratio;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..color = gridColor.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
    }
    final path = Path();
    for (var i = 0; i < days.length; i++) {
      final x = left + width * i / (days.length - 1);
      final y = lineArea.bottom - lineArea.height * days[i].rate;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final lineColor = AppTheme.heatColor(
      hue: hue,
      rate: 1,
      isDark: isDark,
      hasTasks: true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = days.isEmpty ? null : days.last;
    if (last != null) {
      final x = right;
      final y = lineArea.bottom - lineArea.height * last.rate;
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = lineColor);
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: AppStrings.tr(text),
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.weeks != weeks ||
        oldDelegate.days != days ||
        oldDelegate.hue != hue ||
        oldDelegate.isDark != isDark;
  }
}

class _DetailTile extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _DetailTile({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final line in lines) ...[
              LText(line),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  final double progress;

  _RevealClipper(this.progress);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.progress != progress;
}
