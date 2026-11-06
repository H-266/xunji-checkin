import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import '../widgets/l_text.dart';

/// 使用教程 + 常见问题。教程结束时通过 OnboardingService 让 AppShell 重新播放。
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const LText('使用教程与常见问题')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          FilledButton.icon(
            onPressed: () {
              OnboardingService.instance.requestReplay();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const LText('重新播放使用教程'),
          ),
          const SizedBox(height: 16),
          const _Faq(
            question: '为什么第二天打卡状态会重置？',
            answer:
                '打卡记录按「任务 + 日期」保存。每日任务在每一天都是新的记录，'
                '所以零点后自动回到未完成状态，不需要改写数据库。',
          ),
          const _Faq(
            question: '临时待办完成后为什么不见了？',
            answer:
                '临时待办是一次性任务。勾选完成后会从今日列表消失，'
                '但完成当天仍会计入热力图；可在任务详情里撤销或查看。',
          ),
          const _Faq(
            question: '桌面小组件不刷新怎么办？',
            answer:
                '先在小组件配置页点「立即刷新」。国产 ROM 可能限制后台，'
                '请在设置 → 保活帮助里允许后台运行和自启动；'
                '零点刷新使用系统非精确闹钟，可能会有几分钟延迟。',
          ),
          const _Faq(
            question: '备份文件在哪里？会申请存储权限吗？',
            answer:
                '导出时由系统文件选择器决定保存位置，App 只写入你选中的文件，'
                '不会申请存储权限。导入会先校验，再让你选择覆盖或追加。',
          ),
          const _Faq(
            question: '自动备份什么时候执行？',
            answer:
                '默认关闭。开启后只在 App 启动或回到前台时检查周期，'
                '不会常驻后台；目录由系统文件选择器授权，保留份数可自选。'
                '最近一次自动备份还会在应用私有目录留一份，'
                '数据自检发现异常时可一键回滚。',
          ),
          const _Faq(
            question: '提醒通知不弹出？',
            answer:
                '请确认系统通知权限已开启，并在电池设置里允许后台运行。'
                '部分 ROM 的省电策略会延迟本地通知，本 App 不联网、不常驻后台。',
          ),
          const _Faq(
            question: '数据会上传吗？',
            answer:
                '不会。所有任务、打卡、标签和设置都只保存在本机 SQLite，'
                '没有账号、没有网络请求。',
          ),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  final String question;
  final String answer;

  const _Faq({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: LText(
          question,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        expansionAnimationStyle: AnimationStyle(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LText(
            answer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
