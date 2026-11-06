import '../core/app_strings.dart';
import '../core/app_motion.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tag.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/reminder_service.dart';
import '../widgets/l_text.dart';

/// 批量管理：多选后归档 / 换标签 / 设提醒 / 切周期。
///
/// 入口藏在今日页右上角，不占主界面空间；所有写操作走 Provider 事务。
class BatchManageScreen extends StatefulWidget {
  const BatchManageScreen({super.key});

  @override
  State<BatchManageScreen> createState() => _BatchManageScreenState();
}

class _BatchManageScreenState extends State<BatchManageScreen> {
  final Set<int> _selected = <int>{};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = provider.allTasks
        .where((task) => !task.isArchived)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: LText(
          _selected.isEmpty
              ? '批量管理'
              : AppStrings.selectedCount(_selected.length),
        ),
        actions: [
          TextButton(
            onPressed: tasks.isEmpty
                ? null
                : () => setState(() {
                    if (_selected.length == tasks.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(tasks.map((task) => task.id!));
                    }
                  }),
            child: LText(_selected.length == tasks.length ? '取消全选' : '全选'),
          ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: LText('没有可管理的任务'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final id = task.id!;
                return CheckboxListTile(
                  value: _selected.contains(id),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _selected.add(id);
                    } else {
                      _selected.remove(id);
                    }
                  }),
                  title: LText(task.title),
                  subtitle: LText(
                    task.isDaily
                        ? '${task.schedule.label} · ${provider.tagFor(task.tagId)?.name ?? '无标签'}'
                        : '临时待办 · ${provider.tagFor(task.tagId)?.name ?? '无标签'}',
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: _busy
            ? const LinearProgressIndicator()
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BatchAction(
                    icon: Icons.archive_outlined,
                    label: '归档',
                    onTap: _selected.isEmpty ? null : _archive,
                  ),
                  _BatchAction(
                    icon: Icons.sell_outlined,
                    label: '标签',
                    onTap: _selected.isEmpty ? null : _setTag,
                  ),
                  _BatchAction(
                    icon: Icons.alarm_outlined,
                    label: '提醒',
                    onTap: _selected.isEmpty ? null : _setReminder,
                  ),
                  _BatchAction(
                    icon: Icons.event_repeat_rounded,
                    label: '周期',
                    onTap: _selected.isEmpty ? null : _setSchedule,
                  ),
                ],
              ),
      ),
    );
  }

  List<Task> get _tasks {
    final provider = context.read<TaskProvider>();
    return provider.allTasks
        .where((task) => _selected.contains(task.id))
        .toList(growable: false);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: LText('批量操作失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: LText('归档 ${_selected.length} 个任务？'),
        content: const LText('历史打卡会保留，可在设置-归档回收站恢复。'),
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
    if (ok != true) return;
    final tasks = _tasks;
    await _run(() => context.read<TaskProvider>().batchArchiveTasks(tasks));
  }

  Future<void> _setTag() async {
    final provider = context.read<TaskProvider>();
    final tag = await showAppSheet<Tag?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.label_off_outlined),
              title: const LText('清除标签'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            for (final tag in provider.allTags)
              ListTile(
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: Color(tag.color),
                ),
                title: LText(tag.name),
                onTap: () => Navigator.pop(sheetContext, tag),
              ),
          ],
        ),
      ),
    );
    if (tag == null || !mounted) return;
    final updated = _tasks
        .map((task) => task.copyWith(tagId: tag.id))
        .toList(growable: false);
    await _run(() => provider.batchUpdateTasks(updated));
  }

  Future<void> _setReminder() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (time == null || !mounted) return;
    final allowed = await ReminderService.ensurePermission();
    if (!allowed) return;
    final text =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final updated = _tasks
        .map(
          (task) => task.copyWith(
            reminderTime: text,
            reminderEnabled: true,
            reminderEffectiveOnly: true,
          ),
        )
        .toList(growable: false);
    await _run(() => context.read<TaskProvider>().batchUpdateTasks(updated));
  }

  Future<void> _setSchedule() async {
    var schedule = TaskSchedule.daily;
    var target = 3;
    var mask = 0x1F;
    var interval = 2;
    var monthMask = 0x1;
    var yearMonth = 1;
    var yearDay = 1;
    final result = await showAppSheet<_BatchScheduleResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  '切换周期',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskSchedule>(
                  initialValue: schedule,
                  decoration: InputDecoration(labelText: AppStrings.tr('周期类型')),
                  items: [
                    for (final item in TaskSchedule.values)
                      DropdownMenuItem(value: item, child: LText(item.label)),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => schedule = value ?? schedule),
                ),
                if (schedule == TaskSchedule.weeklyTarget) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const LText('每周目标'),
                      const Spacer(),
                      DropdownButton<int>(
                        value: target,
                        items: [
                          for (var i = 1; i <= 7; i++)
                            DropdownMenuItem(value: i, child: LText('$i 天')),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => target = value ?? 3),
                      ),
                    ],
                  ),
                ],
                if (schedule == TaskSchedule.weekdays) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var i = 0; i < 7; i++)
                        FilterChip(
                          label: LText(AppStrings.weekdayShort(i)),
                          selected: (mask & (1 << i)) != 0,
                          onSelected: (selected) => setSheetState(() {
                            if (selected) {
                              mask |= 1 << i;
                            } else {
                              mask &= ~(1 << i);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                if (schedule == TaskSchedule.intervalDays) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: '$interval',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('间隔天数'),
                      helperText: AppStrings.tr('从任务创建日起，每 N 天生效一次（1–365）'),
                    ),
                    onChanged: (value) => interval =
                        int.tryParse(value)?.clamp(1, 365) ?? interval,
                  ),
                ],
                if (schedule == TaskSchedule.monthlyDays) ...[
                  const SizedBox(height: 12),
                  const LText('每月生效日期（可多选）'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (var day = 1; day <= 31; day++)
                        FilterChip(
                          label: LText('$day'),
                          selected: (monthMask & (1 << (day - 1))) != 0,
                          onSelected: (selected) => setSheetState(() {
                            if (selected) {
                              monthMask |= 1 << (day - 1);
                            } else {
                              monthMask &= ~(1 << (day - 1));
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                if (schedule == TaskSchedule.yearlyDate) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: yearMonth,
                          decoration: InputDecoration(
                            labelText: AppStrings.tr('月'),
                          ),
                          items: [
                            for (var i = 1; i <= 12; i++)
                              DropdownMenuItem(value: i, child: LText('$i 月')),
                          ],
                          onChanged: (value) => setSheetState(() {
                            yearMonth = value ?? 1;
                            yearDay = yearDay.clamp(1, _daysInMonth(yearMonth));
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: yearDay,
                          decoration: InputDecoration(
                            labelText: AppStrings.tr('日'),
                          ),
                          items: [
                            for (var i = 1; i <= _daysInMonth(yearMonth); i++)
                              DropdownMenuItem(value: i, child: LText('$i 日')),
                          ],
                          onChanged: (value) =>
                              setSheetState(() => yearDay = value ?? 1),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _BatchScheduleResult(
                        schedule: schedule,
                        weeklyTarget: target,
                        weekdayMask: mask,
                        intervalDays: interval.clamp(1, 365),
                        monthDaysMask: monthMask,
                        yearlyMonth: yearMonth,
                        yearlyDay: yearDay,
                      ),
                    ),
                    child: const LText('应用到所选任务'),
                  ),
                ),
                if (schedule == TaskSchedule.weekdays && mask == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LText('至少选择一个生效星期'),
                  ),
                if (schedule == TaskSchedule.monthlyDays && monthMask == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LText('至少选择一个生效日期'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.schedule == TaskSchedule.weekdays && result.weekdayMask == 0) {
      return;
    }
    if (result.schedule == TaskSchedule.monthlyDays &&
        result.monthDaysMask == 0) {
      return;
    }
    final updated = _tasks
        .map(
          (task) => task.copyWith(
            schedule: result.schedule,
            weeklyTarget: result.weeklyTarget,
            weekdayMask: result.weekdayMask,
            intervalDays: result.intervalDays,
            monthDaysMask: result.monthDaysMask,
            yearlyMonth: result.yearlyMonth,
            yearlyDay: result.yearlyDay,
          ),
        )
        .toList(growable: false);
    await _run(() => context.read<TaskProvider>().batchUpdateTasks(updated));
  }

  static int _daysInMonth(int month) {
    return DateTime(2024, month + 1, 0).day;
  }
}

class _BatchScheduleResult {
  const _BatchScheduleResult({
    required this.schedule,
    required this.weeklyTarget,
    required this.weekdayMask,
    required this.intervalDays,
    required this.monthDaysMask,
    required this.yearlyMonth,
    required this.yearlyDay,
  });

  final TaskSchedule schedule;
  final int weeklyTarget;
  final int weekdayMask;
  final int intervalDays;
  final int monthDaysMask;
  final int yearlyMonth;
  final int yearlyDay;
}

class _BatchAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _BatchAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: LText(label),
    );
  }
}
