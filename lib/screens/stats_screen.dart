import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_motion.dart';
import '../core/date_utils.dart';
import '../core/stats.dart';
import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/trend_chart.dart';
import '../widgets/period_trend_card.dart';
import '../widgets/l_text.dart';

/// 高级统计：全部来自本地 TaskProvider，不额外保存统计结果。
///
/// 口径说明：
/// - 打卡天数 = 至少有一条有效打卡记录的日期数；
/// - 最长连续 = 所有任务历史最长全勤连续天数；
/// - 周/月趋势 = 该周期内「完成次数 / 有效任务次数」。
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final weeks = provider.last12WeekRates;
    final days = provider.last30Days;
    final today = AppDateUtils.dayOnly(DateTime.now());
    final thisMonthStart = AppDateUtils.monthStart(today);
    final lastMonthStart = DateTime(today.year, today.month - 1, 1);
    final thisWeekStart = AppDateUtils.weekStart(today);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final tagId = provider.tagFilterId;
    final taskId = provider.taskFilterId;
    final thisMonth = provider.periodStats(
      thisMonthStart,
      today,
      tagId: tagId,
      taskId: taskId,
    );
    final lastMonth = provider.periodStats(
      lastMonthStart,
      AppDateUtils.monthEnd(lastMonthStart),
      tagId: tagId,
      taskId: taskId,
    );
    final thisWeek = provider.periodStats(
      thisWeekStart,
      today,
      tagId: tagId,
      taskId: taskId,
    );
    final lastWeek = provider.periodStats(
      lastWeekStart,
      thisWeekStart.subtract(const Duration(days: 1)),
      tagId: tagId,
      taskId: taskId,
    );
    final rankings = provider.taskRankings.take(5).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: LText(AppLocalizations.of(context).statsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
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
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [
              _MetricCard(
                value: '${provider.totalCheckinDays}',
                label: '累计打卡天数',
                icon: Icons.event_available_rounded,
              ),
              _MetricCard(
                value: '${provider.overallLongestStreak}',
                label: '最长连续天数',
                icon: Icons.local_fire_department_rounded,
              ),
              _MetricCard(
                value: '${provider.completedDaysInYear(DateTime.now().year)}',
                label: '今年全勤天数',
                icon: Icons.calendar_month_rounded,
              ),
            ],
          ),
          const SizedBox(height: 22),
          LText(
            '环比分析',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          LText(
            '本月截至今天 vs 上月；本周 vs 上周',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  _CompareRow(
                    label: '本月完成率',
                    current: thisMonth.percent,
                    previous: lastMonth.percent,
                    suffix: '%',
                  ),
                  _CompareRow(
                    label: '本周完成率',
                    current: thisWeek.percent,
                    previous: lastWeek.percent,
                    suffix: '%',
                  ),
                  _CompareRow(
                    label: '本月全勤',
                    current: thisMonth.perfectDays,
                    previous: lastMonth.perfectDays,
                    suffix: ' 天',
                  ),
                  _CompareRow(
                    label: '本周全勤',
                    current: thisWeek.perfectDays,
                    previous: lastWeek.perfectDays,
                    suffix: ' 天',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ComparisonChart(
            monthCurrent: thisMonth.rate,
            monthPrevious: lastMonth.rate,
            weekCurrent: thisWeek.rate,
            weekPrevious: lastWeek.rate,
          ),
          const SizedBox(height: 22),
          LText(
            '任务完成度排行',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          LText(
            '按累计完成天数排序，同时展示最长连续',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (rankings.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LText(
                  '还没有可排行的任务，先完成几次打卡吧。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < rankings.length; i++) ...[
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        child: LText(
                          '${i + 1}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      title: LText(
                        rankings[i].task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: LText(
                        '累计 ${rankings[i].totalDays} 天 · '
                        '最长连续 ${rankings[i].longestStreak} 天',
                      ),
                      trailing: LText(
                        '${rankings[i].totalDays}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (i != rankings.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 22),
          LText(
            '维度拆解',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          LText(
            '标签、任务类型、时段与周期表现，全部同源计算',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _TagPerformanceCard(items: provider.tagPerformance),
          const SizedBox(height: 10),
          _TypePerformanceCard(data: provider.typePerformance),
          const SizedBox(height: 10),
          _HourCard(data: provider.hourDistribution, hue: settings.hue),
          const SizedBox(height: 10),
          _PeriodCard(data: provider.periodPerformance),
          const SizedBox(height: 22),
          LText(
            '完成趋势',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          LText(
            '12 周柱状 · 30 天折线，点按图表看明细',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TrendChart(weeks: weeks, days: days, hue: settings.hue),
          const SizedBox(height: 12),
          PeriodTrendCard(provider: provider, hue: settings.hue),
          const SizedBox(height: 18),
          LText(
            '统计只读取本机 SQLite，不会上传。非计划日不计入总数，'
            '临时待办只在创建到完成当天计入。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonChart extends StatelessWidget {
  const _ComparisonChart({
    required this.monthCurrent,
    required this.monthPrevious,
    required this.weekCurrent,
    required this.weekPrevious,
  });

  final double monthCurrent;
  final double monthPrevious;
  final double weekCurrent;
  final double weekPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 96,
      child: CustomPaint(
        painter: _ComparisonPainter(
          values: [monthPrevious, monthCurrent, weekPrevious, weekCurrent],
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.35),
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.35),
            theme.colorScheme.primary,
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 74),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              LText('上月', style: theme.textTheme.labelSmall),
              LText('本月', style: theme.textTheme.labelSmall),
              LText('上周', style: theme.textTheme.labelSmall),
              LText('本周', style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonPainter extends CustomPainter {
  _ComparisonPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 18;
    final groupWidth = size.width / 2;
    final barWidth = 24.0;
    for (var group = 0; group < 2; group++) {
      for (var index = 0; index < 2; index++) {
        final value = values[group * 2 + index].clamp(0.0, 1.0);
        final height = (baseline - 8) * value;
        final left =
            group * groupWidth +
            groupWidth / 2 -
            barWidth -
            6 +
            index * (barWidth + 12);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, baseline - height, barWidth, height),
          const Radius.circular(5),
        );
        canvas.drawRRect(rect, Paint()..color = colors[group * 2 + index]);
      }
    }
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ComparisonPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.suffix,
  });

  final String label;
  final int current;
  final int previous;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = current - previous;
    final positive = delta >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: LText(label)),
          LText(
            '$current$suffix',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 74,
            child: LText(
              '较上期 ${positive ? '+' : ''}$delta$suffix',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall?.copyWith(
                color: positive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            LText(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            LText(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagPerformanceCard extends StatelessWidget {
  const _TagPerformanceCard({required this.items});

  final List<TagPerformance> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LText('还没有标签数据。给任务加标签后，这里会按标签汇总。'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              '按标签',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items.take(6)) ...[
              Row(
                children: [
                  Expanded(
                    child: LText(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  LText(
                    '${item.totalDays} 天 · 均 ${item.percent}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: item.averageRate,
                  minHeight: 5,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypePerformanceCard extends StatelessWidget {
  const _TypePerformanceCard({required this.data});

  final TypePerformance data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              '按类型',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _TypeRow(
              label: '打卡任务',
              count: data.dailyTotal,
              done: data.dailyDone,
              rate: data.dailyRate,
            ),
            const SizedBox(height: 10),
            _TypeRow(
              label: '临时待办',
              count: data.todoTotal,
              done: data.todoDone,
              rate: data.todoRate,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.label,
    required this.count,
    required this.done,
    required this.rate,
  });

  final String label;
  final int count;
  final int done;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(width: 76, child: LText(label)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 7,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        LText(
          '${(rate * 100).round()}% · $done/$count',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HourCard extends StatelessWidget {
  const _HourCard({required this.data, required this.hue});

  final HourDistribution data;
  final double hue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = HSVColor.fromAHSV(1, hue % 360, 0.72, 0.86).toColor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LText(
                  '时段分布',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                LText(
                  data.total == 0
                      ? '暂无打卡时间'
                      : '高峰 ${data.peakHour.toString().padLeft(2, '0')}:00',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              width: double.infinity,
              child: CustomPaint(
                painter: _HourPainter(counts: data.counts, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourPainter extends CustomPainter {
  const _HourPainter({required this.counts, required this.color});

  final List<int> counts;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxCount = counts.fold<int>(1, (a, b) => b > a ? b : a);
    final barWidth = size.width / counts.length;
    final paint = Paint()..color = color;
    for (var i = 0; i < counts.length; i++) {
      final height = size.height * counts[i] / maxCount;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * barWidth + 1,
            size.height - height,
            barWidth - 2,
            height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HourPainter oldDelegate) =>
      oldDelegate.counts != counts || oldDelegate.color != color;
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.data});

  final PeriodPerformance data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bestMonth = data.bestMonth;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              '周期表现',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _PeriodMetric(
                  value: '${data.longestPerfectStreak}',
                  label: '最长全勤',
                ),
                _PeriodMetric(value: '${data.longestGapDays}', label: '最长空窗'),
                _PeriodMetric(
                  value: bestMonth == null ? '—' : '${bestMonth.month}月',
                  label: '最佳月份',
                ),
                _PeriodMetric(value: '${data.averagePercent}%', label: '平均完成'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodMetric extends StatelessWidget {
  const _PeriodMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          LText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          LText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
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
