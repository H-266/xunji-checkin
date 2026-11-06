import '../core/app_strings.dart';
import '../core/app_motion.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/l_text.dart';

/// 全局任务搜索。
///
/// 只搜索未归档任务，不占用今日页空间；结果可直接打卡或看详情。
class _SearchResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onDetail;

  const _SearchResultTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onToggle,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: Material(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 68,
                  child: Checkbox(
                    value: done,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onChanged: (_) => onToggle(),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      LText(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.tr('详情'),
                  onPressed: onDetail,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskSearchScreen extends StatefulWidget {
  const TaskSearchScreen({super.key});

  @override
  State<TaskSearchScreen> createState() => _TaskSearchScreenState();
}

class _TaskSearchScreenState extends State<TaskSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    // 输入期间不立刻重建整页结果；停 120ms 再过滤。
    if (value.trim().isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final results = provider
        .searchTasks(_query)
        .take(80)
        .toList(growable: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: AppStrings.tr('搜索任务标题…'),
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: AppStrings.tr('清空'),
              onPressed: () {
                _debounce?.cancel();
                _controller.clear();
                setState(() => _query = '');
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: _query.trim().isEmpty
          ? Center(
              child: LText(
                '输入关键词，搜索所有未归档任务',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : results.isEmpty
          ? const Center(child: LText('没有找到匹配的任务'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final task = results[index];
                final done = task.isDaily
                    ? provider.isDailyDone(task)
                    : task.completedAt != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SearchResultTile(
                    key: ValueKey(task.id),
                    title: task.title,
                    subtitle: '${task.type.label} · ${_scheduleText(task)}',
                    done: done,
                    onToggle: () => unawaited(_toggle(context, provider, task)),
                    onDetail: () => _showDetail(context, provider, task),
                  ),
                );
              },
            ),
    );
  }

  String _scheduleText(Task task) {
    if (task.isTodo) {
      final due = task.dueDate;
      return due == null ? '无截止日' : '截止 ${AppDateUtils.monthDayLabel(due)}';
    }
    return task.schedule.label;
  }

  Future<void> _toggle(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    try {
      if (task.isDaily) {
        await provider.toggleDaily(task);
      } else if (task.completedAt == null) {
        await provider.completeTodo(task);
      } else {
        await provider.undoCompleteTodo(task);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: LText('操作失败：$error')));
    }
  }

  void _showDetail(BuildContext context, TaskProvider provider, Task task) {
    final stats = task.isDaily ? provider.taskStats(task) : null;
    showAppSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText(
                task.title,
                style: Theme.of(sheetContext).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              LText(_scheduleText(task)),
              if (stats != null) ...[
                const SizedBox(height: 16),
                LText('当前连续 ${stats.currentStreak} 天'),
                LText('最长连续 ${stats.longestStreak} 天'),
                LText('累计打卡 ${stats.totalDays} 天'),
              ],
              if (task.isTodo && task.dueDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LText(
                    task.isOverdue
                        ? '已逾期，可在任务菜单延期或归档'
                        : '截止日期 ${AppDateUtils.monthDayLabel(task.dueDate!)}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
