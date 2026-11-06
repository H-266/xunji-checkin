import 'package:flutter/material.dart';

import '../widgets/l_text.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'privacy_policy_screen.dart';

/// 首次启动的隐私同意门。
///
/// 合规要点：
/// - 默认不勾选，必须用户主动勾选后才能继续；
/// - 提供完整政策入口；
/// - 拒绝时直接退出，不进入主界面、不初始化任何任务数据读取。
class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() => _saving = true);
    await context.read<SettingsProvider>().setPrivacyAccepted(true);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 52,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/brand/app_icon.png',
                        width: 56,
                        height: 56,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(height: 22),
                    LText(
                      '欢迎使用循记打卡',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LText(
                      '纯本地 · 全局热力打卡工具',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Point(
                      icon: Icons.wifi_off_rounded,
                      title: '完全离线',
                      body: '不联网、无账号、无云端同步、无广告；应用没有网络权限。',
                    ),
                    _Point(
                      icon: Icons.storage_rounded,
                      title: '数据只在本机',
                      body: '任务、打卡、备注、标签与设置保存在应用私有 SQLite；导出由你选择本地文件。',
                    ),
                    _Point(
                      icon: Icons.notifications_active_outlined,
                      title: '只申请通知权限',
                      body: '仅在你开启任务提醒时申请，用于本地到点提醒；拒绝不影响其他功能。',
                    ),
                    _Point(
                      icon: Icons.folder_outlined,
                      title: '文件访问走系统选择器',
                      body: '导入/导出/自动备份全程使用 Android SAF，不申请存储权限。',
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: (value) =>
                                setState(() => _agreed = value ?? false),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const LText('我已阅读并同意'),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const PrivacyPolicyScreen(),
                                      ),
                                    ),
                                    child: const LText('《隐私政策》'),
                                  ),
                                  const LText('，了解数据仅保存在本机。'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _agreed && !_saving ? _accept : null,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const LText('同意并继续'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => SystemNavigator.pop(),
                        child: const LText('暂不使用，退出'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: LText(
                        'Offline only · No collection · You own your data',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                LText(
                  body,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(height: 1.55, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
