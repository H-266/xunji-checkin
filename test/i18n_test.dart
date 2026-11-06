import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/core/app_strings.dart';
import 'package:xunji_checkin/core/date_utils.dart';
import 'package:xunji_checkin/core/app_strings_en.dart';
import 'package:xunji_checkin/core/app_strings_es.dart';
import 'package:xunji_checkin/core/app_strings_extra.dart';
import 'package:xunji_checkin/core/app_strings_fr.dart';
import 'package:xunji_checkin/core/app_strings_ja.dart';
import 'package:xunji_checkin/core/app_strings_long.dart';
import 'package:xunji_checkin/core/app_strings_stats.dart';
import 'package:xunji_checkin/core/zh_hant.dart';
import 'package:xunji_checkin/l10n/app_localizations.dart';
import 'package:xunji_checkin/widgets/l_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('六种语言资源均可加载且标题非空', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.appTitle, isNotEmpty);
      expect(l10n.tabToday, isNotEmpty);
      expect(l10n.settingsData, isNotEmpty);
    }
    expect(AppLocalizations.supportedLocales.length, 6);
  });

  test('英文与中文的标签文案不同', () async {
    final zh = await AppLocalizations.delegate.load(const Locale('zh'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(en.tabToday, isNot(zh.tabToday));
    expect(en.settingsData, isNot(zh.settingsData));
  });

  test('五种语言的正文文案表键集合一致且无空值', () {
    final base = enStrings.keys.toSet();
    for (final map in [jaStrings, frStrings, esStrings]) {
      expect(map.keys.toSet().containsAll(base), isTrue);
      expect(map.values.every((v) => v.trim().isNotEmpty), isTrue);
    }
  });

  test('补充文案表四语种键集合一致且无空值', () {
    final base = extraStrings['en']!.keys.toSet();
    for (final code in ['ja', 'fr', 'es']) {
      final map = extraStrings[code]!;
      expect(map.keys.toSet().containsAll(base), isTrue, reason: code);
      expect(
        map.values.every((v) => v.trim().isNotEmpty),
        isTrue,
        reason: code,
      );
    }
  });

  test('统计粒度文案四语种键集合一致且无空值', () {
    final base = statsStrings['en']!.keys.toSet();
    for (final code in ['ja', 'fr', 'es']) {
      final map = statsStrings[code]!;
      expect(map.keys.toSet().containsAll(base), isTrue, reason: code);
      expect(
        map.values.every((v) => v.trim().isNotEmpty),
        isTrue,
        reason: code,
      );
    }
  });

  test('长帮助与 ROM 说明四语种键集合一致且无空值', () {
    final base = longStrings['en']!.keys.toSet();
    for (final code in ['ja', 'fr', 'es']) {
      final map = longStrings[code]!;
      expect(map.keys.toSet().containsAll(base), isTrue, reason: code);
      expect(
        map.values.every((v) => v.trim().isNotEmpty),
        isTrue,
        reason: code,
      );
    }
  });

  test('动态计数与连续天数文案会本地化', () {
    AppStrings.languageCode = 'en';
    expect(AppStrings.selectedCount(3), '3 selected');
    expect(AppStrings.tr('当前连续 5 天'), 'Current streak 5');
    expect(AppStrings.tr('归档 2 个任务？'), 'Archive 2 tasks?');
    expect(AppStrings.tr('导出失败：目录不可写'), 'Export failed: 目录不可写');
    expect(AppStrings.tr('连续全勤 3 天'), 'Perfect streak: 3 days');
    expect(AppStrings.tr('完成 2/3 · 67%'), '2/3 · 67%');
    expect(AppStrings.tr('备注：今天状态不错'), 'Note: 今天状态不错');
    expect(AppStrings.tr('暗夜蓝'), 'Midnight Blue');
    expect(
      AppStrings.tr('桌面小组件不刷新怎么办？'),
      'What if the home-screen widget does not refresh?',
    );
    expect(
      AppStrings.tr('小米 / Redmi：设置 → 应用设置 → 循记打卡 → 省电策略 → 无限制，并允许自启动。'),
      contains('Xiaomi / Redmi'),
    );
    expect(AppStrings.tr('无标签'), 'No tag');
    expect(AppStrings.tr('已完成'), 'Done');
    expect(AppStrings.tr('未完成'), 'Not done');
    expect(AppStrings.tr('3 项'), '3 items');
    expect(AppStrings.tr('全部任务'), 'All tasks');
    expect(AppStrings.tr('按单个任务'), 'By task');
    expect(AppStrings.tr('触感反馈'), 'Haptics');
    expect(
      AppStrings.tr('通过系统文件选择器保存，App 不申请存储权限；文件只写到你选择的位置。'),
      contains('storage permission'),
    );
    expect(
      AppStrings.tr('国产 ROM 可能清理后台，导致零点刷新或桌面卡片更新延迟。建议手动允许后台运行。'),
      contains('Chinese ROMs'),
    );
    AppStrings.languageCode = 'zh';
  });

  test('日期与导出文件名前缀会跟随语言', () async {
    await initializeDateFormatting('en');
    final date = DateTime(2026, 11, 4);
    AppStrings.languageCode = 'en';
    expect(AppDateUtils.weekdayLabel(date), 'Wednesday');
    expect(AppDateUtils.fullDateLabel(date), contains('November'));
    expect(AppStrings.exportPrefix, 'xunji-checkin');
    AppStrings.languageCode = 'ja';
    expect(AppStrings.exportPrefix, '循記打卡');
    AppStrings.languageCode = 'zh';
    expect(AppDateUtils.weekdayLabel(date), '星期三');
    expect(AppStrings.exportPrefix, '循记打卡');
  });

  test('剩余动态文案在英文下不回落中文', () {
    AppStrings.languageCode = 'en';
    const samples = [
      '3 份',
      '3 天',
      '3 月',
      '3 日',
      '3月',
      '当前连续 3 天',
      '最长连续 3 天',
      '累计打卡 3 天',
      '归档 3 个任务？',
      '永久删除 3 项？',
      '「Run」会从今日列表移除，历史记录仍会保留，可在回收站恢复。',
      '添加失败：PERMISSION_DENIED',
      '本周 3/5 次',
      '3/5 项完成',
      '近 8 周平均 80%',
      '完成 3/5 · 60%',
      '备注：Good day',
      '近期生效：Nov 4, Nov 5',
      '完成于 08:30',
      '累计 10 天 · 均 80%',
      '10 天 · 均 80%',
      '发现 2 条可修复的数据问题',
      '已备份 2026-11-04',
      '导入完成：任务 3 · 打卡 5 · 标签 2',
    ];
    final chinese = RegExp(r'[\u4e00-\u9fff]');
    for (final source in samples) {
      final value = AppStrings.tr(source);
      expect(chinese.hasMatch(value), isFalse, reason: '$source => $value');
    }
    AppStrings.languageCode = 'zh';
  });

  test('四语翻译表无非白名单汉字', () {
    final chinese = RegExp(r'[\u4e00-\u9fff]');
    final brand = RegExp('循记打卡|循記打卡|简体中文|日本語');
    for (final lang in ['en', 'fr', 'es']) {
      final data = jsonDecode(File('tool/tr_$lang.json').readAsStringSync())
          as Map<String, dynamic>;
      for (final entry in data.entries) {
        final value = entry.value.toString().replaceAll(brand, '');
        expect(
          chinese.hasMatch(value),
          isFalse,
          reason: '$lang: ${entry.key} => ${entry.value}',
        );
      }
    }
  });

  test('星期短名在非中文语言无汉字', () {
    final chinese = RegExp(r'[\u4e00-\u9fff]');
    for (final lang in ['en', 'fr', 'es']) {
      AppStrings.languageCode = lang;
      for (var i = 0; i < 7; i++) {
        final label = AppStrings.weekdayShort(i);
        expect(chinese.hasMatch(label), isFalse, reason: '$lang/$i: $label');
      }
    }
    AppStrings.languageCode = 'zh';
  });

  test('LText 语言码与繁体取词', () {
    expect(
      AppStrings.codeForLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      'zh_Hant',
    );
    expect(AppStrings.codeForLocale(const Locale('en')), 'en');
    AppStrings.languageCode = 'zh_Hant';
    expect(AppStrings.tr('设置'), '設定');
    expect(AppStrings.tr('已完成'), '已完成');
    AppStrings.languageCode = 'zh';
  });

  test('繁体中文使用台湾软件用语且不残留简体字', () {
    expect(toTraditionalChinese('设置数据任务'), '設定資料任務');
    expect(toTraditionalChinese('新建任务'), '新增任務');
    expect(toTraditionalChinese('备注'), '備註');
    AppStrings.languageCode = 'zh_Hant';
    expect(AppStrings.tr('热力统计'), '熱力統計');
    expect(AppStrings.selectedCount(3), '已選 3 項');
    expect(AppStrings.tr('已完成'), '已完成');
    AppStrings.languageCode = 'zh';
  });

  testWidgets('切换 Locale 时 const LText 立即重建', (tester) async {
    await tester.pumpWidget(const _LocaleHost());
    expect(find.text('保存'), findsOneWidget);

    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('保存'), findsNothing);
    AppStrings.languageCode = 'zh';
  });
}

class _LocaleHost extends StatefulWidget {
  const _LocaleHost();

  @override
  State<_LocaleHost> createState() => _LocaleHostState();
}

class _LocaleHostState extends State<_LocaleHost> {
  Locale _locale = const Locale('zh');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Column(
          children: [
            const LText('保存'),
            TextButton(
              onPressed: () => setState(() => _locale = const Locale('en')),
              child: const Text('switch'),
            ),
          ],
        ),
      ),
    );
  }
}
