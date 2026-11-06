import '../core/app_strings.dart';
import '../core/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tag.dart';
import '../providers/task_provider.dart';
import '../widgets/l_text.dart';

/// 标签管理放在设置深处的二级页，避免主页面信息过载。
class TagManagementScreen extends StatelessWidget {
  const TagManagementScreen({super.key});

  Future<void> _edit(BuildContext context, {Tag? tag}) async {
    final provider = context.read<TaskProvider>();
    final controller = TextEditingController(text: tag?.name ?? '');
    var color = tag?.color ?? 0xFF3B6FD4;
    final name = await showAppDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: LText(tag == null ? '新建标签' : '重命名标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 12,
                decoration: InputDecoration(labelText: AppStrings.tr('标签名称')),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final value in const [
                    0xFF3B6FD4,
                    0xFF2E9E6B,
                    0xFFD4812E,
                    0xFFC94B57,
                    0xFF8A5BD6,
                    0xFF2A9DAE,
                  ])
                    InkWell(
                      onTap: () => setLocal(() => color = value),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(value),
                          shape: BoxShape.circle,
                          border: color == value
                              ? Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  width: 2,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const LText('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const LText('保存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      if (tag == null) {
        await provider.addTag(name, color: color);
      } else {
        await provider.renameTag(tag, name);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppStrings.tr('$error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tags = provider.allTags;
    return Scaffold(
      appBar: AppBar(title: const LText('标签管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_rounded),
        label: const LText('新建标签'),
      ),
      body: tags.isEmpty
          ? const Center(child: LText('还没有标签，新建一个给任务分类吧'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: tags.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tag = tags[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(tag.color),
                    ),
                    title: LText(tag.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: AppStrings.tr(tag.pinned ? '取消置顶' : '置顶标签'),
                          icon: Icon(
                            tag.pinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            color: tag.pinned
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          onPressed: () => provider.toggleTagPinned(tag),
                        ),
                        IconButton(
                          tooltip: AppStrings.tr('标签操作'),
                          icon: const Icon(Icons.more_horiz_rounded),
                          onPressed: () async {
                            final action = await showAppSheet<String>(
                              context: context,
                              showDragHandle: true,
                              builder: (sheetContext) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit_rounded),
                                      title: const LText('重命名'),
                                      onTap: () =>
                                          Navigator.pop(sheetContext, 'edit'),
                                    ),
                                    ListTile(
                                      leading: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Theme.of(sheetContext)
                                            .colorScheme
                                            .error,
                                      ),
                                      title: const LText('删除标签'),
                                      onTap: () =>
                                          Navigator.pop(sheetContext, 'delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (!context.mounted) return;
                            if (action == 'edit') {
                              _edit(context, tag: tag);
                            } else if (action == 'delete') {
                              _delete(context, tag);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _delete(BuildContext context, Tag tag) async {
    final provider = context.read<TaskProvider>();
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText('删除标签？'),
        content: const LText('标签会从所有任务上移除，任务本身与历史记录不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const LText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const LText('删除'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.deleteTag(tag);
  }
}
