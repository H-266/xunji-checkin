import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import '../services/platform_service.dart';
import '../widgets/l_text.dart';

/// 自动备份设置：目录、周期、保留份数、立即执行。
///
/// 目录通过 SAF 选择并持久授权；不申请存储权限，也不会在后台偷偷运行。
class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  BackupConfig _config = BackupConfig.empty;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await BackupService.loadConfig();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  Future<void> _chooseDirectory() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final uri = await PlatformService.chooseBackupDirectory();
      if (uri == null) return;
      await BackupService.saveConfig(
        directoryUri: uri,
        frequencyDays: _config.frequencyDays == 0 ? 7 : _config.frequencyDays,
        keep: _config.keep,
      );
      await _load();
      messenger.showSnackBar(const SnackBar(content: LText('备份目录已保存')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: LText('选择目录失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setFrequency(int days) async {
    await BackupService.saveConfig(
      directoryUri: _config.directoryUri,
      frequencyDays: days,
      keep: _config.keep,
    );
    await _load();
  }

  Future<void> _setKeep(int keep) async {
    await BackupService.saveConfig(
      directoryUri: _config.directoryUri,
      frequencyDays: _config.frequencyDays,
      keep: keep,
    );
    await _load();
  }

  Future<void> _runNow() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsProvider>();
    setState(() => _busy = true);
    try {
      final result = await BackupService.runNow(settings);
      await _load();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: LText(
            '已备份 ${result.fileName}'
            '${result.deletedOld > 0 ? '，清理 ${result.deletedOld} 份旧文件' : ''}',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: LText('备份失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = _config.directoryUri != null && _config.frequencyDays > 0;
    return Scaffold(
      appBar: AppBar(title: const LText('自动备份')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LText(
                          '纯本地自动备份',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LText(
                          'App 启动或回到前台时检查周期，到期后写入你选定的目录；'
                          '只保留最近若干份，不会上传任何数据。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_outlined),
                          title: const LText('备份目录'),
                          subtitle: LText(
                            _config.directoryUri ?? '尚未选择，自动备份不会执行',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: TextButton(
                            onPressed: _busy ? null : _chooseDirectory,
                            child: const LText('选择'),
                          ),
                        ),
                        const Divider(height: 20),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule_rounded),
                          title: const LText('备份周期'),
                          subtitle: const LText('到期后仅在 App 运行时检查'),
                          trailing: DropdownButton<int>(
                            value: _config.frequencyDays == 0
                                ? 0
                                : _config.frequencyDays,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(value: 0, child: LText('关闭')),
                              DropdownMenuItem(value: 7, child: LText('每周')),
                              DropdownMenuItem(value: 14, child: LText('每两周')),
                              DropdownMenuItem(value: 30, child: LText('每月')),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => _setFrequency(value ?? 0),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: const LText('保留份数'),
                          subtitle: const LText('超出后删除最旧的自动备份'),
                          trailing: DropdownButton<int>(
                            value: _config.keep.clamp(3, 60),
                            underline: const SizedBox.shrink(),
                            items: const [5, 10, 20, 30]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: LText('$value 份'),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _busy
                                ? null
                                : (value) => _setKeep(value ?? 10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy || !enabled ? null : _runNow,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Icon(Icons.backup_outlined),
                            label: const LText('立即备份一次'),
                          ),
                        ),
                        if (!enabled) ...[
                          const SizedBox(height: 8),
                          LText(
                            '选择目录并把周期设为每周/每两周/每月后启用。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
