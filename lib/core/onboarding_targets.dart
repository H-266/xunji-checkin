import 'package:flutter/widgets.dart';

/// 新手引导需要真正“框住”的控件。
///
/// 不能用固定坐标硬编码：不同字号、语言、刘海屏和页面滚动都会让
/// 目标控件移动。这里用 GlobalKey 直接读取 RenderBox 的实际位置。
class OnboardingTargets {
  const OnboardingTargets._();

  static final GlobalKey todayFab = GlobalKey(debugLabel: 'onboarding-fab');
  static final GlobalKey heatmapGrid = GlobalKey(
    debugLabel: 'onboarding-heatmap',
  );
  static final GlobalKey widgetAdd = GlobalKey(
    debugLabel: 'onboarding-widget-add',
  );
  static final GlobalKey settingsAppearance = GlobalKey(
    debugLabel: 'onboarding-settings',
  );

  static GlobalKey? forStep(int step) => switch (step) {
    0 => todayFab,
    1 => heatmapGrid,
    2 => widgetAdd,
    _ => settingsAppearance,
  };
}
