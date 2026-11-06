import 'package:flutter/material.dart';

/// 全局主题与热力配色。
///
/// 热力图的核心规则：始终使用同一个色相 H，只让“浓度”随完成率升高。
/// 为了让 0% 在深色模式下仍然像一块安静的空底色，这里把高饱和色
/// 按完成率叠加到明/暗底色上；视觉上等价于饱和度从 0 升到 100%，
/// 100% 时完全不透明，得到最跳脱的高亮色。
class AppTheme {
  AppTheme._();

  // 深蓝视觉体系：页面底色、卡片、热力空底色都带一点蓝，
  // 避免 220° 主色与环境色脱节。
  static const Color darkBase = Color(0xFF0B1220);
  static const Color lightBase = Color(0xFFF5F7FC);
  static const Color darkHeatBase = Color(0xFF1B2436);
  static const Color lightHeatBase = Color(0xFFE7ECF5);
  static const Color brandBlue = Color(0xFF1F3A8A);

  /// 品牌深蓝只用于 App 外壳（按钮、导航、SnackBar 等）。
  /// 热力色相由用户设置决定，两者互不串色。
  static const double brandHue = 220;

  /// 单色相热力色。
  ///
  /// - 无任务 / 0%：浅底色，不染色；
  /// - 0~100%：同色相，浓度线性升高；
  /// - 100%：完全不透明的高亮色，界面上再叠加描边。
  /// 热力色缓存：月/年视图一次会请求几百个格子，同一 (色相, 完成率,
  /// 深浅色) 只计算一次。按千分位量化完成率，避免浮点尾数导致键爆炸。
  static final Map<int, Color> _heatCache = <int, Color>{};

  static Color heatColor({
    required double hue,
    required double rate,
    required bool isDark,
    bool hasTasks = true,
  }) {
    final normalized = rate.clamp(0.0, 1.0).toDouble();
    if (!hasTasks || normalized <= 0) {
      return isDark ? darkHeatBase : lightHeatBase;
    }

    final hueBucket = ((hue % 360) * 10).round();
    final rateBucket = (normalized * 1000).round();
    final key = Object.hash(hueBucket, rateBucket, isDark);
    final cached = _heatCache[key];
    if (cached != null) return cached;
    if (_heatCache.length > 512) _heatCache.clear();

    final base = isDark ? darkHeatBase : lightHeatBase;
    final saturated = HSVColor.fromAHSV(1, hue % 360, 1, 1).toColor();

    // 深色背景下低完成率需要更高的最小不透明度才看得见；
    // 100% 时 alpha = 1，颜色完全饱和、最亮。
    final alpha = isDark ? 0.16 + 0.84 * normalized : 0.10 + 0.90 * normalized;
    final color = Color.alphaBlend(saturated.withValues(alpha: alpha), base);
    _heatCache[key] = color;
    return color;
  }

  /// 热力格子上文字/图标的对比色。
  static Color onHeatColor(Color background) {
    return background.computeLuminance() > 0.55
        ? const Color(0xFF0B1220)
        : Colors.white;
  }

  /// 100% 格子的描边色。
  static Color perfectBorderColor(bool isDark) =>
      isDark ? Colors.white : brandBlue;

  /// Material 3 浅色 / 深色主题。
  static ThemeData build({
    required double hue,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final seed = HSVColor.fromAHSV(
      1,
      hue % 360,
      0.66,
      isDark ? 0.82 : 0.68,
    ).toColor();

    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? darkBase : lightBase,
    );

    final cardColor = isDark ? const Color(0xFF141D30) : Colors.white;
    final borderColor = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.45 : 0.65,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0E1626) : Colors.white,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return base.textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // 跟随 Material 3 的反色表面，深蓝主题下不会再出现旧的绿色提示条。
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _ReducedMotionPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

/// 系统开启“减少动画”时页面推入/返回零时长；否则保持 300ms FadeUpwards。
class _ReducedMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const _ReducedMotionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return const FadeUpwardsPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
