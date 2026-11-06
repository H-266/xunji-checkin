import '../core/app_strings.dart';
import '../core/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../core/onboarding_targets.dart';
import '../l10n/app_localizations.dart';
import '../core/stats.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/heatmap_image_service.dart';
import '../theme/app_theme.dart';
import 'stats_screen.dart';
import 'year_heatmap_screen.dart';
import '../widgets/l_text.dart';

/// 阶段 2：全局热力月历。
///
/// 一张月历，一个格子代表一天；颜色由当天完成率决定。
/// 页面不维护自己的打卡数据，全部从 TaskProvider 读取，
/// 所以今日页打卡后这里会同步刷新。
class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  late final DateTime _currentMonth = AppDateUtils.monthStart(DateTime.now());
  late final int _currentIndex = AppDateUtils.monthIndex(_currentMonth);
  late int _index = _currentIndex;

  void _goTo(int delta) {
    final target = (_index + delta).clamp(0, _currentIndex);
    if (target == _index) return;
    setState(() => _index = target);
  }

  void _backToCurrent() {
    if (_index == _currentIndex) return;
    setState(() => _index = _currentIndex);
  }

  Future<void> _openYear(BuildContext context) async {
    final month = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute<DateTime>(builder: (_) => const YearHeatmapScreen()),
    );
    if (month == null || !mounted) return;
    setState(() {
      _index = AppDateUtils.monthIndex(month).clamp(0, _currentIndex);
    });
  }

  Future<void> _openExportMenu(BuildContext context) async {
    final selected = await showAppSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const LText('保存本月长图'),
              onTap: () => Navigator.pop(sheetContext, 'month'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month_rounded),
              title: const LText('保存全年长图'),
              onTap: () => Navigator.pop(sheetContext, 'year'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || selected == null) return;
    await _exportImage(context, year: selected == 'year');
  }

  Future<void> _exportImage(BuildContext context, {required bool year}) async {
    final provider = context.read<TaskProvider>();
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final dark = settings.isDark(context);
    try {
      final uri = year
          ? await HeatmapImageService.exportYear(
              provider: provider,
              year: AppDateUtils.monthFromIndex(_index).year,
              hue: settings.hue,
              dark: dark,
            )
          : await HeatmapImageService.exportMonth(
              provider: provider,
              month: AppDateUtils.monthFromIndex(_index),
              hue: settings.hue,
              dark: dark,
              tagId: provider.tagFilterId,
              taskId: provider.taskFilterId,
            );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText(uri == null ? '已取消保存' : '热力图长图已保存')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText('保存图片失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TaskProvider>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: LText(AppLocalizations.of(context).heatmapTitle),
        actions: [
          if (_index != _currentIndex)
            IconButton(
              onPressed: _backToCurrent,
              tooltip: AppStrings.tr('回到本月'),
              icon: const Icon(Icons.my_location_rounded),
            ),
          IconButton(
            onPressed: () => _openYear(context),
            tooltip: AppStrings.tr('年度热力图'),
            icon: const Icon(Icons.calendar_view_month_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
            ),
            tooltip: AppStrings.tr('数据统计'),
            icon: const Icon(Icons.insights_rounded),
          ),
          IconButton(
            tooltip: AppStrings.tr('导出图片'),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _openExportMenu(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        '每一天，一格',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      LText(
                        '当天所有任务的完成率，汇总成一种颜色',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LText(
                        '连续全勤 ${provider.currentPerfectStreak} 天',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _TagFilterBar(provider: provider),
          Expanded(
            // 真机实测：切月时叠两棵全屏网格 + 42 个颜色动画，
            // 单帧可达 580–610ms。按“动效不得牺牲性能”退回硬切换。
            child: KeyedSubtree(
              key: OnboardingTargets.heatmapGrid,
              child: _MonthPage(
                key: ValueKey<int>(_index),
                month: AppDateUtils.monthFromIndex(_index),
                isCurrentMonth: _index == _currentIndex,
                onPrevious: _index > 0 ? () => _goTo(-1) : null,
                onNext: _index < _currentIndex ? () => _goTo(1) : null,
                onDayTap: (date) => _showDayDetail(context, date),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDayDetail(BuildContext context, DateTime date) async {
    final provider = context.read<TaskProvider>();
    final stat = provider.statsFor(
      date,
      tagId: provider.tagFilterId,
      taskId: provider.taskFilterId,
    );
    await showAppDialog<void>(
      context: context,
      builder: (_) => _DayDetailDialog(stat: stat),
    );
  }
}

class _TagFilterBar extends StatelessWidget {
  final TaskProvider provider;

  const _TagFilterBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final filtered =
        provider.tagFilterId != null || provider.taskFilterId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openFilterSheet(context),
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(
                provider.filterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (filtered) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: '清除筛选',
              onPressed: provider.clearStatFilter,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) {
        final tasks = provider.allTasks
            .where((task) => task.archivedAt == null)
            .toList(growable: false);
        return SizedBox(
          height: 460,
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded),
                title: const LText('全部任务'),
                trailing: provider.filterTitle == '全部任务'
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  provider.clearStatFilter();
                  Navigator.pop(sheetContext);
                },
              ),
              if (provider.allTags.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: LText('按标签'),
                ),
                for (final tag in provider.allTags)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.label_outline_rounded,
                      color: Color(tag.color),
                    ),
                    title: Text(tag.name),
                    trailing: provider.tagFilterId == tag.id
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () {
                      provider.setTagFilter(tag.id);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
              if (tasks.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: LText('按单个任务'),
                ),
                for (final task in tasks)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline_rounded),
                    title: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: provider.taskFilterId == task.id
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () {
                      provider.setTaskFilter(task.id);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MonthPage extends StatelessWidget {
  final DateTime month;
  final bool isCurrentMonth;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<DateTime> onDayTap;

  const _MonthPage({
    super.key,
    required this.month,
    required this.isCurrentMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final stats = provider.monthStats(
      month,
      tagId: provider.tagFilterId,
      taskId: provider.taskFilterId,
    );
    final today = provider.today;
    final isDark = theme.brightness == Brightness.dark;

    final leading = AppDateUtils.monthStart(month).weekday - 1;
    final days = AppDateUtils.daysInMonth(month);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onPrevious,
                      tooltip: AppStrings.tr('上个月'),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          LText(
                            AppDateUtils.monthTitle(month),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          LText(
                            isCurrentMonth ? '本月' : '历史月份',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onNext,
                      tooltip: AppStrings.tr('下个月'),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _MonthMetrics(stats: stats),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var weekday = 0; weekday < 7; weekday++)
                      Expanded(
                        child: Center(
                          child: LText(
                            AppStrings.weekdayShort(weekday),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                RepaintBoundary(
                  // 用 6×7 的 Column/Row 取代 shrinkWrap GridView：
                  // 月切换时不再触发 SliverGrid 的嵌套布局与滚动语义。
                  child: Column(
                    children: [
                      for (var row = 0; row < 6; row++)
                        Row(
                          children: [
                            for (var col = 0; col < 7; col++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: _buildCell(
                                      context,
                                      month: month,
                                      leading: leading,
                                      days: days,
                                      row: row,
                                      col: col,
                                      today: today,
                                      hue: settings.hue,
                                      isDark: isDark,
                                      tagId: provider.tagFilterId,
                                      taskId: provider.taskFilterId,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _HeatLegend(hue: settings.hue, isDark: isDark),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _ExplainCard(),
      ],
    );
  }

  Widget _buildCell(
    BuildContext context, {
    required DateTime month,
    required int leading,
    required int days,
    required int row,
    required int col,
    required DateTime today,
    required double hue,
    required bool isDark,
    required int? tagId,
    required int? taskId,
  }) {
    final index = row * 7 + col;
    if (index < leading || index >= leading + days) {
      return const SizedBox.shrink();
    }
    final day = index - leading + 1;
    final date = DateTime(month.year, month.month, day);
    final isFuture = date.isAfter(today);
    final stat = isFuture
        ? DayStat.empty(date)
        : context.read<TaskProvider>().statsFor(
            date,
            tagId: tagId,
            taskId: taskId,
          );
    return _HeatCell(
      date: date,
      stat: stat,
      isFuture: isFuture,
      isToday: AppDateUtils.isSameDay(date, today),
      hue: hue,
      isDark: isDark,
      onTap: isFuture ? null : () => onDayTap(date),
    );
  }
}

class _MonthMetrics extends StatelessWidget {
  final MonthStats stats;

  const _MonthMetrics({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _Metric(
          value: '${stats.averagePercent}%',
          label: '月平均完成率',
          color: theme.colorScheme.primary,
        ),
        _MetricDivider(),
        _Metric(value: '${stats.perfectDays}', label: '全勤天数'),
        _MetricDivider(),
        _Metric(value: '${stats.daysWithCompletion}', label: '有完成的天'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _Metric({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          LText(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          LText(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).dividerColor,
    );
  }
}

class _HeatCell extends StatelessWidget {
  final DateTime date;
  final DayStat stat;
  final bool isFuture;
  final bool isToday;
  final double hue;
  final bool isDark;
  final VoidCallback? onTap;

  const _HeatCell({
    required this.date,
    required this.stat,
    required this.isFuture,
    required this.isToday,
    required this.hue,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heat = AppTheme.heatColor(
      hue: hue,
      rate: stat.rate,
      isDark: isDark,
      hasTasks: stat.hasTasks,
    );
    final foreground = stat.hasTasks
        ? AppTheme.onHeatColor(heat)
        : theme.colorScheme.onSurfaceVariant.withValues(
            alpha: isFuture ? 0.30 : 0.80,
          );
    final perfect = stat.isPerfect;

    final border = perfect
        ? AppTheme.perfectBorderColor(isDark)
        : isToday
        ? theme.colorScheme.primary
        : Colors.transparent;

    final child = Container(
      decoration: BoxDecoration(
        color: isFuture
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22)
            : heat,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: perfect ? 1.8 : 1.4),
        boxShadow: perfect
            ? [
                BoxShadow(
                  color: heat.withValues(alpha: 0.55),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 7,
            top: 5,
            child: LText(
              '${date.day}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (perfect)
            Positioned(
              right: 5,
              bottom: 4,
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 12,
                color: foreground,
              ),
            ),
        ],
      ),
    );

    return Semantics(
      label:
          '${AppDateUtils.monthDayLabel(date)}，完成 ${stat.completed}/${stat.total}',
      button: onTap != null,
      enabled: onTap != null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: child,
        ),
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  final double hue;
  final bool isDark;

  const _HeatLegend({required this.hue, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        LText(
          '完成率',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        for (final rate in const [0.0, 0.25, 0.5, 0.75, 1.0])
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.heatColor(
                  hue: hue,
                  rate: rate,
                  isDark: isDark,
                  hasTasks: rate > 0,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        const Spacer(),
        LText(
          '0% → 100%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ExplainCard extends StatelessWidget {
  const _ExplainCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                LText(
                  '怎么算的',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LText(
              '每个格子代表一整天：当天完成数 ÷ 当天有效任务数。'
              '每日任务每天都会计入；临时待办只在自己的有效期内计入。',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.55,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            LText(
              '颜色始终是同一个色相，只改变饱和度：完成度越高颜色越浓，'
              '100% 时饱和度拉满，并带高亮描边。',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.55,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetailDialog extends StatelessWidget {
  final DayStat stat;

  const _DayDetailDialog({required this.stat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TaskProvider>();
    // 弹窗内补卡后，provider 通知重建，统计与任务行实时刷新。
    final day = provider.statsFor(
      stat.date,
      tagId: provider.tagFilterId,
      taskId: provider.taskFilterId,
    );
    final date = day.date;
    final canEdit = !date.isAfter(provider.today);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  AppDateUtils.fullDateLabel(date),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                LText(
                  '${AppDateUtils.weekdayLabel(date)} · 完成 ${day.completed}/${day.total}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: AppStrings.tr('关闭'),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  LText(
                    '${day.percent}%',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: LText(
                      '完成率',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (day.isPerfect)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: LText(
                        '全部完成',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: day.rate,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 18),
              if (day.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: LText(
                    '当天没有任务记录。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                SizedBox(
                  // 当天可能有一百条任务；固定高度 + builder 只构建视口内几行，
                  // 避免一次性布局全部条目导致弹窗卡顿。
                  height: (day.entries.length * 76.0).clamp(88.0, 320.0),
                  child: ListView.builder(
                    // 固定高度已有边界，不能再 shrinkWrap，否则会强制
                    // 一次性测量全部 100 行，正是 580ms 首帧的根因。
                    itemCount: day.entries.length,
                    itemBuilder: (context, index) {
                      final entry = day.entries[index];
                      return _DayEntryRow(
                        entry: entry,
                        date: date,
                        canEdit: canEdit,
                        completedAt: provider.completionAtFor(entry.task, date),
                        onTime: () async {
                          final at = provider.completionAtFor(entry.task, date);
                          if (at == null) return;
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(at),
                            helpText: AppStrings.tr('修改完成时间'),
                          );
                          if (picked == null) return;
                          await provider.setCompletionTime(
                            entry.task,
                            date,
                            picked.hour,
                            picked.minute,
                          );
                        },
                        onToggle: () async {
                          try {
                            await provider.toggleTaskOn(entry.task, date);
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: LText('操作失败：$error')),
                            );
                          }
                        },
                        onRemark: entry.done && entry.task.isDaily
                            ? () => _editRemark(context, provider, entry, date)
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const LText('知道了'),
        ),
      ],
    );
  }
}

Future<void> _editRemark(
  BuildContext context,
  TaskProvider provider,
  DayTaskEntry entry,
  DateTime date,
) async {
  final controller = TextEditingController(
    text: provider.remarkFor(entry.task.id, date) ?? '',
  );
  final result = await showAppDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const LText('打卡备注'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        maxLines: 3,
        decoration: InputDecoration(hintText: AppStrings.tr('补一句当天状态，可留空')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const LText('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const LText('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null) return;
  await provider.setRemark(entry.task, date, result);
}

class _DayEntryRow extends StatelessWidget {
  final DayTaskEntry entry;
  final DateTime date;
  final bool canEdit;
  final DateTime? completedAt;
  final Future<void> Function()? onTime;
  final Future<void> Function()? onToggle;
  final Future<void> Function()? onRemark;

  const _DayEntryRow({
    required this.entry,
    required this.date,
    required this.canEdit,
    required this.completedAt,
    required this.onTime,
    required this.onToggle,
    required this.onRemark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = entry.done;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: canEdit && onToggle != null ? () => onToggle!() : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          children: [
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: done
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    entry.task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  LText(
                    [
                      entry.task.type.label,
                      if (completedAt != null)
                        '完成于 ${AppDateUtils.timeLabel(completedAt!)}',
                      if (providerRemark(context) != null) '有备注',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onTime != null && done)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: AppStrings.tr('修改完成时间'),
                onPressed: () => onTime!(),
                icon: const Icon(Icons.schedule_rounded, size: 20),
              ),
            if (onRemark != null && done)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: AppStrings.tr('编辑备注'),
                onPressed: () => onRemark!(),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  String? providerRemark(BuildContext context) {
    return context.read<TaskProvider>().remarkFor(entry.task.id, date);
  }
}
