import 'package:flutter/material.dart';

/// 全局动效参数。
///
/// 统一时长/曲线，避免各页面各写一套；系统开启“移除动画”时自动降级为
/// 无动画，低端机与无障碍场景不会因为动画产生额外掉帧。
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);

  /// 进入 / 展开 / 状态变更。
  static const Curve curve = Curves.easeOutCubic;

  /// 退出 / 收起；不使用回弹。
  static const Curve exitCurve = Curves.easeInCubic;

  static Duration of(BuildContext context, Duration base) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : base;
  }

  static AnimationStyle _style(BuildContext context, Duration base) {
    final duration = of(context, base);
    return AnimationStyle(
      curve: curve,
      duration: duration,
      reverseCurve: exitCurve,
      reverseDuration: duration,
    );
  }

  /// 弹出菜单统一 320ms 淡入/放大，保证真机上肉眼可见。
  static AnimationStyle popupStyle(BuildContext context) =>
      _style(context, const Duration(milliseconds: 320));

  /// 对话框统一 220ms 淡入/缩放入场，150ms 淡出。
  static AnimationStyle dialogStyle(BuildContext context) => AnimationStyle(
    curve: curve,
    duration: of(context, standard),
    reverseCurve: exitCurve,
    reverseDuration: of(context, const Duration(milliseconds: 150)),
  );

  /// 底部面板统一 220ms 上滑淡入。
  static AnimationStyle sheetStyle(BuildContext context) =>
      _style(context, standard);
}

/// 带统一动效的对话框：220ms 淡入 + 0.96→1 缩放入场。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useSafeArea = true,
  bool useRootNavigator = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black54,
    transitionDuration: AppMotion.of(context, AppMotion.standard),
    useRootNavigator: useRootNavigator,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.curve,
        reverseCurve: AppMotion.exitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 底部面板沿用系统 250ms 上滑，但固定走统一入口，后续可整体换动画。
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // 系统负责上滑，内容再补一层 220ms 淡入 + 8px 上移，
    // 避免只有整块面板在动、菜单项像“瞬间出现”。
    builder: (sheetContext) => TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.of(sheetContext, AppMotion.standard),
      curve: AppMotion.curve,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: builder(sheetContext),
    ),
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
  );
}
