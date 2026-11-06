import 'dart:async';

import '../core/app_motion.dart';
import '../core/app_strings.dart';
import '../core/onboarding_targets.dart';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/backup_service.dart';
import '../services/import_service.dart';
import '../services/onboarding_service.dart';
import '../services/reminder_service.dart';
import '../services/widget_service.dart';
import '../widgets/onboarding_overlay.dart';
import 'heatmap_screen.dart';
import 'settings_screen.dart';
import 'support_prompt.dart';
import 'today_screen.dart';
import 'widget_config_screen.dart';
import '../widgets/l_text.dart';

/// 主容器：四个 Tab，IndexedStack 保持页面状态。
///
/// 除了原有的跨天刷新，这里还是小组件数据的唯一同步入口：
/// - TaskProvider / SettingsProvider 任一变化 → 250ms 防抖 → 写 JSON + 刷新卡片；
/// - 系统深浅色变化、App 回到前台 → 重新同步；
/// - 卡片点击 URI → 定位今日/热力/小组件页。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  /// 语言切换会重建整个 AppShell；保留最后停留的 Tab，避免用户被弹回首页。
  static int _lastTab = 0;
  int _index = _lastTab;
  Timer? _dayTimer;
  Timer? _syncDebounce;
  Timer? _reminderDebounce;
  StreamSubscription<Uri?>? _widgetClickSub;
  int _onboardingStep = -1;

  late final TaskProvider _tasks;
  late final SettingsProvider _settings;
  bool _listenersAttached = false;

  /// 当前页面缓存对应的语言；切换语言时整组丢弃，强制重新取词。
  String? _pagesLanguageCode;

  /// 懒加载 + 保活：首次进入某 Tab 才构建，之后保留 State。
  /// 这样再次切换不会重新跑统计/热力构建，也不会每次滑动都丢滚动位置。
  final List<Widget?> _pages = <Widget?>[const TodayScreen(), null, null, null];

  /// 主题切换时只让当前页立即换肤；非当前页冻结旧 ThemeData，避免四页同时重建。
  final List<ThemeData?> _pageThemes = <ThemeData?>[null, null, null, null];

  @override
  void initState() {
    super.initState();
    _tasks = context.read<TaskProvider>();
    _settings = context.read<SettingsProvider>();
    if (_index != 0) _pages[_index] ??= _pageFor(_index);
    WidgetsBinding.instance.addObserver(this);

    _tasks.addListener(_scheduleWidgetSync);
    _tasks.addListener(_scheduleReminderSync);
    // 打卡是轻量刷新（不 notifyListeners），单独驱动桌面卡片同步。
    _tasks.checkinRevision.addListener(_scheduleWidgetSync);
    _settings.addListener(_scheduleSettingsWidgetSync);
    // 设置是异步从 SQLite 读的。必须等它加载完再判断是否首次启动，
    // 否则已看过引导的用户每次冷启动都会被遮罩。
    _settings.addListener(_maybeShowOnboarding);
    _listenersAttached = true;
    OnboardingService.instance.replayRequested.addListener(_replayOnboarding);

    _dayTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _tasks.refreshToday();
    });

    // 首帧之后再同步，避免 initState 阶段读取 MediaQuery。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleWidgetSync();
      _restoreWidgetLaunch();
      _maybeShowOnboarding();
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1600), () {
          if (!mounted || _onboardingStep >= 0) return;
          unawaited(SupportPrompt.maybeShow(context));
        }),
      );

      // 首帧只做与“今天”直接相关的轻量工作。完整性检查、自动备份、
      // 提醒重排都会读库/走原生通道，延后到界面可交互之后再执行，
      // 避免冷启动第一帧被磁盘 IO 抢占。
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 300), () async {
          if (mounted) await _syncReminders();
        }),
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 800), () async {
          if (mounted) await _autoArchiveCompleted();
        }),
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1200), () async {
          if (mounted) await _checkIntegrity();
        }),
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1800), () async {
          if (mounted) await _maybeAutoBackup();
        }),
      );
    });
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  void _maybeShowOnboarding() {
    if (!mounted || !_settings.isLoaded) return;
    _settings.removeListener(_maybeShowOnboarding);
    if (!_settings.onboardingSeen && _onboardingStep < 0) {
      setState(() => _onboardingStep = 0);
    }
  }

  Future<void> _restoreWidgetLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _handleWidgetUri(uri);
    } catch (error) {
      debugPrint('读取小组件启动参数失败：$error');
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    final tab = uri.queryParameters['tab'];
    final target = switch (tab) {
      'heatmap' || 'stats' => 1,
      'widgets' || 'widget' => 2,
      'settings' => 3,
      'today' => 0,
      _ => switch (uri.host) {
        'heatmap' || 'stats' => 1,
        'widgets' || 'widget' => 2,
        'settings' => 3,
        _ => 0,
      },
    };
    if (target != _index) {
      _instantTab(target);
    }
  }

  /// Provider 的 notifyListeners 可能连续触发多次，防抖后统一写一次。
  void _scheduleWidgetSync() {
    if (!mounted) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 250), _syncWidgets);
  }

  /// 设置类变化（主题/色相/字号）不必和打卡一样 250ms 内写卡片；
  /// 延后到交互结束，避免和主题重建抢同一帧。
  void _scheduleSettingsWidgetSync() {
    if (!mounted) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 900), _syncWidgets);
  }

  Future<void> _syncWidgets() async {
    if (!mounted) return;
    final dark = _settings.isDark(context);
    await WidgetService.updateAllWidgets(
      tasks: _tasks,
      settings: _settings,
      dark: dark,
      languageCode: Localizations.localeOf(context).languageCode,
    );
  }

  void _scheduleReminderSync() {
    if (!mounted) return;
    _reminderDebounce?.cancel();
    _reminderDebounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_syncReminders()),
    );
  }

  Future<void> _syncReminders() async {
    try {
      await ReminderService.sync(_tasks.allTasks);
    } catch (error) {
      debugPrint('同步本地提醒失败：$error');
    }
  }

  /// 启动时做一次轻量完整性检查；发现孤立记录时给出一键修复。
  Future<void> _checkIntegrity() async {
    try {
      final issues = await _tasks.checkIntegrity();
      if (!mounted || issues.isEmpty) return;
      final snapshot = await BackupService.readLocalSnapshot();
      if (!mounted) return;
      await showAppDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const LText('数据检查'),
          content: LText(
            '发现 ${issues.length} 条可修复的数据问题：\n\n'
            '${issues.take(6).join('\n')}\n\n'
            '建议先修复；也可以到“设置 → 数据管理 → 导入 JSON 备份”'
            '恢复最近一次备份。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const LText('稍后'),
            ),
            if (snapshot != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _restoreSnapshot(snapshot);
                },
                child: const LText('回滚最近备份'),
              ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _tasks.repairIntegrity();
                await _tasks.reload();
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: LText('数据修复完成')));
              },
              child: const LText('一键修复'),
            ),
          ],
        ),
      );
    } catch (error) {
      debugPrint('数据完整性检查失败：$error');
    }
  }

  /// 自动备份只在前台启动/回到前台时检查，不常驻、不联网。
  Future<void> _autoArchiveCompleted() async {
    if (!_settings.isLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (!mounted || !_settings.isLoaded) return;
    await _tasks.autoArchiveCompletedTodos(_settings.autoArchiveDays);
  }

  Future<void> _maybeAutoBackup() async {
    try {
      final result = await BackupService.maybeRun(_settings);
      if (result != null) {
        debugPrint('自动备份完成：${result.fileName}');
      }
    } catch (error) {
      debugPrint('自动备份失败：$error');
    }
  }

  void _replayOnboarding() {
    if (!mounted) return;
    setState(() {
      _index = 0;
      _lastTab = 0;
      _onboardingStep = 0;
      _pages[0] ??= _pageFor(0);
    });
  }

  void _changeOnboardingStep(int step) {
    setState(() {
      _onboardingStep = step.clamp(0, 3);
      _index = _onboardingStep;
      _lastTab = _index;
      _pages[_index] ??= _pageFor(_index);
    });
    // 设置页可能停在底部；最后一步要框住顶部的外观卡片，先滚回去。
    // 即使目标仍不可见，蒙层也有兜底卡片，不会把用户卡死。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 设置页顶部的目标在 ListView 懒加载区，滚到底部时根本没有
      // context；直接让设置页自己滚回顶部，比 ensureVisible 可靠。
      if (_onboardingStep == 3) {
        SettingsScreen.scrollToTopForOnboarding();
        return;
      }
      final target = OnboardingTargets.forStep(_onboardingStep)?.currentContext;
      if (target == null || !target.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        ),
      );
    });
  }

  Future<void> _finishOnboarding({required bool skipped}) async {
    await _settings.setOnboardingSeen(true);
    if (!mounted) return;
    setState(() => _onboardingStep = -1);
    if (!skipped) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: LText('教程完成，随时可在设置里重播')));
    }
  }

  /// 用最近一次自动备份的本地快照覆盖恢复；导入服务负责事务和校验。
  Future<void> _restoreSnapshot(String raw) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final preview = ImportService.parse(raw);
      await ImportService.apply(preview, ImportMode.overwrite);
      await _tasks.reload();
      await _settings.load();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: LText('已回滚到最近备份')));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText('回滚失败：$error')));
    }
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    _syncDebounce?.cancel();
    _reminderDebounce?.cancel();
    _widgetClickSub?.cancel();
    OnboardingService.instance.replayRequested.removeListener(
      _replayOnboarding,
    );
    if (_listenersAttached) {
      _tasks.removeListener(_scheduleWidgetSync);
      _tasks.removeListener(_scheduleReminderSync);
      _tasks.checkinRevision.removeListener(_scheduleWidgetSync);
      _settings.removeListener(_scheduleSettingsWidgetSync);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _tasks.refreshToday();
      _scheduleWidgetSync();
      unawaited(_maybeAutoBackup());
      unawaited(_autoArchiveCompleted());
    }
  }

  @override
  void didChangePlatformBrightness() {
    // 主题为“跟随系统”时，桌面卡片也要跟着换深浅色。
    _scheduleWidgetSync();
  }

  Widget _pageFor(int index) => switch (index) {
    1 => const HeatmapScreen(),
    2 => const WidgetConfigScreen(),
    3 => const SettingsScreen(),
    _ => const TodayScreen(),
  };

  void _instantTab(int value) {
    if (value == _index) return;
    setState(() {
      _index = value;
      _lastTab = value;
      _pages[value] ??= _pageFor(value);
    });
  }

  void _selectTab(int value) => _instantTab(value);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // 以当前 Localizations 为准同步文案表；再按语言给页面换 key，
    // 这样切回中文时 const LText 也会重新 build，不会残留上一语言。
    final locale = Localizations.localeOf(context);
    final languageCode = AppStrings.codeForLocale(locale);
    if (AppStrings.languageCode != languageCode) {
      AppStrings.languageCode = languageCode;
    }
    // IndexedStack 会一直持有旧页面 Element；仅改 KeyedSubtree 的 key
    // 在部分 Flutter 版本里不足以让 const LText 重新取词。语言一变就
    // 主动丢弃整组页面缓存，确保每一页都用新语言重新构建。
    if (_pagesLanguageCode != languageCode) {
      _pagesLanguageCode = languageCode;
      for (var i = 0; i < _pages.length; i++) {
        _pages[i] = null;
      }
      _pages[0] = const TodayScreen();
      _pages[_index] = _pageFor(_index);
    }
    _pageThemes[_index] = theme;
    return PopScope(
      // 引导期间锁止系统返回，避免用户直接退出引导。
      canPop: _onboardingStep < 0,
      child: Scaffold(
        body: Stack(
          children: [
            // 保活页签：首次进入才构建，之后直接复用已有 Element/State。
            // 之前每次切换都重新 build 热力/统计页，是“越切越卡”的主因。
            Positioned.fill(
              child: IndexedStack(
                key: ValueKey('tabs_$languageCode'),
                index: _index,
                children: List<Widget>.generate(4, (i) {
                  final page = _pages[i];
                  if (page == null) return const SizedBox.shrink();
                  // 页面已保活，切换只改 IndexedStack 的可见页。
                  // 实测整页 opacity/slide 会把平均帧从 4.4ms 拉到 8.3ms，
                  // 按“动效不得牺牲性能”原则退回零成本切换。
                  return Theme(
                    data: _pageThemes[i] ?? theme,
                    child: TickerMode(
                      enabled: _index == i,
                      // 语言切换时整页重挂载，确保 const LText 也会重新取词，
                      // 避免切回中文后仍残留上一次的语言。
                      child: KeyedSubtree(
                        key: ValueKey('page_${i}_$languageCode'),
                        child: page,
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (_onboardingStep >= 0)
              Positioned.fill(
                child: OnboardingOverlay(
                  step: _onboardingStep,
                  onStepChanged: _changeOnboardingStep,
                  onFinish: () => unawaited(_finishOnboarding(skipped: false)),
                  onSkip: () => unawaited(_finishOnboarding(skipped: true)),
                ),
              ),
          ],
        ),
        bottomNavigationBar: AbsorbPointer(
          // 引导蒙层在 body 内，底栏在 body 外，必须单独锁止。
          absorbing: _onboardingStep >= 0,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _selectTab,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.today_outlined),
                selectedIcon: const Icon(Icons.today_rounded),
                label: l10n.tabToday,
              ),
              NavigationDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: const Icon(Icons.grid_view_rounded),
                label: l10n.tabHeatmap,
              ),
              NavigationDestination(
                icon: const Icon(Icons.widgets_outlined),
                selectedIcon: const Icon(Icons.widgets_rounded),
                label: l10n.tabWidgets,
              ),
              NavigationDestination(
                icon: const Icon(Icons.tune_outlined),
                selectedIcon: const Icon(Icons.tune_rounded),
                label: l10n.tabSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
