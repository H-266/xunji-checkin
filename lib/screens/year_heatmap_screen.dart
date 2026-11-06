import '../core/app_strings.dart';
import '../core/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../core/stats.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/l_text.dart';

/// GitHub 风格年度热力图。
///
/// 返回一个 [DateTime] 表示用户点了某个月份，调用方据此跳回月视图。
class YearHeatmapScreen extends StatefulWidget {
  const YearHeatmapScreen({super.key});

  @override
  State<YearHeatmapScreen> createState() => _YearHeatmapScreenState();
}

class _YearHeatmapScreenState extends State<YearHeatmapScreen> {
  late int _year = DateTime.now().year;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final first = DateTime(_year, 1, 1);
    final last = DateTime(_year, 12, 31);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final weekCount = (last.difference(gridStart).inDays / 7).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const LText('年度热力图'),
        actions: [
          IconButton(
            tooltip: AppStrings.tr('上一年'),
            onPressed: _year > 2000 ? () => setState(() => _year--) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Center(
            child: LText(
              '$_year',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: AppStrings.tr('下一年'),
            onPressed: _year < DateTime.now().year
                ? () => setState(() => _year++)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _openFilter(context, provider),
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(
                provider.filterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _YearMetric(
                  value: '${_checkinDays(provider)}',
                  label: '打卡天数',
                ),
              ),
              Expanded(
                child: _YearMetric(
                  value: '${provider.overallLongestStreak}',
                  label: '最长连续',
                ),
              ),
              Expanded(
                child: _YearMetric(
                  value: '${provider.completedDaysInYear(_year)}',
                  label: '全勤天数',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LText(
            '点击月份回到月视图',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(12, (index) {
              final month = DateTime(_year, index + 1);
              return ActionChip(
                label: LText('${index + 1}月'),
                onPressed: () => Navigator.of(context).pop(month),
              );
            }),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              // 只构建进入视口的周列。年度视图一年 53 列，若一次生成全部
              // 371 个格子，横向滑动时每帧都要搬运整棵树；懒构建后首屏
              // 只创建可见的 8~10 列。
              child: SizedBox(
                height: 7 * 18,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: weekCount,
                  itemExtent: 18,
                  itemBuilder: (context, week) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        children: List.generate(7, (weekday) {
                          final date = gridStart.add(
                            Duration(days: week * 7 + weekday),
                          );
                          if (date.isAfter(last)) {
                            return const SizedBox(width: 14, height: 18);
                          }
                          final inYear = !date.isBefore(first);
                          final isFuture = date.isAfter(provider.today);
                          final stat = inYear && !isFuture
                              ? provider.statsFor(
                                  date,
                                  tagId: provider.tagFilterId,
                                  taskId: provider.taskFilterId,
                                )
                              : DayStat.empty(date);
                          final color = isFuture || !inYear
                              ? theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35)
                              : AppTheme.heatColor(
                                  hue: settings.hue,
                                  rate: stat.rate,
                                  isDark: isDark,
                                  hasTasks: stat.hasTasks,
                                );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Tooltip(
                              message: inYear
                                  ? '${AppDateUtils.fullDateLabel(date)} '
                                        '${stat.completed}/${stat.total}'
                                  : '',
                              child: InkWell(
                                onTap: inYear && !isFuture
                                    ? () => _showDay(context, date)
                                    : null,
                                child: RepaintBoundary(
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                      border: stat.isPerfect
                                          ? Border.all(
                                              color:
                                                  AppTheme.perfectBorderColor(
                                                    isDark,
                                                  ),
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              LText(
                '少',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              for (final rate in const [0.0, 0.25, 0.5, 0.75, 1.0])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppTheme.heatColor(
                        hue: settings.hue,
                        rate: rate,
                        isDark: isDark,
                        hasTasks: rate > 0,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              LText(
                '多',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              LText(
                '一格 = 一天',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _checkinDays(TaskProvider provider) {
    var days = 0;
    var cursor = DateTime(_year, 1, 1);
    final lastDay = DateTime(_year, 12, 31);
    while (!cursor.isAfter(lastDay) && !cursor.isAfter(provider.today)) {
      final stat = provider.statsFor(
        cursor,
        tagId: provider.tagFilterId,
        taskId: provider.taskFilterId,
      );
      if (stat.completed > 0) days++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return days;
  }

  Future<void> _openFilter(BuildContext context, TaskProvider provider) async {
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

  Future<void> _showDay(BuildContext context, DateTime date) async {
    final provider = context.read<TaskProvider>();
    final stat = provider.statsFor(
      date,
      tagId: provider.tagFilterId,
      taskId: provider.taskFilterId,
    );
    await showAppDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: LText(AppDateUtils.fullDateLabel(date)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  '完成 ${stat.completed}/${stat.total} · ${stat.percent}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (stat.entries.isEmpty)
                  LText(
                    '这一天没有有效任务',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  )
                else
                  ...stat.entries.map((entry) {
                    final remark = provider.remarkFor(entry.task.id, date);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            entry.done
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 18,
                            color: entry.done
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LText(entry.task.title),
                                if (remark != null && remark.isNotEmpty)
                                  LText(
                                    '备注：$remark',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const LText('知道了'),
            ),
          ],
        );
      },
    );
  }
}

class _YearMetric extends StatelessWidget {
  final String value;
  final String label;

  const _YearMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        LText(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
          ),
        ),
        LText(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
