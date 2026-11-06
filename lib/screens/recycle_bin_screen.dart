import '../core/app_strings.dart';
import '../core/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/l_text.dart';

/// 归档任务回收站：支持单条/批量恢复与永久删除。
class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  final Set<int> _selected = <int>{};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = provider.archivedTasks;
    final selecting = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: LText(
          selecting ? AppStrings.selectedCount(_selected.length) : '归档回收站',
        ),
        leading: selecting
            ? IconButton(
                tooltip: AppStrings.tr('退出多选'),
                onPressed: () => setState(_selected.clear),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        actions: selecting
            ? [
                IconButton(
                  tooltip: AppStrings.tr('批量恢复'),
                  onPressed: _busy ? null : () => _restore(provider),
                  icon: const Icon(Icons.restore_rounded),
                ),
                IconButton(
                  tooltip: AppStrings.tr('批量永久删除'),
                  onPressed: _busy ? null : () => _deleteSelected(provider),
                  icon: const Icon(Icons.delete_forever_rounded),
                ),
              ]
            : tasks.isEmpty
            ? null
            : [
                TextButton(
                  onPressed: () => setState(
                    () => _selected.addAll(
                      tasks.map((task) => task.id).whereType<int>(),
                    ),
                  ),
                  child: const LText('全选'),
                ),
              ],
      ),
      body: tasks.isEmpty
          ? const Center(child: LText('没有已归档的任务'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                final id = task.id;
                final checked = id != null && _selected.contains(id);
                return Card(
                  child: ListTile(
                    selected: checked,
                    leading: selecting
                        ? Checkbox(
                            value: checked,
                            onChanged: (_) => _toggle(task),
                          )
                        : null,
                    onLongPress: () => _toggle(task),
                    onTap: selecting ? () => _toggle(task) : null,
                    title: LText(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: LText(task.isTodo ? '临时待办 · 已归档' : '打卡任务 · 已归档'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: AppStrings.tr('恢复'),
                          onPressed: () => provider.restoreTask(task),
                          icon: const Icon(Icons.restore_rounded),
                        ),
                        IconButton(
                          tooltip: AppStrings.tr('永久删除'),
                          onPressed: () =>
                              _deleteForever(context, provider, task),
                          icon: const Icon(Icons.delete_forever_rounded),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _toggle(Task task) {
    final id = task.id;
    if (id == null) return;
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Future<void> _restore(TaskProvider provider) async {
    setState(() => _busy = true);
    try {
      await provider.batchRestoreTasks(_selected.toList(growable: false));
      if (mounted) setState(_selected.clear);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSelected(TaskProvider provider) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: LText('永久删除 ${_selected.length} 项？'),
        content: const LText('任务和全部打卡记录都会被删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LText('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const LText('永久删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await provider.batchDeleteTasksPermanently(
        _selected.toList(growable: false),
      );
      if (mounted) setState(_selected.clear);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteForever(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText('永久删除？'),
        content: const LText('任务和它的全部打卡记录都会被删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const LText('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const LText('永久删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await provider.deleteTaskPermanently(task);
      if (mounted && task.id != null) _selected.remove(task.id);
    }
  }
}
