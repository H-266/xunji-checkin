import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'循记打卡'**
  String get appTitle;

  /// No description provided for @tabToday.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get tabToday;

  /// No description provided for @tabHeatmap.
  ///
  /// In zh, this message translates to:
  /// **'热力'**
  String get tabHeatmap;

  /// No description provided for @tabWidgets.
  ///
  /// In zh, this message translates to:
  /// **'小组件'**
  String get tabWidgets;

  /// No description provided for @tabSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get tabSettings;

  /// No description provided for @todayTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日打卡'**
  String get todayTitle;

  /// No description provided for @heatmapTitle.
  ///
  /// In zh, this message translates to:
  /// **'热力统计'**
  String get heatmapTitle;

  /// No description provided for @statsTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据统计'**
  String get statsTitle;

  /// No description provided for @widgetTitle.
  ///
  /// In zh, this message translates to:
  /// **'小组件配置'**
  String get widgetTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观设置'**
  String get settingsAppearance;

  /// No description provided for @settingsData.
  ///
  /// In zh, this message translates to:
  /// **'数据管理'**
  String get settingsData;

  /// No description provided for @settingsKeepalive.
  ///
  /// In zh, this message translates to:
  /// **'保活帮助'**
  String get settingsKeepalive;

  /// No description provided for @settingsGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用设置'**
  String get settingsGeneral;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// No description provided for @languageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageJa.
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get languageJa;

  /// No description provided for @languageFr.
  ///
  /// In zh, this message translates to:
  /// **'Français'**
  String get languageFr;

  /// No description provided for @languageEs.
  ///
  /// In zh, this message translates to:
  /// **'Español'**
  String get languageEs;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @addTask.
  ///
  /// In zh, this message translates to:
  /// **'新建任务'**
  String get addTask;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In zh, this message translates to:
  /// **'切换后立即生效，无需重启'**
  String get settingsLanguageHint;

  /// No description provided for @offline.
  ///
  /// In zh, this message translates to:
  /// **'纯离线'**
  String get offline;

  /// No description provided for @dailySection.
  ///
  /// In zh, this message translates to:
  /// **'每日打卡'**
  String get dailySection;

  /// No description provided for @todoSection.
  ///
  /// In zh, this message translates to:
  /// **'临时待办'**
  String get todoSection;

  /// No description provided for @allTags.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get allTags;

  /// No description provided for @emptyDaily.
  ///
  /// In zh, this message translates to:
  /// **'还没有每日任务'**
  String get emptyDaily;

  /// No description provided for @emptyTodo.
  ///
  /// In zh, this message translates to:
  /// **'暂无临时待办'**
  String get emptyTodo;

  /// No description provided for @detailsStats.
  ///
  /// In zh, this message translates to:
  /// **'详情与统计'**
  String get detailsStats;

  /// No description provided for @editTask.
  ///
  /// In zh, this message translates to:
  /// **'编辑任务'**
  String get editTask;

  /// No description provided for @archiveTask.
  ///
  /// In zh, this message translates to:
  /// **'归档任务'**
  String get archiveTask;

  /// No description provided for @backfill.
  ///
  /// In zh, this message translates to:
  /// **'补卡'**
  String get backfill;

  /// No description provided for @postponeOneDay.
  ///
  /// In zh, this message translates to:
  /// **'延期一天'**
  String get postponeOneDay;

  /// No description provided for @writeRemark.
  ///
  /// In zh, this message translates to:
  /// **'写备注'**
  String get writeRemark;

  /// No description provided for @saveRemark.
  ///
  /// In zh, this message translates to:
  /// **'保存备注'**
  String get saveRemark;

  /// No description provided for @todayNoTasks.
  ///
  /// In zh, this message translates to:
  /// **'今天还没有任务'**
  String get todayNoTasks;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
