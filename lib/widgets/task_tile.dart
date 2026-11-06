import 'dart:math' as math;

import '../core/app_motion.dart';
import '../core/app_strings.dart';
import '../widgets/l_text.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/task.dart';

/// 任务行：标题 + 勾选框，完成态显示删除线。
///
/// 点击整行或勾选框都会触发 [onToggle]；长按或右侧更多按钮触发 [onEdit]。
class TaskTile extends StatelessWidget {
  final Task task;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  /// 可选的第二行说明，例如“每周 3 次 · 学习”。
  final String? subtitle;

  /// 临时待办已逾期：仅弱高亮，不改变主色系统。
  final bool overdue;

  /// 行级完成态；提供后勾选只重建当前行。
  final ValueListenable<bool>? doneListenable;

  const TaskTile({
    super.key,
    required this.task,
    required this.done,
    required this.onToggle,
    required this.onEdit,
    this.subtitle,
    this.overdue = false,
    this.doneListenable,
  });

  @override
  Widget build(BuildContext context) {
    final listenable = doneListenable;
    if (listenable == null) return _buildRow(context, done);
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, liveDone, child) => _buildRow(context, liveDone),
    );
  }

  Widget _buildRow(BuildContext context, bool done) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final typeLabel = subtitle ?? task.type.label;

    // 列表是 sliver 懒构建的，只有视口附近几行会创建边界；
    // 单行勾选仅重绘这一行，不会把整段可见列表一起重放。
    return RepaintBoundary(
      child: Semantics(
        label: '${task.title}，$typeLabel，${done ? '已完成' : '未完成'}',
        button: true,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          curve: AppMotion.curve,
          // 扁平面板：不使用 Card/Material 的 elevation 或圆角裁剪，
          // 避免单行重绘触发 blur/saveLayer；层级只靠纯色差区分。
          decoration: BoxDecoration(
            color: done
                ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.72)
                : overdue
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.28)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 6, 10),
              child: Row(
                children: [
                  _CheckCircle(
                    key: ValueKey<String>('check-${task.id}'),
                    done: done,
                    onToggle: onToggle,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: AppMotion.of(context, AppMotion.fast),
                          curve: AppMotion.curve,
                          style:
                              (theme.textTheme.titleMedium ?? const TextStyle())
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    decorationThickness: 1.8,
                                    color: done
                                        ? muted
                                        : theme.colorScheme.onSurface,
                                  ),
                          child: LText(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              task.isDaily
                                  ? Icons.repeat_rounded
                                  : Icons.bolt_rounded,
                              size: 14,
                              color: muted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: LText(
                                typeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    tooltip: AppStrings.tr('任务操作'),
                    icon: Icon(Icons.more_horiz_rounded, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 只让勾选圆点触发打卡，避免整行轻点误触。
///
/// 视觉反馈交给整行 150ms 背景过渡与系统触感；圆点本身保持静态，
/// 避免 20 次连点时叠加缩放/对勾/边框三层栅格化动画。
class _CheckCircle extends StatefulWidget {
  final bool done;
  final VoidCallback onToggle;

  const _CheckCircle({super.key, required this.done, required this.onToggle});

  @override
  State<_CheckCircle> createState() => _CheckCircleState();
}

class _CheckCircleState extends State<_CheckCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
      value: widget.done ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _CheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.done == widget.done) return;
    final duration = AppMotion.of(context, AppMotion.fast);
    if (duration == Duration.zero) {
      _controller.value = widget.done ? 1 : 0;
      return;
    }
    _controller.duration = duration;
    if (widget.done) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      checked: widget.done,
      label: widget.done ? AppStrings.tr('已完成') : AppStrings.tr('未完成'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_controller.value);
                // 峰值 1.1 倍，落点 1.0；取消时反向收回。
                final scale = 1 + 0.1 * math.sin(math.pi * t);
                return Transform.scale(
                  scale: scale,
                  child: CustomPaint(
                    size: const Size.square(28),
                    painter: _CheckPainter(
                      progress: t,
                      fill: scheme.primary,
                      outline: scheme.outline,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color fill;
  final Color outline;

  const _CheckPainter({
    required this.progress,
    required this.fill,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = outline.withValues(alpha: 0.75);
    canvas.drawCircle(center, radius, base);

    if (progress <= 0) return;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fill.withValues(alpha: progress);
    canvas.drawCircle(center, radius - 0.8, fillPaint);

    final check = Path()
      ..moveTo(size.width * 0.30, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.72, size.height * 0.37);
    final metric = check.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fill != fill ||
      oldDelegate.outline != outline;
}
