import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../core/onboarding_targets.dart';
import 'l_text.dart';

/// 轻量引导层。
///
/// 高亮区域不写死坐标，而是读取目标控件真实 RenderBox 的位置。
/// 这样换语言、放大字号、横屏或页面滚动后，框仍然贴住真实控件。
class OnboardingOverlay extends StatefulWidget {
  final int step;
  final ValueChanged<int> onStepChanged;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  const OnboardingOverlay({
    super.key,
    required this.step,
    required this.onStepChanged,
    required this.onFinish,
    required this.onSkip,
  });

  static const _steps = [
    (title: '先建一个任务', body: '点右下角「新建任务」。打卡任务每天重置；临时待办完成即消失。'),
    (title: '热力图是全局的', body: '一格代表一整天，颜色由当天完成率决定。点格子看当天明细。'),
    (title: '把今天放到桌面', body: '在小组件配置里添加卡片。桌面卡片只展示，点一下回到 App 打卡。'),
    (title: '按自己的习惯来', body: '这里能改主色、深浅模式和字号，也能导出 / 导入 JSON 备份。'),
  ];

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  final GlobalKey _overlayKey = GlobalKey(debugLabel: 'onboarding-overlay');
  Rect? _targetRect;
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant OnboardingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      // 目标页刚切过来时还没完成 layout，先清空旧框。
      // 60ms 后先量一次；滚动/页面入场结束后再补量一次，避免卡片
      // 长时间停在兜底位置造成“点了没反应”的错觉。
      _targetRect = null;
      final step = widget.step;
      _scheduleMeasure(delayMs: 60);
      Future<void>.delayed(const Duration(milliseconds: 360), () {
        if (mounted && widget.step == step) _scheduleMeasure(delayMs: 0);
      });
    }
  }

  void _scheduleMeasure({int delayMs = 160}) {
    if (_measureScheduled) return;
    _measureScheduled = true;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      _measureScheduled = false;
      if (!mounted) return;
      // 等 FAB / 页面入场位移结束后直接量，不能只挂 postFrame：
      // 页面静止时没有新帧，postFrame 回调可能永远不执行。
      _measure();
    });
  }

  void _measure() {
    final overlayBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    final targetKey = OnboardingTargets.forStep(widget.step);
    final targetBox =
        targetKey?.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null ||
        targetBox == null ||
        !overlayBox.hasSize ||
        !targetBox.hasSize) {
      // 目标还没挂载（例如页面正在切换），下一帧重试。
      _scheduleMeasure();
      return;
    }
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final raw = topLeft & targetBox.size;
    final size = overlayBox.size;
    // 目标可能在滚动容器之外（例如设置页停在底部时重播教程）。
    // 此时不能把坐标硬夹到屏幕边缘，否则会画出错误的高亮框并挡住卡片。
    if (raw.bottom <= 0 ||
        raw.top >= size.height ||
        raw.right <= 0 ||
        raw.left >= size.width) {
      if (_targetRect != null) setState(() => _targetRect = null);
      _scheduleMeasure(delayMs: 600);
      return;
    }
    final maxHeight = size.height * 0.40;
    final rect = Rect.fromLTWH(
      raw.left.clamp(4.0, size.width - 40),
      raw.top.clamp(4.0, size.height - 40),
      raw.width.clamp(24.0, size.width - 8),
      raw.height.clamp(24.0, maxHeight),
    );
    if (_targetRect != rect) {
      setState(() => _targetRect = rect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = widget.step.clamp(0, OnboardingOverlay._steps.length - 1);
    final data = OnboardingOverlay._steps[index];

    return LayoutBuilder(
      key: _overlayKey,
      builder: (context, constraints) {
        final size = constraints.biggest;
        // 目标暂时不可见时仍要显示卡片和“完成”按钮，否则用户会被
        // 全屏遮罩困住（重播教程停在设置页底部时可复现）。
        final measured = _targetRect;
        final hole =
            measured ??
            Rect.fromLTWH(18, size.height * 0.45, size.width - 36, 2);
        final cardTop = _cardTop(size, hole);
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: hole.top,
              child: const _Dim(),
            ),
            Positioned(
              left: 0,
              top: hole.bottom,
              right: 0,
              bottom: 0,
              child: const _Dim(),
            ),
            Positioned(
              left: 0,
              top: hole.top,
              width: hole.left,
              height: hole.height,
              child: const _Dim(),
            ),
            Positioned(
              left: hole.right,
              top: hole.top,
              right: 0,
              height: hole.height,
              child: const _Dim(),
            ),
            if (measured != null)
              AnimatedPositioned(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: hole.left,
                top: hole.top,
                width: hole.width,
                height: hole.height,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            AnimatedPositioned(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: 18,
              right: 18,
              top: cardTop,
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(index),
                tween: Tween<double>(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - t)),
                    child: child,
                  ),
                ),
                child: Card(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LText(
                          '${index + 1}/${OnboardingOverlay._steps.length} · '
                          '${AppStrings.tr(data.title)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LText(
                          data.body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.55,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: widget.onSkip,
                              child: const LText('跳过'),
                            ),
                            const Spacer(),
                            if (index > 0)
                              TextButton(
                                onPressed: () =>
                                    widget.onStepChanged(index - 1),
                                child: const LText('上一步'),
                              ),
                            const SizedBox(width: 4),
                            FilledButton(
                              onPressed:
                                  index == OnboardingOverlay._steps.length - 1
                                  ? widget.onFinish
                                  : () => widget.onStepChanged(index + 1),
                              child: LText(
                                index == OnboardingOverlay._steps.length - 1
                                    ? '完成'
                                    : '下一步',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _cardTop(Size size, Rect hole) {
    const estimatedCardHeight = 190.0;
    final below = hole.bottom + 14;
    if (below + estimatedCardHeight < size.height) return below;
    final above = hole.top - estimatedCardHeight - 14;
    if (above > 12) return above;
    return (hole.bottom + 14).clamp(12.0, size.height - estimatedCardHeight);
  }
}

class _Dim extends StatelessWidget {
  const _Dim();

  @override
  Widget build(BuildContext context) {
    return const AbsorbPointer(
      absorbing: true,
      child: ColoredBox(color: Color(0xAA000000)),
    );
  }
}
