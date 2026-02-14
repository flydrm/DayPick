import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return AppPageScaffold(
      title: '隐私说明',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: ListView(
        padding: DpInsets.page,
        children: [
          Text(
            '我们把“可控可信”当作产品底座：无登录、本地优先、离线可用。',
            style: shadTheme.textTheme.h4.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          Text(
            '1) 数据存储',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: DpSpacing.sm),
          Text(
            '- 任务/笔记/番茄记录默认仅保存在本机（本地数据库）。\n'
            '- 你可以随时导出/备份/恢复/清空。',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          Text(
            '2) AI 边界',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: DpSpacing.sm),
          Text(
            '- AI 仅在你点击后才会发送内容。\n'
            '- 应用会尽量在操作前明确告诉你“将发送什么/到哪里”。\n'
            '- AI 生成结果必须先预览→可编辑→再采用；不会静默覆盖你的内容。',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          Text(
            '3) apiKey 与备份',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: DpSpacing.sm),
          Text(
            '- AI 的 apiKey 默认只在本地密文存储，不会进入明文导出/普通加密备份。\n'
            '- 仅当你选择「数据 → 安全导出（含密钥）」时，才会把 apiKey 纳入加密包。\n'
            '- 加密包使用 passphrase（至少 6 位）；普通备份可用 6 位数字 PIN，而“含密钥”导出要求强密码且禁止 6 位 PIN。密码不保存、不回填，遗失将无法恢复。',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          Text(
            '4) 权限最小化',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: DpSpacing.sm),
          Text(
            '- 通知权限仅用于番茄到点提醒（你开始专注后才会请求）。\n'
            '- 联网能力仅用于你主动触发 AI 时向你配置的 baseUrl 发起请求（普通权限，不会弹窗）。\n'
            '- 文件选择/分享仅在你导出/备份/恢复时触发。',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
