import 'package:flutter/material.dart';

import '../core/app_motion.dart';

import '../core/app_strings.dart';
import '../core/date_utils.dart';
import '../core/stats.dart';
import '../providers/task_provider.dart';
import 'l_text.dart';

/// 时间粒度取值的四档。
enum TrendGranularity { week, month, quarter, year }

/// 周 / 月 / 季度 / 年四档完成率趋势。
///
/// 直接调用 TaskProvider.periodStats 计算，与月热力、年度热力同源；
/// 图表用 CustomPainter 绘制，不引入第三方图表库。
class PeriodTrendCard extends StatefulWidget {
  const PeriodTrendCard({super.key, required this.provider, required this.hue});

  final TaskProvider provider;
  final double hue;

  @override
  State<PeriodTrendCard> createState() => _PeriodTrendCardState();
}

class _PeriodTrendCardState extends State<PeriodTrendCard> {
  TrendGranularity _granularity = TrendGranularity.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = _buildPoints(widget.provider, _granularity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LText(
                    AppStrings.tr('时间维度'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                LText(
                  AppStrings.tr('完成率趋势'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final item in TrendGranularity.values)
                  ChoiceChip(
                    label: LText(AppStrings.tr(_label(item))),
                    selected: _granularity == item,
                    onSelected: (_) => setState(() => _granularity = item),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              width: double.infinity,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _showDetail(
                  context,
                  points,
                  details.localPosition,
                  context.size?.width ?? 300,
                ),
                child: CustomPaint(
                  painter: _PeriodPainter(
                    points: points,
                    hue: widget.hue,
                    isDark: theme.brightness == Brightness.dark,
                    textColor: theme.colorScheme.onSurfaceVariant,
                    gridColor: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(TrendGranularity value) {
    return switch (value) {
      TrendGranularity.week => '周',
      TrendGranularity.month => '月',
      TrendGranularity.quarter => '季度',
      TrendGranularity.year => '年',
    };
  }

  void _showDetail(
    BuildContext context,
    List<_TrendPoint> points,
    Offset position,
    double width,
  ) {
    if (points.isEmpty) return;
    final index = ((position.dx - 34) / ((width - 44) / points.length))
        .floor()
        .clamp(0, points.length - 1)
        .toInt();
    final point = points[index];
    showAppSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(point.label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            LText(
              '${AppStrings.tr('完成率')} ${point.percent}%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            LText(
              '${point.completed}/${point.total} · ${AppStrings.tr('有效日')} ${point.activeDays}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  List<_TrendPoint> _buildPoints(TaskProvider provider, TrendGranularity type) {
    final today = AppDateUtils.dayOnly(DateTime.now());
    final result = <_TrendPoint>[];
    switch (type) {
      case TrendGranularity.week:
        for (var i = 11; i >= 0; i--) {
          final start = AppDateUtils.weekStart(
            today.subtract(Duration(days: i * 7)),
          );
          final end = start.add(const Duration(days: 6));
          final clamped = end.isAfter(today) ? today : end;
          final stat = provider.periodStats(start, clamped);
          result.add(
            _TrendPoint(label: '${start.month}/${start.day}', stat: stat),
          );
        }
      case TrendGranularity.month:
        for (var i = 11; i >= 0; i--) {
          final start = DateTime(today.year, today.month - i, 1);
          final end = AppDateUtils.monthEnd(start);
          final clamped = end.isAfter(today) ? today : end;
          final stat = provider.periodStats(start, clamped);
          result.add(
            _TrendPoint(label: AppStrings.tr('${start.month}月'), stat: stat),
          );
        }
      case TrendGranularity.quarter:
        final currentQuarter = ((today.month - 1) ~/ 3);
        for (var i = 7; i >= 0; i--) {
          final index = currentQuarter - i;
          final year = today.year + (index < 0 ? -1 : index ~/ 4);
          final quarter = (index % 4 + 4) % 4;
          final start = DateTime(year, quarter * 3 + 1, 1);
          final end = DateTime(year, quarter * 3 + 4, 0);
          final clamped = end.isAfter(today) ? today : end;
          final stat = provider.periodStats(start, clamped);
          result.add(
            _TrendPoint(
              label: '${year.toString().substring(2)} Q${quarter + 1}',
              stat: stat,
            ),
          );
        }
      case TrendGranularity.year:
        for (var i = 4; i >= 0; i--) {
          final year = today.year - i;
          final start = DateTime(year, 1, 1);
          final end = DateTime(year, 12, 31);
          final clamped = end.isAfter(today) ? today : end;
          final stat = provider.periodStats(start, clamped);
          result.add(_TrendPoint(label: '$year', stat: stat));
        }
    }
    return result;
  }
}

class _TrendPoint {
  const _TrendPoint({required this.label, required this.stat});

  final String label;
  final PeriodCompletion stat;

  double get rate => stat.rate;
  int get percent => stat.percent;
  int get total => stat.total;
  int get completed => stat.completed;
  int get activeDays => stat.activeDays;
}

class _PeriodPainter extends CustomPainter {
  const _PeriodPainter({
    required this.points,
    required this.hue,
    required this.isDark,
    required this.textColor,
    required this.gridColor,
  });

  final List<_TrendPoint> points;
  final double hue;
  final bool isDark;
  final Color textColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final left = 28.0;
    final right = size.width - 6;
    final top = 8.0;
    final bottom = size.height - 26;
    final chartHeight = bottom - top;
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;
    final labelStyle = TextStyle(fontSize: 9, color: textColor);

    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
      _drawText(canvas, '${100 - i * 25}%', Offset(0, y - 6), labelStyle);
    }

    final gap = 5.0;
    final barWidth =
        ((right - left) - gap * (points.length - 1)) / points.length;
    final base = HSVColor.fromAHSV(
      1,
      hue % 360,
      0.82,
      isDark ? 0.95 : 0.82,
    ).toColor();
    for (var i = 0; i < points.length; i++) {
      final x = left + i * (barWidth + gap);
      final rate = points[i].rate.clamp(0.0, 1.0);
      final height = chartHeight * rate;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, bottom - height, barWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = base.withValues(alpha: 0.35 + 0.65 * rate),
      );
      _drawText(
        canvas,
        '${points[i].percent}%',
        Offset(x - 2, bottom - height - 13),
        TextStyle(fontSize: 8, color: textColor),
      );
      _drawText(canvas, points[i].label, Offset(x - 1, bottom + 5), labelStyle);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 60);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PeriodPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hue != hue ||
        oldDelegate.isDark != isDark;
  }
}
