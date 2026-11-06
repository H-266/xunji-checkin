import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_strings.dart';
import '../providers/settings_provider.dart';
import 'about_screen.dart';

/// 累计启动赞赏弹窗。
///
/// 只有当前界面语言为中文（简体或繁体）、达到本地计数阈值、未永久关闭，
/// 才会构建对话框。外文环境连这个方法都不会走到。
class SupportPrompt {
  const SupportPrompt._();

  static Future<void> maybeShow(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.supportVisible) return;
    if (Localizations.localeOf(context).languageCode != 'zh') return;
    if (!settings.shouldShowSupportPrompt) return;

    var noMore = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.tr('感谢使用循记打卡')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.tr(
                  '你已经累计启动20次啦。这个项目是我14岁独立开发的免费工具，'
                  '无广告无内购。如果觉得好用，欢迎赞赏支持我持续更新~',
                ),
                style: const TextStyle(height: 1.55),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: noMore,
                onChanged: (value) =>
                    setDialogState(() => noMore = value ?? false),
                title: Text(AppStrings.tr('不再提示')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (noMore) await settings.disableSupportPrompt();
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                await settings.deferSupportPrompt();
              },
              child: Text(AppStrings.tr('下次再说')),
            ),
            FilledButton(
              onPressed: () async {
                if (noMore) await settings.disableSupportPrompt();
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutScreen(scrollToSupport: true),
                  ),
                );
              },
              child: Text(AppStrings.tr('去看看')),
            ),
          ],
        ),
      ),
    );
  }
}
