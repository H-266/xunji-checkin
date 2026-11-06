import 'dart:async';

import '../core/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/onboarding_targets.dart';
import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/csv_export_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/local_log_service.dart';
import '../services/platform_service.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'backup_settings_screen.dart';
import 'error_log_screen.dart';
import 'privacy_policy_screen.dart';
import 'recycle_bin_screen.dart';
import 'tag_management_screen.dart';
import 'tutorial_screen.dart';
import '../widgets/l_text.dart';

/// 阶段 4：设置页。
///
/// 三组功能：
/// 1. 外观：主色相 / 深浅模式 / 字体缩放；
/// 2. 数据：通过系统文件选择器导出 JSON；
/// 3. 保活：电池优化状态、系统设置入口、国产 ROM 手动配置提示。
///
/// 页面不申请存储、网络、定位等任何权限。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// 教程最后一步框选的是设置页顶部；重播前先把列表滚回顶部。
  static void scrollToTopForOnboarding() {
    _SettingsScreenState.replayScrollRequest.value++;
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// 教程重播到“外观设置”一步时，设置页可能停在底部；ListView 的
  /// 懒加载会让顶部目标根本没挂载，ensureVisible 也找不到 context。
  /// 由 AppShell 发一个轻量信号，让设置页自己滚回顶部。
  static final ValueNotifier<int> replayScrollRequest =
      ValueNotifier<int>(0);

  final ScrollController _scroll = ScrollController();
  bool _ignoringBattery = false;
  String _brand = '';
  bool _loadingSystem = true;
  bool _exporting = false;
  bool _importing = false;

  // 拖动期间只改这两个本地预览值，不触碰全局 Provider；
  // 松手后再延迟 250ms 提交，避免一帧内重建整棵树。
  double? _previewHue;
  double? _previewFont;
  Timer? _hueCommit;
  Timer? _fontCommit;

  @override
  void initState() {
    super.initState();
    _loadSystemState();
    _SettingsScreenState.replayScrollRequest.addListener(_onReplayScroll);
  }

  @override
  void dispose() {
    _SettingsScreenState.replayScrollRequest.removeListener(_onReplayScroll);
    _hueCommit?.cancel();
    _fontCommit?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onReplayScroll() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _previewHueValue(double value) {
    setState(() => _previewHue = value);
  }

  void _commitHue(SettingsProvider settings, double value) {
    _hueCommit?.cancel();
    _hueCommit = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      unawaited(settings.setHue(value));
      setState(() => _previewHue = null);
    });
  }

  void _previewFontValue(double value) {
    setState(() => _previewFont = value);
  }

  void _commitFont(SettingsProvider settings, double value) {
    _fontCommit?.cancel();
    _fontCommit = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      unawaited(settings.setFontScale(value));
      setState(() => _previewFont = null);
    });
  }

  Future<void> _loadSystemState() async {
    var ignoring = false;
    var brand = '';
    try {
      final results = await Future.wait<Object>([
        PlatformService.isIgnoringBatteryOptimizations(),
        PlatformService.deviceBrand(),
      ]);
      ignoring = results[0] as bool;
      brand = results[1] as String;
    } catch (error) {
      debugPrint('读取系统状态失败：$error');
    }
    if (!mounted) return;
    setState(() {
      _ignoringBattery = ignoring;
      _brand = brand;
      _loadingSystem = false;
    });
  }

  Future<void> _export(SettingsProvider settings) async {
    if (_exporting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final outcome = await ExportService.export(settings: settings);
      if (!mounted) return;
      if (outcome.cancelled) {
        messenger.showSnackBar(const SnackBar(content: LText('已取消导出')));
      } else {
        messenger.showSnackBar(const SnackBar(content: LText('备份已保存到所选位置')));
      }
    } catch (error) {
      await LocalLogService.log('JSON 导出失败', error: error);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText('导出失败：$error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    final kind = await showAppDialog<CsvKind>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const LText('导出 CSV'),
        children: [
          for (final item in CsvKind.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(item),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: LText(item.label),
                subtitle: LText(switch (item) {
                  CsvKind.checkins => '每条打卡一行，含时间与备注',
                  CsvKind.daily => '每天的任务数、完成数与完成率',
                  CsvKind.tasks => '任务累计天数、连续天数与归档状态',
                  CsvKind.tags => '按标签汇总打卡天数与连续表现',
                  CsvKind.periods => '按周期类型汇总任务与完成天数',
                }),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
        ],
      ),
    );
    if (kind == null || !mounted) return;

    final provider = context.read<TaskProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final uri = await CsvExportService.export(provider, kind);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText(uri == null ? '已取消 CSV 导出' : 'CSV 已保存到所选位置')),
      );
    } catch (error) {
      await LocalLogService.log('CSV 导出失败', error: error);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText('CSV 导出失败：$error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    if (_importing) return;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<TaskProvider>();
    final settings = context.read<SettingsProvider>();
    setState(() => _importing = true);
    try {
      final raw = await PlatformService.importJson();
      if (raw == null) return;
      final preview = await ImportService.parseAsync(raw);
      if (!mounted) return;
      final mode = await showAppDialog<ImportMode>(
        context: context,
        builder: (context) => AlertDialog(
          title: const LText('导入备份'),
          content: LText(
            '备份日期：${preview.exportedAt.isEmpty ? '未知' : preview.exportedAt}\n'
            '任务 ${preview.taskCount} 个 · 打卡 ${preview.checkinCount} 条 · '
            '标签 ${preview.tagCount} 个\n\n'
            '覆盖导入会先清空现有数据；追加导入会保留现有数据并重新编号，'
            '不会破坏原记录。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const LText('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImportMode.append),
              child: const LText('追加导入'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ImportMode.overwrite),
              child: const LText('覆盖导入'),
            ),
          ],
        ),
      );
      if (mode == null) return;
      final result = await ImportService.apply(preview, mode);
      await provider.reload();
      await settings.load();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: LText(
            '导入完成：任务 ${result.tasks} · 打卡 ${result.checkins} · '
            '标签 ${result.tags}',
          ),
        ),
      );
    } on ImportException catch (error) {
      await LocalLogService.log('JSON 导入校验失败', error: error);
      messenger.showSnackBar(SnackBar(content: LText('备份校验失败：$error')));
    } catch (error) {
      await LocalLogService.log('JSON 导入失败', error: error);
      messenger.showSnackBar(SnackBar(content: LText('导入失败：$error')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openBatterySettings() async {
    final messenger = ScaffoldMessenger.of(context);
    await PlatformService.openBatteryOptimizationSettings();
    if (!mounted) return;
    // 用户可能去设置里改了状态，回来时重新读取一次。
    await _loadSystemState();
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: LText('如已允许后台运行，请返回本页查看状态')),
    );
  }

  Future<void> _openAutoStartSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await PlatformService.openAutoStartSettings();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: LText(opened ? '已打开系统自启动管理' : '未找到自启动页，已回退到应用详情')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: LText(AppLocalizations.of(context).settingsTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(child: _VersionPill()),
          ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          LText(
            '按自己的习惯来',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          LText(
            '所有设置只保存在本机，不上传任何数据',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            icon: Icons.palette_outlined,
            title: AppLocalizations.of(context).settingsAppearance,
          ),
          const SizedBox(height: 10),
          KeyedSubtree(
            key: OnboardingTargets.settingsAppearance,
            child: _SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabelRow(
                    title: '热力主色相',
                    value: '${((_previewHue ?? settings.hue).round())}°',
                  ),
                  const SizedBox(height: 2),
                  LText(
                    '固定同一色相，只改变饱和度；只影响热力格子与桌面卡片',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Slider(
                    value: _previewHue ?? settings.hue,
                    min: 0,
                    max: 359,
                    divisions: 359,
                    label: '${(_previewHue ?? settings.hue).round()}°',
                    onChanged: _previewHueValue,
                    onChangeEnd: (value) => _commitHue(settings, value),
                  ),
                  const SizedBox(height: 4),
                  _HuePresets(
                    current: _previewHue ?? settings.hue,
                    onPick: (value) {
                      setState(() => _previewHue = null);
                      unawaited(settings.setHue(value));
                    },
                  ),
                  const SizedBox(height: 12),
                  _HeatPreview(
                    hue: _previewHue ?? settings.hue,
                    isDark: settings.isDark(context),
                  ),
                  const Divider(height: 34),
                  LText(
                    '深色模式',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: LText('跟随系统'),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: LText('浅色'),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: LText('深色'),
                        ),
                      ],
                      selected: <ThemeMode>{settings.themeMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        unawaited(settings.setThemeMode(selection.first));
                      },
                    ),
                  ),
                  const Divider(height: 34),
                  _LabelRow(
                    title: '字体大小',
                    value:
                        '${((_previewFont ?? settings.fontScale) * 100).round()}%',
                    trailing: TextButton(
                      onPressed: () {
                        _fontCommit?.cancel();
                        setState(() => _previewFont = null);
                        unawaited(
                          settings.setFontScale(
                            SettingsProvider.defaultFontScale,
                          ),
                        );
                      },
                      child: const LText('重置'),
                    ),
                  ),
                  Slider(
                    value: _previewFont ?? settings.fontScale,
                    min: 0.85,
                    max: 1.30,
                    divisions: 9,
                    label:
                        '${((_previewFont ?? settings.fontScale) * 100).round()}%',
                    onChanged: _previewFontValue,
                    onChangeEnd: (value) => _commitFont(settings, value),
                  ),
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        _previewFont ?? settings.fontScale,
                      ),
                    ),
                    child: LText(
                      '字号预览：循记打卡，今天也要好好打卡。',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LText(
                    '只影响 App 内文字；桌面小组件保持固定字号，避免溢出。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle(icon: Icons.tune_rounded, title: '通用设置'),
          const SizedBox(height: 10),
          _SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.translate_rounded),
                  title: LText(AppLocalizations.of(context).language),
                  subtitle: LText(
                    AppLocalizations.of(context).settingsLanguageHint,
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.languageCode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: 'system',
                        child: LText(
                          AppLocalizations.of(context).languageSystem,
                        ),
                      ),
                      const DropdownMenuItem(value: 'zh', child: LText('简体中文')),
                      const DropdownMenuItem(
                        value: 'zh_Hant',
                        child: LText('繁體中文'),
                      ),
                      const DropdownMenuItem(
                        value: 'en',
                        child: LText('English'),
                      ),
                      const DropdownMenuItem(value: 'ja', child: LText('日本語')),
                      const DropdownMenuItem(
                        value: 'fr',
                        child: LText('Français'),
                      ),
                      const DropdownMenuItem(
                        value: 'es',
                        child: LText('Español'),
                      ),
                    ],
                    onChanged: (code) {
                      if (code != null) unawaited(settings.setLanguage(code));
                    },
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const LText('完成后自动归档待办'),
                  subtitle: const LText('默认关闭；归档后保留历史，可在回收站恢复'),
                  value: settings.autoArchiveDays > 0,
                  onChanged: (enabled) =>
                      unawaited(settings.setAutoArchiveDays(enabled ? 7 : 0)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const LText('触感反馈'),
                  subtitle: const LText('打卡完成时触发系统轻触感，可在系统设置中关闭'),
                  value: settings.hapticsEnabled,
                  onChanged: (enabled) =>
                      unawaited(settings.setHapticsEnabled(enabled)),
                ),
                if (settings.autoArchiveDays > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const LText('完成多少天后归档'),
                    trailing: DropdownButton<int>(
                      value: settings.autoArchiveDays,
                      underline: const SizedBox.shrink(),
                      items: const [3, 7, 14, 30]
                          .map(
                            (days) => DropdownMenuItem(
                              value: days,
                              child: LText('$days 天'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (days) =>
                          unawaited(settings.setAutoArchiveDays(days ?? 0)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.save_alt_rounded,
            title: AppLocalizations.of(context).settingsData,
          ),
          const SizedBox(height: 10),
          _SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_download_outlined),
                  title: const LText('导出 JSON 备份'),
                  subtitle: const LText('任务、每日打卡、完成时间与设置'),
                  trailing: _exporting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _exporting
                      ? null
                      : () => unawaited(_export(_settings(context))),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const LText('导出 CSV 表格'),
                  subtitle: const LText('打卡明细、每日统计、任务汇总，可选一类'),
                  trailing: _exporting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _exporting ? null : () => unawaited(_exportCsv()),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const LText('导入 JSON 备份'),
                  subtitle: const LText('校验后选择覆盖或追加，不改动无关数据'),
                  trailing: _importing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _importing ? null : () => unawaited(_import()),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.backup_outlined),
                  title: const LText('自动备份'),
                  subtitle: const LText('选择目录后按周/双周/月自动保存，默认关闭'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BackupSettingsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.label_outline_rounded),
                  title: const LText('标签管理'),
                  subtitle: const LText('自定义分类，在今日页按标签筛选'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TagManagementScreen(),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const LText('错误日志'),
                  subtitle: const LText('仅记录崩溃与数据异常，可导出或清空'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ErrorLogScreen(),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restore_from_trash_outlined),
                  title: const LText('归档回收站'),
                  subtitle: const LText('恢复任务，或永久删除任务与历史'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecycleBinScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                LText(
                  '通过系统文件选择器保存，App 不申请存储权限；文件只写到'
                  '你选择的位置。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.battery_saver_outlined,
            title: AppLocalizations.of(context).settingsKeepalive,
          ),
          const SizedBox(height: 10),
          _SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _ignoringBattery
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: _ignoringBattery
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LText(
                        _loadingSystem
                            ? '正在读取电池优化状态…'
                            : (_ignoringBattery ? '已加入电池优化白名单' : '仍受电池优化限制'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LText(
                  '国产 ROM 可能清理后台，导致零点刷新或桌面卡片更新延迟。'
                  '建议手动允许后台运行。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _openBatterySettings,
                      icon: const Icon(Icons.battery_std_rounded, size: 18),
                      label: const LText('电池优化设置'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openAutoStartSettings,
                      icon: const Icon(
                        Icons.settings_suggest_outlined,
                        size: 18,
                      ),
                      label: const LText('自启动管理'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LText(
                  _brandTip(_brand),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const LText('隐私政策与权限说明'),
                  subtitle: const LText('纯离线、不收集数据；仅通知权限用于提醒'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const LText('关于循记打卡'),
                  subtitle: const LText('版本 1.0.1 · MIT 开源 · 本地数据自主可控'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const LText('使用教程与常见问题'),
              subtitle: const LText('重新播放引导，查看打卡重置、备份、通知说明'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TutorialScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SettingsProvider _settings(BuildContext context) =>
      context.read<SettingsProvider>();

  static String _brandTip(String brand) {
    final normalized = brand.toLowerCase();
    if (normalized.contains('xiaomi') || normalized.contains('redmi')) {
      return '小米 / Redmi：设置 → 应用设置 → 循记打卡 → 省电策略 → 无限制，并允许自启动。';
    }
    if (normalized.contains('huawei') || normalized.contains('honor')) {
      return '华为 / 荣耀：设置 → 电池 → 应用启动管理 → 循记打卡 → 手动管理，允许自启动。';
    }
    if (normalized.contains('oppo') || normalized.contains('realme')) {
      return 'OPPO / realme：设置 → 电池 → 应用耗电管理 → 循记打卡 → 允许后台运行。';
    }
    if (normalized.contains('vivo') || normalized.contains('iqoo')) {
      return 'vivo / iQOO：设置 → 电池 → 后台耗电管理 → 循记打卡 → 允许后台高耗电。';
    }
    if (normalized.contains('oneplus')) {
      return '一加：设置 → 电池 → 电池优化 → 循记打卡 → 不优化，并允许自启动。';
    }
    if (normalized.contains('meizu')) {
      return '魅族：设置 → 电量管理 → 后台管理 → 循记打卡 → 允许后台运行。';
    }
    if (normalized.contains('samsung')) {
      return '三星：设置 → 电池 → 后台使用限制 → 循记打卡 → 从“休眠应用”中移除。';
    }
    return '在系统电池设置中允许「循记打卡」后台运行，避免零点刷新被清理。';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        LText(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.title, required this.value, this.trailing});

  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        LText(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        ?trailing,
        LText(
          value,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HuePresets extends StatelessWidget {
  const _HuePresets({required this.current, required this.onPick});

  final double current;
  final ValueChanged<double> onPick;

  static const List<_ThemePreset> _presets = [
    _ThemePreset('暗夜蓝', 220),
    _ThemePreset('森绿', 152),
    _ThemePreset('赭石', 28),
    _ThemePreset('莫兰迪粉', 340),
    _ThemePreset('深空灰', 215),
    _ThemePreset('落日橙', 18),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presets
          .map((preset) {
            final selected = (preset.hue - current).abs() < 0.6;
            final color = HSVColor.fromAHSV(
              1,
              preset.hue,
              0.82,
              0.92,
            ).toColor();
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => onPick(preset.hue),
              avatar: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              label: LText(preset.name),
              labelStyle: TextStyle(
                fontSize: 12.5,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurface,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ThemePreset {
  const _ThemePreset(this.name, this.hue);

  final String name;
  final double hue;
}

class _HeatPreview extends StatelessWidget {
  const _HeatPreview({required this.hue, required this.isDark});

  final double hue;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [0.0, 0.25, 0.5, 0.75, 1.0]
          .map((rate) {
            final color = AppTheme.heatColor(
              hue: hue,
              rate: rate,
              isDark: isDark,
            );
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: rate == 1
                          ? AppTheme.perfectBorderColor(isDark)
                          : Colors.transparent,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LText(
        'v1.0.1',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
