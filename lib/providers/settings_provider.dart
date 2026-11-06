import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/task.dart';
import '../services/platform_service.dart';

/// 外观设置。
///
/// 所有设置都持久化到本地 `settings` 表，不联网、不上传。
/// 默认值按「循记打卡」的深蓝视觉体系：深色模式、220° 色相、1.0 字号。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({AppDatabase? database})
    : _db = database ?? AppDatabase.instance;

  static const double defaultHue = 220;
  static const double defaultFontScale = 1.0;
  static const ThemeMode defaultThemeMode = ThemeMode.dark;

  static const String _hueKey = 'heatmap_hue';
  static const String _themeModeKey = 'theme_mode';
  static const String _fontScaleKey = 'font_scale';
  static const String _onboardingKey = 'onboarding_seen';
  static const String _widgetMinimalKey = 'widget_minimal';
  static const String _lastTaskTypeKey = 'last_task_type';
  static const String _autoArchiveDaysKey = 'auto_archive_days';
  static const String _languageKey = 'app_language';
  static const String _privacyAcceptedKey = 'privacy_accepted';
  static const String _hapticsKey = 'haptics_enabled';
  static const String _launchCountKey = 'support_launch_count';
  static const String _supportNextKey = 'support_next_prompt';
  static const String _supportDisabledKey = 'support_disabled';

  final AppDatabase _db;

  double _hue = defaultHue;
  ThemeMode _themeMode = defaultThemeMode;
  double _fontScale = defaultFontScale;
  bool _onboardingSeen = false;
  bool _privacyAccepted = false;
  bool _widgetMinimal = false;
  bool _hapticsEnabled = true;
  TaskType _lastTaskType = TaskType.daily;
  int _autoArchiveDays = 0;
  String _languageCode = 'system';
  int _launchCount = 0;
  int _supportNextPrompt = 20;
  bool _supportPromptDisabled = false;
  bool _loaded = false;

  double get hue => _hue;
  ThemeMode get themeMode => _themeMode;
  bool get onboardingSeen => _onboardingSeen;
  bool get widgetMinimal => _widgetMinimal;
  bool get hapticsEnabled => _hapticsEnabled;

  int get launchCount => _launchCount;
  bool get supportPromptDisabled => _supportPromptDisabled;

  /// 当前应用语言是否属于中文语系（简体/繁体）。
  ///
  /// 赞赏不是编译开关：运行时跟随 App 语言，切到外文立即隐藏。
  bool get supportVisible {
    if (_languageCode == 'zh' || _languageCode == 'zh_Hant') return true;
    if (_languageCode == 'system') {
      return WidgetsBinding
              .instance
              .platformDispatcher
              .locale
              .languageCode ==
          'zh';
    }
    return false;
  }

  bool get shouldShowSupportPrompt =>
      supportVisible &&
      !_supportPromptDisabled &&
      _launchCount >= _supportNextPrompt;

  /// 新建任务时默认选中的类型，记住上一次选择。
  TaskType get lastTaskType => _lastTaskType;

  /// 临时待办完成 N 天后自动归档；0 表示关闭。
  int get autoArchiveDays => _autoArchiveDays;

  /// `system` 表示跟随系统；其余为受支持的语言代码。
  String get languageCode => _languageCode;

  /// 是否已同意隐私政策；未同意前不进入主界面。
  bool get privacyAccepted => _privacyAccepted;

  /// 传给 MaterialApp.locale；返回 null 时由 Flutter 跟随系统并回退中文。
  Locale? get locale {
    if (_languageCode == 'system') return null;
    if (_languageCode == 'zh_Hant') {
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    }
    return Locale(_languageCode);
  }

  /// 仅作用于 App 内文本；桌面小组件使用固定 dp，不跟随系统/App 字体缩放。
  double get fontScale => _fontScale;
  bool get isLoaded => _loaded;

  /// Material 3 seed。热力图本身使用固定色相 + 饱和度；
  /// 这里让按钮、导航等组件跟主色相保持同一家族。
  Color get seedColor => HSVColor.fromAHSV(1, _hue % 360, 0.62, 0.82).toColor();

  bool isDark(BuildContext context) =>
      _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  Future<void> load() async {
    try {
      final values = await _db.loadSettings();
      final storedHue = double.tryParse(values[_hueKey] ?? '');
      if (storedHue != null) {
        _hue = storedHue.clamp(0, 359).toDouble();
      }

      final storedFontScale = double.tryParse(values[_fontScaleKey] ?? '');
      if (storedFontScale != null) {
        _fontScale = storedFontScale.clamp(0.85, 1.30).toDouble();
      }

      // 没有存过主题时保留默认深色；不能把 null 解析成“跟随系统”。
      final storedTheme = values[_themeModeKey];
      if (storedTheme != null) {
        _themeMode = _parseThemeMode(storedTheme);
      }
      _onboardingSeen = values[_onboardingKey] == '1';
      _privacyAccepted = values[_privacyAcceptedKey] == '1';
      _widgetMinimal = values[_widgetMinimalKey] == '1';
      _hapticsEnabled = values[_hapticsKey] != '0';
      _lastTaskType = values[_lastTaskTypeKey] == 'todo'
          ? TaskType.todo
          : TaskType.daily;
      _autoArchiveDays = (int.tryParse(values[_autoArchiveDaysKey] ?? '') ?? 0)
          .clamp(0, 90);
      final storedLanguage = values[_languageKey];
      if (storedLanguage != null &&
          const {
            'system',
            'zh',
            'zh_Hant',
            'en',
            'ja',
            'fr',
            'es',
          }.contains(storedLanguage)) {
        _languageCode = storedLanguage;
      }

      _launchCount = int.tryParse(values[_launchCountKey] ?? '') ?? 0;
      _supportNextPrompt = int.tryParse(values[_supportNextKey] ?? '') ?? 20;
      _supportPromptDisabled = values[_supportDisabledKey] == '1';

      // 运行时跟随应用语言：外文不计数、不写库，避免留下赞赏痕迹。
      if (supportVisible) {
        _launchCount += 1;
        await _db.setSetting(_launchCountKey, '$_launchCount');
      }
    } catch (error) {
      // 设置读取失败不应阻塞 App；使用默认值继续运行。
      debugPrint('设置加载失败：$error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setHue(double value) async {
    final normalized = value.clamp(0, 359).toDouble();
    if ((normalized - _hue).abs() < 0.01) return;

    _hue = normalized;
    notifyListeners();
    await _db.setSetting(_hueKey, normalized.toStringAsFixed(1));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _db.setSetting(_themeModeKey, mode.name);
  }

  Future<void> setPrivacyAccepted(bool accepted) async {
    if (_privacyAccepted == accepted) return;
    _privacyAccepted = accepted;
    notifyListeners();
    await _db.setSetting(_privacyAcceptedKey, accepted ? '1' : '0');
  }

  Future<void> setOnboardingSeen(bool seen) async {
    if (_onboardingSeen == seen) return;
    _onboardingSeen = seen;
    notifyListeners();
    await _db.setSetting(_onboardingKey, seen ? '1' : '0');
  }

  Future<void> setLastTaskType(TaskType type) async {
    if (_lastTaskType == type) return;
    _lastTaskType = type;
    notifyListeners();
    await _db.setSetting(_lastTaskTypeKey, type.dbValue);
  }

  Future<void> setAutoArchiveDays(int days) async {
    final normalized = days.clamp(0, 90);
    if (_autoArchiveDays == normalized) return;
    _autoArchiveDays = normalized;
    notifyListeners();
    await _db.setSetting(_autoArchiveDaysKey, '$normalized');
  }

  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
    await _db.setSetting(_languageKey, code);
    // Android 13+ 同步 per-app locale；原生资源与桌面卡片随系统重建。
    // zh_Hant 使用 zh-TW，才能命中 values-zh-rTW。
    await PlatformService.setAppLanguage(
      code == 'zh_Hant' ? 'zh-TW' : code,
    );
  }

  Future<void> setWidgetMinimal(bool value) async {
    if (_widgetMinimal == value) return;
    _widgetMinimal = value;
    notifyListeners();
    await _db.setSetting(_widgetMinimalKey, value ? '1' : '0');
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    notifyListeners();
    await _db.setSetting(_hapticsKey, value ? '1' : '0');
  }

  /// 「下次再说」：本次关闭，累计到 100 次再提示。
  Future<void> deferSupportPrompt() async {
    _supportNextPrompt = 100;
    notifyListeners();
    await _db.setSetting(_supportNextKey, '100');
  }

  /// 勾选「不再提示」并关闭后永久禁用。
  Future<void> disableSupportPrompt() async {
    _supportPromptDisabled = true;
    notifyListeners();
    await _db.setSetting(_supportDisabledKey, '1');
  }

  Future<void> setFontScale(double value) async {
    final normalized = value.clamp(0.85, 1.30).toDouble();
    if ((normalized - _fontScale).abs() < 0.005) return;

    _fontScale = normalized;
    notifyListeners();
    await _db.setSetting(_fontScaleKey, normalized.toStringAsFixed(2));
  }

  static ThemeMode _parseThemeMode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => defaultThemeMode,
    };
  }
}
