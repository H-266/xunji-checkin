import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'l_text.dart';

/// 今日完成率进度环。
///
/// 组件只负责画图和动画，不依赖 Provider，便于单独复用/测试。
class ProgressRing extends StatefulWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 108,
    this.strokeWidth = 10,
    this.trackColor,
    this.center,
  });

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _from;
  late double _to;
  late double _displayed;

  @override
  void initState() {
    super.initState();
    final target = widget.value.clamp(0.0, 1.0).toDouble();
    _from = 0;
    _to = target;
    _displayed = target;
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 150),
        )..addListener(() {
          setState(() {
            _displayed = _from + (_to - _from) * _controller.value;
          });
        });
    _controller.forward(from: 1);
  }

  @override
  void didUpdateWidget(covariant ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.value.clamp(0.0, 1.0).toDouble();
    if (target == _to) return;
    // 从当前显示值继续，而不是每次从 0 重扫整圈。
    _from = _displayed;
    _to = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      _displayed = target;
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.value.clamp(0.0, 1.0).toDouble();
    final theme = Theme.of(context);
    final effectiveTrack =
        widget.trackColor ??
        theme.colorScheme.onSurface.withValues(alpha: 0.09);
    final animatedPercent = (_displayed * 100).round();

    return Semantics(
      label: '今日完成度 ${(target * 100).round()}%',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _ProgressRingPainter(
                  value: _displayed,
                  color: widget.color,
                  trackColor: effectiveTrack,
                  strokeWidth: widget.strokeWidth,
                ),
              ),
            ),
            widget.center ??
                LText(
                  '$animatedPercent%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _ProgressRingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
