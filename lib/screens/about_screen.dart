import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_strings.dart';
import '../core/feature_flags.dart';
import '../services/platform_service.dart';

/// 关于页：开发者简介 + GitHub 引导；仅中文语系显示赞赏板块。
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.scrollToSupport = false});

  final bool scrollToSupport;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final GlobalKey _supportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!widget.scrollToSupport) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      final target = _supportKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    });
  }

  bool get _showSupport {
    return Localizations.localeOf(context).languageCode == 'zh';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final copy = AboutCopy.of(AppStrings.languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(copy.appName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/brand/app_icon.png',
                  width: 72,
                  height: 72,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.appName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.tagline,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            copy.developerHeading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              copy.developerBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              leading: const Icon(Icons.code_rounded),
              title: Text(copy.projectHeading),
              subtitle: Text(
                projectUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.copy_rounded, size: 20),
              onTap: () async {
                await Clipboard.setData(const ClipboardData(text: projectUrl));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(copy.linkCopied)));
              },
            ),
          ),
          const SizedBox(height: 28),
          Text(
            copy.contactHeading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _ContactTile(
                  label: copy.qqLabel,
                  email: contactEmailQq,
                  onTap: () => _openEmail(context, copy, contactEmailQq),
                  onCopy: () => _copyEmail(context, copy, contactEmailQq),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
                _ContactTile(
                  label: copy.outlookLabel,
                  email: contactEmailOutlook,
                  onTap: () => _openEmail(context, copy, contactEmailOutlook),
                  onCopy: () => _copyEmail(context, copy, contactEmailOutlook),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.contactHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (_showSupport) ...[
            const SizedBox(height: 28),
            Container(
              key: _supportKey,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_outline_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '支持项目',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '如果循记打卡帮到了你，欢迎用微信或支付宝赞赏支持我持续更新。'
                    '赞赏完全自愿，不影响任何功能。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PayCard(
                          asset: 'assets/support/wechat_pay.png',
                          label: '微信赞赏',
                          onTap: () => _showQr(
                            context,
                            'assets/support/wechat_pay.png',
                            '微信赞赏',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PayCard(
                          asset: 'assets/support/alipay_pay.jpg',
                          label: '支付宝赞赏',
                          onTap: () => _showQr(
                            context,
                            'assets/support/alipay_pay.jpg',
                            '支付宝赞赏',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '点击收款码可放大查看；赞赏纯属自愿。',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Center(
            child: Text(
              'MIT License · No network · No account',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEmail(
    BuildContext context,
    AboutCopy copy,
    String email,
  ) async {
    final opened = await PlatformService.openEmail(email);
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(copy.mailUnavailable)));
  }

  Future<void> _copyEmail(
    BuildContext context,
    AboutCopy copy,
    String email,
  ) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(email)));
  }

  void _showQr(BuildContext context, String asset, String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF0B1220),
        insetPadding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.label,
    required this.email,
    required this.onTap,
    required this.onCopy,
  });

  final String label;
  final String email;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Icons.alternate_email_rounded),
      title: Text(label),
      subtitle: Text(
        email,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy_rounded, size: 20),
        onPressed: onCopy,
      ),
      onTap: onTap,
      onLongPress: onCopy,
    );
  }
}

class _PayCard extends StatelessWidget {
  const _PayCard({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
