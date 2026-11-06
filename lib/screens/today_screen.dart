import '../core/app_strings.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_motion.dart';
import '../core/date_utils.dart';
import '../core/onboarding_targets.dart';
import '../l10n/app_localizations.dart';
import '../core/stats.dart';
import '../models/tag.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../services/reminder_service.dart';
import '../widgets/progress_ring.dart';
import 'batch_manage_screen.dart';
import 'task_search_screen.dart';
import '../widgets/task_tile.dart';
import '../widgets/l_text.dart';

/// 今日打卡页。
///
/// 页面只负责交互与展示；完成率、跨天语义、周期规则全部由
/// TaskProvider + StatsCalculator 决定，避免出现第二套统计口径。
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final theme = Theme.of(context);

    if (provider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: LText(AppLocalizations.of(context).todayTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.loadError != null) {
      return Scaffold(
        appBar: AppBar(title: LText(AppLocalizations.of(context).todayTitle)),
        body: _ErrorView(
          message: provider.loadError!,
          onRetry: provider.reload,
        ),
      );
    }

    final today = provider.today;
    final daily = provider.visibleDailyTasks;
    final todos = provider.visibleTodoTasks;
    final dailyDone = daily.where(provider.isDailyDone).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const LText('今日打卡'),
        actions: [
          IconButton(
            tooltip: AppStrings.tr('更多'),
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _openMore(context),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Center(child: _OfflinePill()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _openSearch(context),
        // 整页使用 sliver 懒构建：100 条任务时只创建视口附近的行。
        // 每日任务的 ReorderableListView 仍需要参与拖拽，但外层不再
        // 用 ListView(children)，避免一次性构建所有卡片。
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  LText(
                    AppDateUtils.monthDayLabel(today),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  LText(
                    '${AppDateUtils.weekdayLabel(today)} · 把今天过好',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // 打卡只推动这个轻量信号：进度环局部重建，
                  // 不把整页任务列表一起 build。
                  ValueListenableBuilder<int>(
                    valueListenable: provider.checkinRevision,
                    builder: (context, _, child) => _ProgressPanel(
                      stat: provider.todayStat,
                      dailyDone: provider.dailyTasks
                          .where(provider.isDailyDone)
                          .length,
                      dailyTotal: provider.dailyTasks.length,
                      todoPending: provider.todoTasks.length,
                    ),
                  ),
                  if (provider.allTags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TagFilter(provider: provider),
                  ],
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: AppLocalizations.of(context).dailySection,
                    subtitle: '零点自动重置 · 长按拖动可排序',
                    trailing: '$dailyDone/${daily.length}',
                  ),
                  const SizedBox(height: 10),
                  if (daily.isEmpty)
                    _EmptyState(
                      icon: Icons.repeat_rounded,
                      title: provider.tagFilterId == null
                          ? AppLocalizations.of(context).emptyDaily
                          : '这个标签下没有打卡任务',
                      subtitle: '添加一件每天想坚持的小事',
                    ),
                ]),
              ),
            ),
            if (daily.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverReorderableList(
                  itemCount: daily.length,
                  proxyDecorator: (child, index, animation) {
                    if (MediaQuery.disableAnimationsOf(context)) return child;
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) => Transform.scale(
                        scale: 1 + 0.02 * animation.value,
                        child: Material(
                          elevation: 6 * animation.value,
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: child,
                        ),
                      ),
                    );
                  },
                  onReorderItem: (oldIndex, newIndex) {
                    final ordered = <Task>[...daily];
                    final moved = ordered.removeAt(oldIndex);
                    ordered.insert(newIndex, moved);
                    unawaited(provider.reorderVisibleDaily(ordered));
                  },
                  itemBuilder: (context, index) {
                    final task = daily[index];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey<String>('drag-${task.id}'),
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _swipe(
                          context,
                          provider,
                          task,
                          TaskTile(
                            task: task,
                            done: provider.isDailyDone(task),
                            doneListenable: provider.doneListenable(
                              task,
                              provider.isDailyDone(task),
                            ),
                            subtitle: _taskSubtitle(provider, task),
                            onToggle: () =>
                                _toggleDaily(context, provider, task),
                            onEdit: () =>
                                _openTaskMenu(context, provider, task),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: AppLocalizations.of(context).todoSection,
                      subtitle: AppStrings.tr('一次性任务 · 完成后从列表消失'),
                      trailing: AppStrings.tr('${todos.length} 项'),
                    ),
                    const SizedBox(height: 10),
                    if (todos.isEmpty)
                      _EmptyState(
                        icon: Icons.bolt_rounded,
                        title: AppLocalizations.of(context).emptyTodo,
                        subtitle: '想到什么就记下来，做完即消失',
                      ),
                  ],
                ),
              ),
            ),
            if (todos.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final task = todos[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _swipe(
                        context,
                        provider,
                        task,
                        TaskTile(
                          task: task,
                          done: false,
                          overdue: task.isOverdue,
                          subtitle: _taskSubtitle(provider, task),
                          onToggle: () =>
                              _completeTodo(context, provider, task),
                          onEdit: () => _openTaskMenu(context, provider, task),
                        ),
                      ),
                    );
                  }, childCount: todos.length),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 112)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: OnboardingTargets.todayFab,
        onPressed: () => _createTask(context),
        icon: const Icon(Icons.add_rounded),
        label: LText(AppLocalizations.of(context).addTask),
      ),
    );
  }

  String _taskSubtitle(TaskProvider provider, Task task) {
    final parts = <String>[];
    if (task.type == TaskType.daily) {
      parts.add(switch (task.schedule) {
        TaskSchedule.daily => AppStrings.tr('每日'),
        TaskSchedule.weeklyTarget => AppStrings.tr('每周 ${task.weeklyTarget} 次'),
        TaskSchedule.weekdays => _weekdaySummary(task.weekdayMask),
        TaskSchedule.intervalDays => AppStrings.tr('每 ${task.intervalDays} 天'),
        TaskSchedule.monthlyDays =>
          '每月 ${_monthDaySummary(task.monthDaysMask)}',
        TaskSchedule.yearlyDate =>
          '每年 ${task.yearlyMonth ?? 1} 月 ${task.yearlyDay ?? 1} 日',
      });
    } else {
      parts.add(AppStrings.tr('临时待办'));
      final due = task.dueDate;
      if (due != null) {
        parts.add(
          AppStrings.tr(
            task.isOverdue
                ? '已逾期 ${AppDateUtils.monthDayLabel(due)}'
                : '截止 ${AppDateUtils.monthDayLabel(due)}',
          ),
        );
      }
    }
    final tag = provider.tagFor(task.tagId);
    if (tag != null) parts.add(tag.name);
    if (task.reminderEnabled && task.reminderTime != null) {
      parts.add(AppStrings.tr('提醒 ${task.reminderTime}'));
    }
    if (task.isDaily && provider.isDailyDone(task)) {
      parts.add(AppStrings.tr('今日已完成'));
    }
    return parts.join(' · ');
  }

  String _weekdaySummary(int mask) {
    final selected = <String>[
      for (var i = 0; i < 7; i++)
        if ((mask & (1 << i)) != 0) AppStrings.weekdayShort(i),
    ];
    final joined = selected.join(AppStrings.isChinese ? '、' : ', ');
    return AppStrings.isChinese ? '周$joined' : joined;
  }

  String _monthDaySummary(int mask) {
    final selected = <String>[
      for (var i = 0; i < 31; i++)
        if ((mask & (1 << i)) != 0) '${i + 1}',
    ];
    return selected.isEmpty ? '未选择' : '${selected.join('、')} 日';
  }

  /// 左滑归档、右滑编辑；不直接删除条目，确认后由回调处理。
  Widget _swipe(
    BuildContext context,
    TaskProvider provider,
    Task task,
    Widget child,
  ) {
    return _SwipeRow(
      key: ValueKey<String>('swipe-${task.id}'),
      onEdit: () => _editTask(context, provider, task),
      onArchive: () => _archiveTask(context, provider, task),
      child: child,
    );
  }

  Future<void> _toggleDaily(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final wasDone = provider.isDailyDone(task);
    final wasPerfect = provider.todayStat.isPerfect;
    final haptics = context.read<SettingsProvider>().hapticsEnabled;
    try {
      await provider.toggleDaily(task);
      if (haptics) await HapticFeedback.lightImpact();
      if (!context.mounted) return;
      final nowPerfect = provider.todayStat.isPerfect;
      if (!wasDone && nowPerfect && provider.todayStat.total > 0) {
        if (haptics) await HapticFeedback.heavyImpact();
        if (!context.mounted) return;
      }
      if (!wasDone) {
        _showCheckedSnack(
          context,
          provider,
          task,
          perfect: !wasPerfect && nowPerfect,
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      _showPlainSnack(context, '打卡失败：$error');
    }
  }

  Future<void> _completeTodo(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final wasPerfect = provider.todayStat.isPerfect;
    final haptics = context.read<SettingsProvider>().hapticsEnabled;
    try {
      await provider.completeTodo(task);
      if (haptics) await HapticFeedback.mediumImpact();
      if (!context.mounted) return;
      final nowPerfect = provider.todayStat.isPerfect;
      _showTodoCompletedSnack(
        context,
        provider,
        task,
        perfect: !wasPerfect && nowPerfect && provider.todayStat.total > 0,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showPlainSnack(context, '完成失败：$error');
    }
  }

  /// 打卡后的轻提示：可顺手写备注，但不强制打断。
  void _showCheckedSnack(
    BuildContext context,
    TaskProvider provider,
    Task task, {
    required bool perfect,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final actionColor = Theme.of(context).colorScheme.inversePrimary;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Expanded(
              child: LText(perfect ? '今天全部完成，稳！' : '已打卡「${task.title}」'),
            ),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                _editRemark(context, provider, task);
              },
              style: TextButton.styleFrom(
                foregroundColor: actionColor,
                visualDensity: VisualDensity.compact,
              ),
              child: LText(AppLocalizations.of(context).writeRemark),
            ),
          ],
        ),
      ),
    );
  }

  void _showTodoCompletedSnack(
    BuildContext context,
    TaskProvider provider,
    Task task, {
    required bool perfect,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final undoColor = Theme.of(context).colorScheme.inversePrimary;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Expanded(
              child: LText(
                perfect ? '全部完成！已搞定「${task.title}」' : '已完成「${task.title}」',
              ),
            ),
            TextButton(
              onPressed: () async {
                messenger.hideCurrentSnackBar();
                try {
                  await provider.undoCompleteTodo(task);
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      content: LText('撤销失败：$error'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: undoColor,
                visualDensity: VisualDensity.compact,
              ),
              child: const LText('撤销'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    // 搜索是独立路由，必须显式带上当前页主题，否则会回落到根 MaterialApp 的
    // 系统主题，在深色 App 里出现一整页浅色搜索界面。
    final pageTheme = AppTheme.build(
      hue: context.read<SettingsProvider>().hue,
      brightness: Brightness.dark,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(data: pageTheme, child: const TaskSearchScreen()),
      ),
    );
  }

  Future<void> _openMore(BuildContext context) async {
    final selected = await showAppSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const LText('批量管理'),
              onTap: () => Navigator.pop(sheetContext, 'batch'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || selected != 'batch') return;
    _openBatch(context);
  }

  void _openBatch(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BatchManageScreen()));
  }

  void _showPlainSnack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(duration: const Duration(seconds: 2), content: LText(message)),
    );
  }

  Future<void> _createTask(BuildContext context) async {
    final provider = context.read<TaskProvider>();
    final settings = context.read<SettingsProvider>();
    final form = await showAppSheet<_TaskFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _TaskEditorSheet(
        availableTags: provider.allTags,
        initialType: settings.lastTaskType,
      ),
    );
    if (form == null || !context.mounted) return;

    try {
      if (form.reminderEnabled) {
        await ReminderService.ensurePermission();
      }
      await provider.addTask(
        title: form.title,
        type: form.type,
        schedule: form.schedule,
        weeklyTarget: form.weeklyTarget,
        weekdayMask: form.weekdayMask,
        intervalDays: form.intervalDays,
        monthDaysMask: form.monthDaysMask,
        yearlyMonth: form.yearlyMonth,
        yearlyDay: form.yearlyDay,
        tagId: form.tagId,
        reminderTime: form.reminderTime,
        reminderEnabled: form.reminderEnabled,
        reminderEffectiveOnly: form.reminderEffectiveOnly,
        dueDate: form.dueAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(form.dueAt!),
      );
      if (!context.mounted) return;
      await settings.setLastTaskType(form.type);
      if (!context.mounted) return;
      _showPlainSnack(context, '已添加「${form.title}」');
    } catch (error) {
      if (!context.mounted) return;
      _showPlainSnack(context, '添加失败：$error');
    }
  }

  Future<void> _openTaskMenu(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final action = await showAppSheet<_TaskAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: LText(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: LText(_taskSubtitle(provider, task)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.insights_rounded),
              title: LText(AppLocalizations.of(context).detailsStats),
              onTap: () => Navigator.pop(sheetContext, _TaskAction.detail),
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: LText(AppLocalizations.of(context).editTask),
              onTap: () => Navigator.pop(sheetContext, _TaskAction.edit),
            ),
            ListTile(
              leading: Icon(
                task.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
              ),
              title: LText(task.isPinned ? '取消置顶' : '置顶任务'),
              subtitle: const LText('置顶任务始终排在今日列表最前'),
              onTap: () => Navigator.pop(sheetContext, _TaskAction.pin),
            ),
            if (task.isDaily)
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: LText(AppLocalizations.of(context).backfill),
                subtitle: const LText('为过去某一天补上打卡'),
                onTap: () => Navigator.pop(sheetContext, _TaskAction.backfill),
              ),
            if (task.isTodo && task.isOverdue)
              ListTile(
                leading: const Icon(Icons.update_rounded),
                title: LText(AppLocalizations.of(context).postponeOneDay),
                onTap: () => Navigator.pop(sheetContext, _TaskAction.extend),
              ),
            ListTile(
              leading: Icon(
                Icons.archive_outlined,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: LText(
                AppLocalizations.of(sheetContext).archiveTask,
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              subtitle: const LText('保留历史，可在设置-回收站恢复'),
              onTap: () => Navigator.pop(sheetContext, _TaskAction.archive),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TaskAction.detail:
        await _openTaskDetail(context, provider, task);
      case _TaskAction.edit:
        await _editTask(context, provider, task);
      case _TaskAction.pin:
        try {
          await provider.togglePin(task);
          if (!context.mounted) return;
          _showPlainSnack(context, task.isPinned ? '已取消置顶' : '已置顶，刷新后排在最前');
        } catch (error) {
          if (!context.mounted) return;
          _showPlainSnack(context, '置顶失败：$error');
        }
      case _TaskAction.backfill:
        await _backfill(context, provider, task);
      case _TaskAction.extend:
        await _extendOverdue(context, provider, task);
      case _TaskAction.archive:
        await _archiveTask(context, provider, task);
    }
  }

  /// 历史补卡：只能选今天之前，已有记录则二次确认取消。
  Future<void> _backfill(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final created = task.createdDate;
    final first = DateTime(created.year, created.month, created.day);

    // 找到最近一个可补卡的生效日；没有则直接提示，避免日期选择器
    // 打开后所有日期都不可选。
    var initial = yesterday;
    var found = false;
    for (var i = 0; i < 1600 && !initial.isBefore(first); i++) {
      if (task.isScheduledOn(initial)) {
        found = true;
        break;
      }
      initial = DateTime(initial.year, initial.month, initial.day - 1);
    }
    if (!found) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: LText('该任务从创建至今没有可补卡的生效日')));
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: yesterday,
      selectableDayPredicate: task.isScheduledOn,
      helpText: AppStrings.tr('选择补卡日期'),
    );
    if (picked == null || !context.mounted) return;
    final already = provider.isDailyDone(task, date: picked);
    final controller = TextEditingController(
      text: provider.remarkFor(task.id, picked) ?? '',
    );
    final remark = await showAppDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: LText(
          already
              ? '取消 ${AppDateUtils.fullDateLabel(picked)} 的打卡？'
              : '补卡 ${AppDateUtils.fullDateLabel(picked)}',
        ),
        content: TextField(
          controller: controller,
          maxLength: 80,
          maxLines: 3,
          decoration: InputDecoration(hintText: AppStrings.tr('备注（可选）')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const LText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: LText(already ? '取消打卡' : '确认补卡'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (remark == null || !context.mounted) return;
    try {
      await provider.toggleDailyOn(
        task,
        picked,
        remark: already ? null : remark,
      );
      if (!context.mounted) return;
      _showPlainSnack(context, already ? '已取消该日打卡' : '补卡成功');
    } catch (error) {
      if (!context.mounted) return;
      _showPlainSnack(context, '补卡失败：$error');
    }
  }

  Future<void> _extendOverdue(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final due = task.dueDate;
    if (due == null) return;
    try {
      await provider.updateTask(
        task.copyWith(
          dueAt: DateTime(
            due.year,
            due.month,
            due.day,
          ).add(const Duration(days: 1)).millisecondsSinceEpoch,
        ),
      );
      if (!context.mounted) return;
      _showPlainSnack(context, '已延期一天');
    } catch (error) {
      if (!context.mounted) return;
      _showPlainSnack(context, '延期失败：$error');
    }
  }

  Future<void> _openTaskDetail(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _TaskDetailSheet(task: task),
    );
  }

  Future<void> _editTask(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final form = await showAppSheet<_TaskFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _TaskEditorSheet(task: task, availableTags: provider.allTags),
    );
    if (form == null || !context.mounted) return;
    try {
      if (form.reminderEnabled) {
        await ReminderService.ensurePermission();
      }
      await provider.updateTask(
        task.copyWith(
          title: form.title,
          type: form.type,
          schedule: form.schedule,
          weeklyTarget: form.weeklyTarget,
          weekdayMask: form.weekdayMask,
          intervalDays: form.intervalDays,
          monthDaysMask: form.monthDaysMask,
          yearlyMonth: form.yearlyMonth,
          yearlyDay: form.yearlyDay,
          tagId: form.tagId,
          reminderTime: form.reminderTime,
          reminderEnabled: form.reminderEnabled,
          reminderEffectiveOnly: form.reminderEffectiveOnly,
          dueAt: form.dueAt,
        ),
      );
      if (!context.mounted) return;
      _showPlainSnack(context, '已保存');
    } catch (error) {
      if (!context.mounted) return;
      _showPlainSnack(context, '保存失败：$error');
    }
  }

  Future<void> _editRemark(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final controller = TextEditingController(
      text: provider.remarkFor(task.id, provider.today) ?? '',
    );
    final remark = await showAppDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('打卡备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: AppStrings.tr('一句话记录今天，例如：状态不错'),
          ),
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
    if (remark == null || !context.mounted) return;
    try {
      await provider.setRemark(task, provider.today, remark);
      if (!context.mounted) return;
      _showPlainSnack(context, '备注已保存');
    } catch (error) {
      if (!context.mounted) return;
      _showPlainSnack(context, '保存备注失败：$error');
    }
  }

  Future<void> _archiveTask(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('归档这个任务？'),
        content: LText('「${task.title}」会从今日列表移除，历史记录仍会保留，可在回收站恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const LText('归档'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await provider.archiveTask(task);
      if (!context.mounted) return;
      _showPlainSnack(context, '已归档「${task.title}」');
    } catch (error) {
      if (!context.mounted) return;
      _showPlainSnack(context, '归档失败：$error');
    }
  }
}

// -----------------------------------------------------------------------------
// 页面组件
// -----------------------------------------------------------------------------

class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 13,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          LText(
            AppLocalizations.of(context).offline,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final DayStat stat;
  final int dailyDone;
  final int dailyTotal;
  final int todoPending;

  const _ProgressPanel({
    required this.stat,
    required this.dailyDone,
    required this.dailyTotal,
    required this.todoPending,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = stat.total;
    final isPerfect = stat.isPerfect;
    final headline = total == 0
        ? '从一件小事开始'
        : isPerfect
        ? '今天全部完成'
        : stat.rate >= 0.5
        ? '已经过半，继续'
        : '慢慢来，不着急';
    final subline = total == 0
        ? '今天还没有任务'
        : '已完成 ${stat.completed} 项 · 还剩 ${stat.remaining} 项';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.16),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: stat.rate,
            color: theme.colorScheme.primary,
            size: 98,
            strokeWidth: 8,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  headline,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                LText(
                  subline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniChip(label: '打卡 $dailyDone/$dailyTotal'),
                    _MiniChip(
                      label: todoPending == 0 ? '待办已清' : '$todoPending 项待办',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LText(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              LText(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        LText(
          trailing,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// 左右滑动手势：背景颜色/图标随位移连续变化，松手回弹。
/// 不用 Dismissible，因为它不暴露滑动进度，背景只能静态显示。
class _SwipeRow extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onEdit;
  final Future<void> Function() onArchive;

  const _SwipeRow({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dx = 0;
  double _from = 0;
  double _to = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          if (!mounted) return;
          setState(() => _dx = _from + (_to - _from) * _controller.value);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snap(double target) {
    _from = _dx;
    _to = target;
    if (_from == _to) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _snap(0);
    try {
      await action();
    } finally {
      if (mounted) _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = (_dx.abs() / 72).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        if (_busy || _controller.isAnimating) return;
        setState(() => _dx = (_dx + details.delta.dx).clamp(-110.0, 110.0));
      },
      onHorizontalDragEnd: (_) {
        if (_dx >= 64) {
          _run(widget.onEdit);
        } else if (_dx <= -64) {
          _run(widget.onArchive);
        } else {
          _snap(0);
        }
      },
      onHorizontalDragCancel: () => _snap(0),
      // 静止时直接返回原行，不创建 ClipRRect/Stack/背景层；
      // 勾选只重绘任务行，避免整行背景被反复裁剪。
      child: _dx == 0
          ? widget.child
          : ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: scheme.secondaryContainer.withValues(
                              alpha: 0.4 + 0.6 * progress,
                            ),
                            child: Opacity(
                              opacity: progress,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined, size: 20),
                                  SizedBox(width: 8),
                                  LText('编辑'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: scheme.errorContainer.withValues(
                              alpha: 0.4 + 0.6 * progress,
                            ),
                            child: Opacity(
                              opacity: progress,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LText(
                                    '归档',
                                    style: TextStyle(
                                      color: scheme.onErrorContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.archive_outlined,
                                    size: 20,
                                    color: scheme.onErrorContainer,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(_dx, 0),
                    child: widget.child,
                  ),
                ],
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.of(context, AppMotion.slow),
      curve: AppMotion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
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
      ),
    );
  }
}

class _TagFilter extends StatelessWidget {
  final TaskProvider provider;
  const _TagFilter({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: LText(AppLocalizations.of(context).allTags),
              selected: provider.tagFilterId == null,
              onSelected: (_) => provider.setTagFilter(null),
            ),
          ),
          for (final tag in provider.allTags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: LText(tag.name),
                selected: provider.tagFilterId == tag.id,
                onSelected: (_) => provider.setTagFilter(tag.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 12),
            LText(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onRetry(),
              child: const LText('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 任务详情
// -----------------------------------------------------------------------------

class _TaskDetailSheet extends StatefulWidget {
  final Task task;
  const _TaskDetailSheet({required this.task});

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  late final TextEditingController _remarkController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TaskProvider>();
    _remarkController = TextEditingController(
      text: provider.remarkFor(widget.task.id, provider.today) ?? '',
    );
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final theme = Theme.of(context);
    final task = provider.allTasks.firstWhere(
      (item) => item.id == widget.task.id,
      orElse: () => widget.task,
    );
    final stats = provider.taskStats(task);
    final done = task.isDaily && provider.isDailyDone(task);
    final tag = provider.tagFor(task.tagId);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              task.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            LText(
              [
                if (task.isDaily) task.schedule.label else '临时待办',
                if (tag != null) tag.name,
                if (task.reminderEnabled && task.reminderTime != null)
                  '提醒 ${task.reminderTime}',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (task.isDaily) ...[
              const SizedBox(height: 6),
              LText(
                '近期生效：${task.upcomingScheduleDates(from: provider.today, count: 4).map(AppDateUtils.monthDayLabel).join('、')}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (provider.completionAtFor(task, provider.today) != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: LText(
                      '完成于 ${AppDateUtils.fullDateLabel(provider.completionAtFor(task, provider.today)!)} '
                      '${AppDateUtils.timeLabel(provider.completionAtFor(task, provider.today)!)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.tr('修改完成时间'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final at = provider.completionAtFor(task, provider.today);
                      if (at == null) return;
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(at),
                        helpText: AppStrings.tr('修改完成时间'),
                      );
                      if (picked == null) return;
                      await provider.setCompletionTime(
                        task,
                        provider.today,
                        picked.hour,
                        picked.minute,
                      );
                    },
                    icon: const Icon(Icons.schedule_rounded, size: 20),
                  ),
                ],
              ),
            ],
            if (task.isDaily) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  _StatBox(label: '当前连击', value: '${stats.currentStreak} 天'),
                  const SizedBox(width: 8),
                  _StatBox(label: '最长连击', value: '${stats.longestStreak} 天'),
                  const SizedBox(width: 8),
                  _StatBox(label: '累计打卡', value: '${stats.totalDays} 天'),
                ],
              ),
              if (task.schedule == TaskSchedule.weeklyTarget) ...[
                const SizedBox(height: 10),
                LText(
                  '本周 ${stats.weeklyDone}/${stats.weeklyTarget} 次',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: stats.weeklyGoalReached
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 22),
            LText(
              '今日备注',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _remarkController,
              enabled: done,
              maxLength: 80,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: done ? '写一句今天的状态…' : '先完成打卡，再写备注',
                helperText: done ? null : '备注会跟随这条打卡记录保存',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: done
                        ? () async {
                            if (_saving) return;
                            setState(() => _saving = true);
                            try {
                              await provider.setRemark(
                                task,
                                provider.today,
                                _remarkController.text,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: LText('备注已保存'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          }
                        : null,
                    icon: const Icon(Icons.save_outlined),
                    label: LText(
                      _saving
                          ? '保存中…'
                          : AppLocalizations.of(context).saveRemark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded),
                    label: const LText('完成'),
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

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            LText(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            LText(
              label,
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

// -----------------------------------------------------------------------------
// 任务编辑器
// -----------------------------------------------------------------------------

class _TaskEditorSheet extends StatefulWidget {
  final Task? task;
  final List<Tag> availableTags;

  const _TaskEditorSheet({
    this.task,
    required this.availableTags,
    this.initialType = TaskType.daily,
  });

  final TaskType initialType;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _titleController;
  late TaskType _type;
  late TaskSchedule _schedule;
  late int _weeklyTarget;
  late int _weekdayMask;
  late int _intervalDays;
  late int _monthDaysMask;
  late int _yearlyMonth;
  late int _yearlyDay;
  int? _tagId;
  late List<Tag> _tags;
  bool _reminderEnabled = false;
  bool _reminderEffectiveOnly = false;
  TimeOfDay? _reminderTime;
  DateTime? _dueDate;
  String? _error;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _type = task?.type ?? widget.initialType;
    _schedule = task?.schedule ?? TaskSchedule.daily;
    _weeklyTarget = task?.weeklyTarget ?? 3;
    _weekdayMask = task?.weekdayMask ?? 0x7F;
    _intervalDays = task?.intervalDays ?? 2;
    _monthDaysMask = task?.monthDaysMask ?? 0x1;
    _yearlyMonth = task?.yearlyMonth ?? DateTime.now().month;
    _yearlyDay = task?.yearlyDay ?? DateTime.now().day;
    _tagId = task?.tagId;
    _tags = List<Tag>.of(widget.availableTags);
    _reminderEnabled = task?.reminderEnabled ?? false;
    _reminderEffectiveOnly = task?.reminderEffectiveOnly ?? false;
    _dueDate = task?.dueDate;
    if (task?.reminderTime != null) {
      final parts = task!.reminderTime!.split(':');
      if (parts.length == 2) {
        _reminderTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 20,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String get _timeText {
    final time = _reminderTime ?? const TimeOfDay(hour: 20, minute: 0);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _createTagInline() async {
    final provider = context.read<TaskProvider>();
    final controller = TextEditingController();
    final name = await showAppDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('新建标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: InputDecoration(labelText: AppStrings.tr('标签名称')),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const LText('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const LText('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final tag = await provider.addTag(name);
      if (!mounted) return;
      setState(() {
        _tags = [tag, ..._tags];
        _tagId = tag.id;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.tr('创建标签失败：$error'))));
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: AppStrings.tr('选择截止日期'),
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  String _scheduleText({
    required TaskSchedule schedule,
    required int weeklyTarget,
    required int weekdayMask,
    required int intervalDays,
    required int monthDaysMask,
    required int yearlyMonth,
    required int yearlyDay,
  }) {
    return switch (schedule) {
      TaskSchedule.daily => '每日',
      TaskSchedule.weeklyTarget => '每周 $weeklyTarget 天',
      TaskSchedule.weekdays => '每周${_weekdayText(weekdayMask)}',
      TaskSchedule.intervalDays => '每 $intervalDays 天',
      TaskSchedule.monthlyDays => '每月 ${_monthDaySummary(monthDaysMask)}',
      TaskSchedule.yearlyDate => '每年 $yearlyMonth 月 $yearlyDay 日',
    };
  }

  String _weekdayText(int mask) {
    final selected = <String>[
      for (var i = 0; i < 7; i++)
        if ((mask & (1 << i)) != 0) AppStrings.weekdayShort(i),
    ];
    return selected.isEmpty
        ? AppStrings.tr('无')
        : selected.join(AppStrings.isChinese ? '、' : ', ');
  }

  String _monthDaySummary(int mask) {
    final selected = <String>[
      for (var i = 0; i < 31; i++)
        if ((mask & (1 << i)) != 0) '${i + 1}',
    ];
    return selected.isEmpty ? '未选择' : '${selected.join('、')} 日';
  }

  Future<void> _openScheduleEditor() async {
    final result = await showAppSheet<_ScheduleConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ScheduleEditorSheet(
        schedule: _schedule,
        weeklyTarget: _weeklyTarget,
        weekdayMask: _weekdayMask,
        intervalDays: _intervalDays,
        monthDaysMask: _monthDaysMask,
        yearlyMonth: _yearlyMonth,
        yearlyDay: _yearlyDay,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _schedule = result.schedule;
      _weeklyTarget = result.weeklyTarget;
      _weekdayMask = result.weekdayMask;
      _intervalDays = result.intervalDays;
      _monthDaysMask = result.monthDaysMask;
      _yearlyMonth = result.yearlyMonth;
      _yearlyDay = result.yearlyDay;
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请输入任务名称');
      return;
    }
    if (_type == TaskType.daily &&
        _schedule == TaskSchedule.weekdays &&
        _weekdayMask == 0) {
      setState(() => _error = '至少选择一个生效星期');
      return;
    }
    if (_type == TaskType.daily &&
        _schedule == TaskSchedule.monthlyDays &&
        _monthDaysMask == 0) {
      setState(() => _error = '至少选择一个每月日期');
      return;
    }
    if (_type == TaskType.daily &&
        _schedule == TaskSchedule.intervalDays &&
        (_intervalDays < 1 || _intervalDays > 365)) {
      setState(() => _error = '间隔天数需在 1~365 之间');
      return;
    }
    if (_reminderEnabled && _reminderTime == null) {
      setState(() => _error = '请选择提醒时间');
      return;
    }
    Navigator.pop(
      context,
      _TaskFormResult(
        title: title,
        type: _type,
        schedule: _schedule,
        weeklyTarget: _weeklyTarget,
        weekdayMask: _weekdayMask,
        intervalDays: _intervalDays,
        monthDaysMask: _monthDaysMask,
        yearlyMonth: _yearlyMonth,
        yearlyDay: _yearlyDay,
        tagId: _tagId,
        reminderEnabled: _reminderEnabled,
        reminderEffectiveOnly: _reminderEffectiveOnly,
        reminderTime: _reminderEnabled ? _timeText : null,
        dueAt: _type == TaskType.todo ? _dueDate?.millisecondsSinceEpoch : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              _editing ? '编辑任务' : '新建任务',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            if (!_editing)
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<TaskType>(
                  segments: const [
                    ButtonSegment(value: TaskType.daily, label: LText('打卡任务')),
                    ButtonSegment(value: TaskType.todo, label: LText('临时待办')),
                  ],
                  selected: {_type},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) =>
                      setState(() => _type = values.first),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              autofocus: !_editing,
              maxLength: 30,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: AppStrings.tr('任务名称'),
                hintText: _type == TaskType.daily
                    ? '例如：喝水 / 阅读 20 分钟'
                    : '例如：交电费',
                errorText: _error,
              ),
            ),
            if (_type == TaskType.daily)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat_rounded),
                title: const LText('重复周期'),
                subtitle: LText(
                  _scheduleText(
                    schedule: _schedule,
                    weeklyTarget: _weeklyTarget,
                    weekdayMask: _weekdayMask,
                    intervalDays: _intervalDays,
                    monthDaysMask: _monthDaysMask,
                    yearlyMonth: _yearlyMonth,
                    yearlyDay: _yearlyDay,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openScheduleEditor,
              ),
            if (_type == TaskType.todo) ...[
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const LText('截止日期'),
                subtitle: LText(
                  _dueDate == null
                      ? '不设截止日'
                      : AppDateUtils.fullDateLabel(_dueDate!),
                ),
                trailing: _dueDate == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        tooltip: AppStrings.tr('清除截止日'),
                        onPressed: () => setState(() => _dueDate = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                onTap: _pickDueDate,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _tagId,
                    decoration: InputDecoration(labelText: AppStrings.tr('标签')),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: LText('无标签'),
                      ),
                      for (final tag in _tags)
                        DropdownMenuItem<int?>(
                          value: tag.id,
                          child: LText(tag.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _tagId = value),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: AppStrings.tr('新建标签'),
                  onPressed: _createTagInline,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const LText('定时提醒'),
              subtitle: LText(
                _reminderEnabled ? AppStrings.dailyAt(_timeText) : '到点发一条本地通知',
              ),
              value: _reminderEnabled,
              onChanged: (value) async {
                if (!value) {
                  setState(() => _reminderEnabled = false);
                  return;
                }
                final time = await showTimePicker(
                  context: context,
                  initialTime:
                      _reminderTime ?? const TimeOfDay(hour: 20, minute: 0),
                );
                if (time == null) return;
                setState(() {
                  _reminderEnabled = true;
                  _reminderTime = time;
                });
              },
            ),
            if (_reminderEnabled &&
                _type == TaskType.daily &&
                _schedule != TaskSchedule.daily)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LText('仅在生效日提醒'),
                subtitle: const LText('非生效日不发通知'),
                value: _reminderEffectiveOnly,
                onChanged: (value) =>
                    setState(() => _reminderEffectiveOnly = value),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: LText(_editing ? '保存修改' : '添加任务'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFormResult {
  final String title;
  final TaskType type;
  final TaskSchedule schedule;
  final int weeklyTarget;
  final int weekdayMask;
  final int intervalDays;
  final int monthDaysMask;
  final int yearlyMonth;
  final int yearlyDay;
  final int? tagId;
  final bool reminderEnabled;
  final bool reminderEffectiveOnly;
  final String? reminderTime;
  final int? dueAt;

  const _TaskFormResult({
    required this.title,
    required this.type,
    required this.schedule,
    required this.weeklyTarget,
    required this.weekdayMask,
    required this.intervalDays,
    required this.monthDaysMask,
    required this.yearlyMonth,
    required this.yearlyDay,
    required this.tagId,
    required this.reminderEnabled,
    required this.reminderEffectiveOnly,
    required this.reminderTime,
    required this.dueAt,
  });
}

class _ScheduleConfig {
  final TaskSchedule schedule;
  final int weeklyTarget;
  final int weekdayMask;
  final int intervalDays;
  final int monthDaysMask;
  final int yearlyMonth;
  final int yearlyDay;

  const _ScheduleConfig({
    required this.schedule,
    required this.weeklyTarget,
    required this.weekdayMask,
    required this.intervalDays,
    required this.monthDaysMask,
    required this.yearlyMonth,
    required this.yearlyDay,
  });
}

/// 周期配置放在二级面板，避免主编辑页被大量选项撑开。
class _ScheduleEditorSheet extends StatefulWidget {
  final TaskSchedule schedule;
  final int weeklyTarget;
  final int weekdayMask;
  final int intervalDays;
  final int monthDaysMask;
  final int yearlyMonth;
  final int yearlyDay;

  const _ScheduleEditorSheet({
    required this.schedule,
    required this.weeklyTarget,
    required this.weekdayMask,
    required this.intervalDays,
    required this.monthDaysMask,
    required this.yearlyMonth,
    required this.yearlyDay,
  });

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  late TaskSchedule _schedule;
  late int _weeklyTarget;
  late int _weekdayMask;
  late int _intervalDays;
  late int _monthDaysMask;
  late int _yearlyMonth;
  late int _yearlyDay;
  late final TextEditingController _intervalController;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
    _weeklyTarget = widget.weeklyTarget;
    _weekdayMask = widget.weekdayMask;
    _intervalDays = widget.intervalDays;
    _monthDaysMask = widget.monthDaysMask;
    _yearlyMonth = widget.yearlyMonth;
    _yearlyDay = widget.yearlyDay;
    _intervalController = TextEditingController(text: '$_intervalDays');
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    setState(() {
      switch (preset) {
        case '隔天':
          _schedule = TaskSchedule.intervalDays;
          _intervalDays = 2;
        case '工作日':
          _schedule = TaskSchedule.weekdays;
          _weekdayMask = 0x1F;
        case '每月 1 号':
          _schedule = TaskSchedule.monthlyDays;
          _monthDaysMask = 1;
        case '每年今天':
          final now = DateTime.now();
          _schedule = TaskSchedule.yearlyDate;
          _yearlyMonth = now.month;
          _yearlyDay = now.day;
      }
      _intervalController.text = '$_intervalDays';
    });
  }

  void _confirm() {
    if (_schedule == TaskSchedule.intervalDays) {
      final parsed = int.tryParse(_intervalController.text.trim());
      if (parsed == null || parsed < 1 || parsed > 365) return;
      _intervalDays = parsed;
    }
    Navigator.pop(
      context,
      _ScheduleConfig(
        schedule: _schedule,
        weeklyTarget: _weeklyTarget,
        weekdayMask: _weekdayMask,
        intervalDays: _intervalDays,
        monthDaysMask: _monthDaysMask,
        yearlyMonth: _yearlyMonth,
        yearlyDay: _yearlyDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxDay = DateTime(2024, _yearlyMonth, 0).day;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              '重复周期',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            LText(
              '非生效日不会计入当天任务总数，也不会拉低完成率。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in const ['隔天', '工作日', '每月 1 号', '每年今天'])
                  ActionChip(
                    label: LText(preset),
                    onPressed: () => _applyPreset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskSchedule>(
              initialValue: _schedule,
              decoration: InputDecoration(labelText: AppStrings.tr('周期类型')),
              items: const [
                DropdownMenuItem(
                  value: TaskSchedule.daily,
                  child: LText('每日打卡'),
                ),
                DropdownMenuItem(
                  value: TaskSchedule.weeklyTarget,
                  child: LText('每周目标'),
                ),
                DropdownMenuItem(
                  value: TaskSchedule.weekdays,
                  child: LText('自定义星期'),
                ),
                DropdownMenuItem(
                  value: TaskSchedule.intervalDays,
                  child: LText('间隔天数'),
                ),
                DropdownMenuItem(
                  value: TaskSchedule.monthlyDays,
                  child: LText('每月固定日期'),
                ),
                DropdownMenuItem(
                  value: TaskSchedule.yearlyDate,
                  child: LText('每年固定日期'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _schedule = value);
              },
            ),
            const SizedBox(height: 14),
            if (_schedule == TaskSchedule.weeklyTarget)
              Row(
                children: [
                  const LText('每周目标'),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _weeklyTarget,
                    items: [
                      for (var i = 1; i <= 7; i++)
                        DropdownMenuItem(value: i, child: LText('$i 天')),
                    ],
                    onChanged: (value) =>
                        setState(() => _weeklyTarget = value ?? 3),
                  ),
                ],
              ),
            if (_schedule == TaskSchedule.weekdays)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: LText(AppStrings.weekdayShort(i)),
                      selected: (_weekdayMask & (1 << i)) != 0,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _weekdayMask |= 1 << i;
                          } else {
                            _weekdayMask &= ~(1 << i);
                          }
                        });
                      },
                    ),
                ],
              ),
            if (_schedule == TaskSchedule.intervalDays)
              TextField(
                controller: _intervalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('每隔几天'),
                  suffixText: '天',
                  helperText: AppStrings.tr('从任务创建日开始循环，填写 1~365'),
                ),
              ),
            if (_schedule == TaskSchedule.monthlyDays)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var day = 1; day <= 31; day++)
                    FilterChip(
                      label: LText('$day'),
                      selected: (_monthDaysMask & (1 << (day - 1))) != 0,
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _monthDaysMask |= 1 << (day - 1);
                          } else {
                            _monthDaysMask &= ~(1 << (day - 1));
                          }
                        });
                      },
                    ),
                ],
              ),
            if (_schedule == TaskSchedule.yearlyDate)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _yearlyMonth,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('月'),
                      ),
                      items: [
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem(
                            value: month,
                            child: LText('$month 月'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _yearlyMonth = value;
                          final limit = DateTime(2024, value, 0).day;
                          if (_yearlyDay > limit) _yearlyDay = limit;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _yearlyDay.clamp(1, maxDay),
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('日'),
                      ),
                      items: [
                        for (var day = 1; day <= maxDay; day++)
                          DropdownMenuItem(value: day, child: LText('$day 日')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _yearlyDay = value);
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _confirm,
                child: const LText('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TaskAction { detail, edit, pin, backfill, extend, archive }
