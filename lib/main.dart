import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'core/app_strings.dart';
import 'providers/settings_provider.dart';
import 'providers/task_provider.dart';
import 'screens/app_shell.dart';
import 'screens/privacy_consent_screen.dart';
import 'services/local_log_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(LocalLogService.init());
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      LocalLogService.log(
        'FlutterError',
        error: details.exception,
        stack: details.stack,
      ),
    );
  };
  runZonedGuarded(
    () => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider()..load(),
          ),
          ChangeNotifierProvider<TaskProvider>(
            create: (_) => TaskProvider()..load(),
          ),
        ],
        child: const XunjiApp(),
      ),
    ),
    (error, stack) {
      unawaited(LocalLogService.log('Uncaught', error: error, stack: stack));
    },
  );
}

String _languageCodeOf(Locale locale) {
  if (locale.languageCode == 'zh' &&
      (locale.scriptCode == 'Hant' || locale.countryCode == 'TW')) {
    return 'zh_Hant';
  }
  return locale.languageCode;
}

class XunjiApp extends StatelessWidget {
  const XunjiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // 在 MaterialApp 构建前先确定语言，避免 builder 与子树同帧读到旧值。
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final requested = settings.locale == null
        ? _languageCodeOf(systemLocale)
        : _languageCodeOf(settings.locale!);
    AppStrings.languageCode =
        const {'zh', 'zh_Hant', 'en', 'ja', 'fr', 'es'}.contains(requested)
        ? requested
        : 'zh';

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 默认 220° 深蓝；用户切换色相时 App 强调色、热力格与卡片同步。
      theme: AppTheme.build(hue: settings.hue, brightness: Brightness.light),
      darkTheme: AppTheme.build(hue: settings.hue, brightness: Brightness.dark),
      themeMode: settings.themeMode,
      // 主题插值会让整棵树每帧重算 ThemeData；本机实测深/浅切换明显卡顿。
      // 这里直接一次性换主题，避免 300ms 的逐帧插值成本。
      themeAnimationDuration: Duration.zero,
      themeAnimationCurve: Curves.easeOutCubic,
      // 字体缩放只作用于 App 内文本，桌面小组件仍使用固定 dp 排版。
      builder: (context, child) {
        final resolved = Localizations.localeOf(context);
        final resolvedCode = _languageCodeOf(resolved);
        AppStrings.languageCode =
            AppLocalizations.supportedLocales.any(
              (l) => _languageCodeOf(l) == resolvedCode,
            )
            ? resolvedCode
            : 'zh';
        final media = MediaQuery.of(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        final surface = Theme.of(context).scaffoldBackgroundColor;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: surface,
            systemNavigationBarColor: surface,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(settings.fontScale),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: !settings.isLoaded
          ? const _BootSplash()
          : settings.privacyAccepted
          ? AppShell(key: ValueKey('shell_$requested'))
          : PrivacyConsentScreen(key: ValueKey('privacy_$requested')),
    );
  }
}

/// 数据库/设置读取期间只显示纯色启动页，避免先闪一下首页再弹隐私门。
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0B1220),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
