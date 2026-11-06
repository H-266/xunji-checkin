import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../core/onboarding_targets.dart';
import '../l10n/app_localizations.dart';
import '../core/stats.dart';
import '../providers/settings_provider.dart';
import '../models/tag.dart';
import '../providers/task_provider.dart';
import '../services/platform_service.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';
import '../widgets/l_text.dart';

/// 小组件配置页。
///
/// 这里只负责“预览 + 发起系统添加 + 手动添加引导”，不做任何卡片内交互。
/// 卡片点击统一由原生 PendingIntent 唤起 App，再按 tab 参数跳转。
class WidgetConfigScreen extends StatefulWidget {
  const WidgetConfigScreen({super.key});

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  bool? _pinSupported;
  bool _busy = false;
  bool _ignoringBattery = true;
  String _brand = '';
  String _checkinSize = '4×2';
  String _heatmapSize = '4×2';
  int? _checkinTagId;
  int? _heatmapTagId;

  @override
  void initState() {
    super.initState();
    _loadPlatformState();
  }

  Future<void> _loadPlatformState() async {
    final supported = await WidgetService.isPinSupported();
    final brand = await PlatformService.deviceBrand();
    final ignoring = await PlatformService.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _pinSupported = supported;
      _brand = brand;
      _ignoringBattery = ignoring;
    });
  }

  Future<void> _pin({required bool heatmap}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final tasks = context.read<TaskProvider>();
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 添加前再写一次，避免桌面拿到上一次会话的旧 JSON。
      await WidgetService.updateAllWidgets(
        tasks: tasks,
        settings: settings,
        dark: settings.isDark(context),
        languageCode: Localizations.localeOf(context).languageCode,
      );
      await WidgetService.requestPinWidget(
        heatmap: heatmap,
        tagId: heatmap ? _heatmapTagId : _checkinTagId,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: LText('已发起系统添加。若没有弹窗，请按下方“手动添加”操作。')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText('添加失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pinMini() async {
    if (_busy) return;
    setState(() => _busy = true);
    final tasks = context.read<TaskProvider>();
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WidgetService.updateAllWidgets(
        tasks: tasks,
        settings: settings,
        dark: settings.isDark(context),
        languageCode: Localizations.localeOf(context).languageCode,
      );
      await WidgetService.pinMini();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: LText('已发起 1×1 迷你卡片添加')));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText('添加失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBatterySettings() async {
    await PlatformService.openBatteryOptimizationSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = context.watch<TaskProvider>();
    final settings = context.watch<SettingsProvider>();
    final dark = settings.isDark(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: LText(AppLocalizations.of(context).widgetTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: _Pill(label: '仅 Android')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          LText(
            '把今天放到桌面上',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 3),
          LText(
            '两种卡片 · 多种尺寸 · 点击打开 App 打卡',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _TagSelector(
            label: '打卡卡片绑定标签',
            value: _checkinTagId,
            tags: tasks.allTags,
            onChanged: (value) => setState(() => _checkinTagId = value),
          ),
          const SizedBox(height: 8),
          _WidgetCard(
            title: '打卡任务卡片',
            subtitle: '今日任务与勾选状态',
            icon: Icons.checklist_rounded,
            sizes: const ['2×1', '2×2', '4×2', '4×4'],
            selectedSize: _checkinSize,
            onSizeChanged: (value) => setState(() => _checkinSize = value),
            preview: _CheckinPreview(
              size: _checkinSize,
              provider: tasks,
              dark: dark,
            ),
            actionLabel: '添加打卡卡片',
            buttonKey: OnboardingTargets.widgetAdd,
            busy: _busy,
            onAdd: () => _pin(heatmap: false),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.widgetMinimal,
            onChanged: (value) async {
              final languageCode = Localizations.localeOf(context).languageCode;
              await settings.setWidgetMinimal(value);
              await WidgetService.updateAllWidgets(
                tasks: tasks,
                settings: settings,
                dark: dark,
                languageCode: languageCode,
              );
            },
            title: const LText('任务卡片极简列表'),
            subtitle: const LText('隐藏进度圆环，优先显示更多任务'),
          ),
          const SizedBox(height: 8),
          _TagSelector(
            label: '热力卡片绑定标签',
            value: _heatmapTagId,
            tags: tasks.allTags,
            onChanged: (value) => setState(() => _heatmapTagId = value),
          ),
          const SizedBox(height: 8),
          _WidgetCard(
            title: '热力日历卡片',
            subtitle: '最近 8 周的完成度热力方格',
            icon: Icons.grid_view_rounded,
            sizes: const ['2×2', '4×2', '4×4'],
            selectedSize: _heatmapSize,
            onSizeChanged: (value) => setState(() => _heatmapSize = value),
            preview: _HeatmapPreview(
              size: _heatmapSize,
              provider: tasks,
              hue: settings.hue,
              dark: dark,
            ),
            actionLabel: '添加热力卡片',
            busy: _busy,
            onAdd: () => _pin(heatmap: true),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pinMini,
            icon: const Icon(Icons.circle_outlined, size: 18),
            label: const LText('添加 1×1 迷你进度卡片'),
          ),
          const SizedBox(height: 14),
          _InstructionCard(supported: _pinSupported),
          const SizedBox(height: 14),
          _BatteryCard(
            brand: _brand,
            ignoring: _ignoringBattery,
            onOpenSettings: _openBatterySettings,
          ),
        ],
      ),
    );
  }
}

class _TagSelector extends StatelessWidget {
  const _TagSelector({
    required this.label,
    required this.value,
    required this.tags,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<Tag> tags;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.label_outline_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LText(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DropdownButton<int>(
          value: value ?? 0,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(12),
          items: [
            const DropdownMenuItem(value: 0, child: LText('全部标签')),
            for (final tag in tags)
              DropdownMenuItem(
                value: tag.id ?? 0,
                child: LText(tag.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (selected) =>
              onChanged(selected == null || selected == 0 ? null : selected),
        ),
      ],
    );
  }
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sizes,
    required this.selectedSize,
    required this.onSizeChanged,
    required this.preview,
    required this.actionLabel,
    required this.busy,
    required this.onAdd,
    this.buttonKey,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> sizes;
  final String selectedSize;
  final ValueChanged<String> onSizeChanged;
  final Widget preview;
  final String actionLabel;
  final bool busy;
  final VoidCallback onAdd;
  final Key? buttonKey;

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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      LText(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            preview,
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final size in sizes)
                  ChoiceChip(
                    label: LText(size),
                    selected: size == selectedSize,
                    onSelected: busy ? null : (_) => onSizeChanged(size),
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: buttonKey,
                onPressed: busy ? null : onAdd,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_to_home_screen_rounded),
                label: LText(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 打卡卡片预览。比例与原生尺寸保持一致：2×1/4×2 = 2:1，2×2/4×4 = 1:1。
class _CheckinPreview extends StatelessWidget {
  const _CheckinPreview({
    required this.size,
    required this.provider,
    required this.dark,
  });

  final String size;
  final TaskProvider provider;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final stat = provider.todayStat;
    final entries = stat.entries.take(8).toList();
    final theme = Theme.of(context);
    final surface = dark ? const Color(0xFF141D30) : Colors.white;
    final border = dark ? const Color(0xFF2A364D) : const Color(0xFFE2E8F2);

    return AspectRatio(
      aspectRatio: size == '2×2' || size == '4×4' ? 1 : 2,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: switch (size) {
          '2×1' => _miniRow(theme, stat.percent, stat.completed, stat.total),
          '2×2' => _square(theme, stat, entries),
          '4×2' => _wide(theme, stat, entries),
          _ => _full(theme, stat, entries),
        },
      ),
    );
  }

  Widget _miniRow(ThemeData theme, int percent, int done, int total) {
    return Row(
      children: [
        _Ring(percent: percent, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LText(
                '今日打卡',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              LText(
                '$done/$total 项完成',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        LText(
          '$percent%',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _square(ThemeData theme, DayStat stat, List<DayTaskEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Ring(percent: stat.percent, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: LText(
                '今日打卡  ${stat.completed}/${stat.total}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: _TaskPreviewList(entries: entries, limit: 3)),
      ],
    );
  }

  Widget _wide(ThemeData theme, DayStat stat, List<DayTaskEntry> entries) {
    final left = entries.take(3).toList();
    final right = entries.skip(3).take(3).toList();
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Ring(percent: stat.percent, size: 54),
              const SizedBox(height: 6),
              LText(
                '${stat.completed}/${stat.total} 项',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _TaskPreviewList(entries: left, limit: 3)),
              Expanded(child: _TaskPreviewList(entries: right, limit: 3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _full(ThemeData theme, DayStat stat, List<DayTaskEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Ring(percent: stat.percent, size: 46),
            const SizedBox(width: 10),
            Expanded(
              child: LText(
                '今日打卡  ${stat.completed}/${stat.total}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Expanded(child: _TaskPreviewList(entries: entries, limit: 8)),
        const SizedBox(height: 4),
        LText(
          '点击卡片打开 App 打卡',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TaskPreviewList extends StatelessWidget {
  const _TaskPreviewList({required this.entries, required this.limit});

  final List<DayTaskEntry> entries;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = entries.take(limit).toList();
    if (shown.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: LText(
          '还没有任务',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final entry = shown[index];
        final done = entry.done;
        final title = entry.task.title;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 12,
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: LText(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.percent, required this.size});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: (percent / 100).clamp(0, 1).toDouble(),
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: accent.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          LText(
            '$percent%',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 热力卡片预览。4×2 用 14×4，4×4 用 8×7，保证每个格子都是正方形。
class _HeatmapPreview extends StatelessWidget {
  const _HeatmapPreview({
    required this.size,
    required this.provider,
    required this.hue,
    required this.dark,
  });

  final String size;
  final TaskProvider provider;
  final double hue;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = provider.today;
    final monday = AppDateUtils.weekStart(today);
    final start = monday.subtract(const Duration(days: 49));
    final days = <DateTime>[
      for (var i = 0; i < 56; i++) start.add(Duration(days: i)),
    ];
    final columns = size == '4×2' ? 14 : 8;
    final rows = size == '4×2' ? 4 : 7;
    final surface = dark ? const Color(0xFF141D30) : Colors.white;
    final border = dark ? const Color(0xFF2A364D) : const Color(0xFFE2E8F2);

    final past = days.where((day) => !day.isAfter(today)).toList();
    final average = past.isEmpty
        ? 0.0
        : past.fold<double>(
                0,
                (sum, day) => sum + provider.statsFor(day).rate,
              ) /
              past.length;

    return AspectRatio(
      aspectRatio: size == '4×2' ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LText(
                  '最近 8 周',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                LText(
                  '近 8 周平均 ${(average * 100).round()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Expanded(
              child: _HeatGrid(
                provider: provider,
                days: days,
                columns: columns,
                rows: rows,
                today: today,
                hue: hue,
                dark: dark,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                LText(
                  '${AppDateUtils.monthDayLabel(start)} — ${AppDateUtils.monthDayLabel(today)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                LText(
                  '点击卡片打开 App',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatGrid extends StatelessWidget {
  const _HeatGrid({
    required this.provider,
    required this.days,
    required this.columns,
    required this.rows,
    required this.today,
    required this.hue,
    required this.dark,
  });

  final TaskProvider provider;
  final List<DateTime> days;
  final int columns;
  final int rows;
  final DateTime today;
  final double hue;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 2.5;
        final cell = ((constraints.maxWidth - gap * (columns - 1)) / columns)
            .clamp(2.0, (constraints.maxHeight - gap * (rows - 1)) / rows)
            .toDouble();
        final gridWidth = columns * cell + (columns - 1) * gap;
        final gridHeight = rows * cell + (rows - 1) * gap;
        return Center(
          child: SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < rows; row++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var column = 0; column < columns; column++)
                          _cell(
                            context,
                            days[row * columns + column],
                            cell,
                            gap,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cell(BuildContext context, DateTime date, double cell, double gap) {
    final isFuture = date.isAfter(today);
    final stat = isFuture ? null : provider.statsFor(date);
    final isToday = AppDateUtils.isSameDay(date, today);
    final color = isFuture
        ? AppTheme.heatColor(hue: hue, rate: 0, isDark: dark, hasTasks: false)
        : AppTheme.heatColor(
            hue: hue,
            rate: stat!.rate,
            isDark: dark,
            hasTasks: stat.hasTasks,
          );
    final perfect = stat != null && stat.isPerfect;
    return Padding(
      padding: EdgeInsets.only(right: gap, bottom: gap),
      child: Container(
        width: cell,
        height: cell,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          border: isToday
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.1,
                )
              : perfect
              ? Border.all(
                  color: dark ? Colors.white70 : Colors.black54,
                  width: 0.8,
                )
              : null,
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({required this.supported});

  final bool? supported;

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
                Icon(Icons.touch_app_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                LText(
                  '手动添加（国产 ROM 推荐）',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _Step(index: '1', text: '回到桌面，长按空白处'),
            const _Step(index: '2', text: '选择「小组件 / 添加小部件」'),
            const _Step(index: '3', text: '找到「循记打卡」，拖入打卡或热力卡片'),
            const SizedBox(height: 8),
            LText(
              supported == false
                  ? '当前桌面不支持一键添加，请按上面步骤手动添加。'
                  : '一键添加会弹出系统确认页；部分 MIUI/EMUI/ColorOS 会直接关闭，请用上面的手动方式。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: LText(
              index,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: LText(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({
    required this.brand,
    required this.ignoring,
    required this.onOpenSettings,
  });

  final String brand;
  final bool ignoring;
  final VoidCallback onOpenSettings;

  String get _tip {
    final value = brand.toLowerCase();
    if (value.contains('xiaomi') || value.contains('redmi')) {
      return '小米/Redmi：设置 → 应用设置 → 循记打卡 → 省电策略 → 无限制，并允许自启动。';
    }
    if (value.contains('huawei') || value.contains('honor')) {
      return '华为/荣耀：设置 → 电池 → 应用启动管理 → 循记打卡 → 手动管理，允许自启动。';
    }
    if (value.contains('oppo') || value.contains('realme')) {
      return 'OPPO/realme：设置 → 电池 → 应用耗电管理 → 循记打卡 → 允许后台运行。';
    }
    if (value.contains('vivo') || value.contains('iqoo')) {
      return 'vivo/iQOO：设置 → 电池 → 后台耗电管理 → 循记打卡 → 允许后台高耗电。';
    }
    return '在系统电池设置中允许「循记打卡」后台运行，避免零点刷新被清理。';
  }

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
                  ignoring
                      ? Icons.battery_saver_rounded
                      : Icons.battery_alert_rounded,
                  color: ignoring
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                LText(
                  ignoring ? '后台刷新正常' : '建议关闭电池优化',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LText(
              '${ignoring ? '系统未限制本 App 的后台刷新。' : _tip}\n'
              '零点刷新使用非精确闹钟，不申请精确闹钟/开机广播权限；重启后打开一次 App 即可恢复调度。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (!ignoring) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const LText('打开电池优化设置'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.android_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          LText(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
