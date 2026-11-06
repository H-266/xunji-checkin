import '../core/app_strings.dart';
import '../core/app_motion.dart';

import 'package:flutter/material.dart';

import '../services/local_log_service.dart';
import '../widgets/l_text.dart';

/// 设置 → 错误日志：查看、导出、清空；不联网。
class ErrorLogScreen extends StatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  State<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends State<ErrorLogScreen> {
  String _content = '';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final content = await LocalLogService.read();
    if (!mounted) return;
    setState(() {
      _content = content;
      _loading = false;
    });
  }

  Future<void> _export() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final uri = await LocalLogService.export();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText(uri == null ? '暂无日志可导出' : '日志已保存')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText('导出失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText('清空日志？'),
        content: const LText('只删除本机错误日志，不影响任务与打卡记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LText('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalLogService.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LText('错误日志'),
        actions: [
          IconButton(
            tooltip: AppStrings.tr('导出'),
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: AppStrings.tr('清空'),
            onPressed: _busy ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _content.isEmpty
          ? const Center(child: LText('暂无错误日志'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _content,
                style: const TextStyle(fontFamily: 'monospace', height: 1.5),
              ),
            ),
    );
  }
}
