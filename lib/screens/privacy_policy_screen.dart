import 'package:flutter/material.dart';

import '../widgets/l_text.dart';

/// 隐私政策与权限说明。
///
/// 本页内容同时保留中英文全文，方便应用商店审核与开源仓库核对；
/// 不依赖网络，也不从远端加载任何政策文本。
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const LText('隐私政策 · Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            LText(
              '更新日期：2026-11-06　版本：1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _Section(
              title: '一、我们收集什么',
              body:
                  '循记打卡是纯离线工具。我们不收集、不上传、不出售任何个人信息；'
                  '没有账号系统、没有云端同步、没有广告 SDK、没有统计分析 SDK，'
                  '应用也没有申请网络权限。',
            ),
            _Section(
              title: '二、数据保存在哪里',
              body:
                  '任务、打卡、备注、标签、设置与自动备份索引全部保存在本机应用私有目录的 SQLite 数据库中。'
                  '只有你主动使用系统文件选择器导出时，数据才会写入你指定的本地文件；'
                  '自动备份也只写入你通过系统文件选择器授权的目录。',
            ),
            _Section(
              title: '三、权限与用途',
              body:
                  '通知权限（POST_NOTIFICATIONS）：仅在你为任务开启提醒时申请，用于本地打卡提醒。'
                  '拒绝后应用将退出，不会读取任务数据。\n'
                  '文件访问：全部通过 Android 系统文件选择器（SAF）完成，不申请存储权限。\n'
                  '应用不申请网络、定位、通讯录、相机、麦克风、精确闹钟、开机自启等权限。',
            ),
            _Section(
              title: '四、你的控制权',
              body:
                  '你可以随时在设置中修改或删除任务、打卡、标签与备注；'
                  '可以在回收站恢复或永久删除；可以导出 JSON 备份；'
                  '卸载应用会删除应用私有目录中的全部数据。',
            ),
            _Section(
              title: '五、第三方组件',
              body:
                  '应用使用 Flutter、sqflite、provider、home_widget 等开源组件，'
                  '均在本机运行。home_widget 依赖中的 WorkManager 权限已在 Manifest 中移除，'
                  '应用不使用后台联网任务。',
            ),
            _Section(
              title: '六、儿童与敏感信息',
              body:
                  '应用不面向儿童单独收集信息，也不要求填写任何身份、联系方式或健康数据。'
                  '请不要在任务标题、备注或备份文件中写入你不希望留在本机的敏感信息。',
            ),
            _Section(
              title: '七、政策变更与联系',
              body:
                  '如未来政策发生变更，会在新版本的应用内更新本页，并在更新日志中说明。'
                  '本项目为开源软件，问题与建议请通过仓库 Issues 反馈。',
            ),
            const Divider(height: 40),
            LText(
              'Privacy Policy (English)',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _Section(
              title: '1. What we collect',
              body:
                  'Xunji Check-in is an offline-only tool. We do not collect, upload, or sell '
                  'personal information. There is no account, cloud sync, advertising SDK, '
                  'analytics SDK, or network permission.',
            ),
            _Section(
              title: '2. Where data is stored',
              body:
                  'Tasks, check-ins, notes, tags, settings, and the local backup index are stored '
                  'in the app-private SQLite database. Data leaves the app only when you explicitly '
                  'export it through the Android system file picker, or when automatic backup writes '
                  'to the directory you authorized through SAF.',
            ),
            _Section(
              title: '3. Permissions',
              body:
                  'POST_NOTIFICATIONS is requested only when you enable a task reminder and is used '
                  'solely for local notifications. File access uses the Android Storage Access '
                  'Framework; the app does not request storage permission. No network, location, '
                  'contacts, camera, microphone, exact-alarm, or boot permissions are requested.',
            ),
            _Section(
              title: '4. Your control',
              body:
                  'You can edit or delete tasks, check-ins, tags, and notes at any time, restore or '
                  'permanently delete items from the recycle bin, and export a JSON backup. '
                  'Uninstalling the app removes all data in its private directory.',
            ),
            _Section(
              title: '5. Third-party components',
              body:
                  'The app uses open-source Flutter, sqflite, provider, and home_widget components, '
                  'all running locally. Unused WorkManager permissions pulled in by home_widget are '
                  'explicitly removed from the manifest.',
            ),
            _Section(
              title: '6. Children and sensitive data',
              body:
                  'The app does not knowingly collect information from children and does not require '
                  'identity, contact, or health data. Do not put sensitive information in task titles, '
                  'notes, or backup files unless you accept that it remains on your device.',
            ),
            _Section(
              title: '7. Changes and contact',
              body:
                  'Material policy changes will be published in-app with a new release and noted in '
                  'the changelog. This is an open-source project; please use the repository Issues '
                  'for questions.',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: LText(
                '纯离线 · 不联网 · 不收集 · 数据由你掌控\n'
                'Offline only · No network · No collection · You own your data',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LText(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          LText(
            body,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.65),
          ),
        ],
      ),
    );
  }
}
