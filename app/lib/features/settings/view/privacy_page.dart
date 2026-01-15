import 'package:flutter/material.dart';

import '../../../ui/scaffolds/app_page_scaffold.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '隐私说明',
      showSettingsAction: false,
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          const Text(
            '我们把“可控可信”当作产品底座：无登录、本地优先、离线可用。',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text('1) 数据存储'),
          const SizedBox(height: 6),
          const Text(
            '- 任务/笔记/番茄记录默认仅保存在本机（本地数据库）。\n'
            '- 你可以随时导出/备份/恢复/清空。',
          ),
          const SizedBox(height: 12),
          const Text('2) AI 边界'),
          const SizedBox(height: 6),
          const Text(
            '- AI 仅在你点击后才会发送内容。\n'
            '- 应用会尽量在操作前明确告诉你“将发送什么/到哪里”。\n'
            '- AI 生成结果必须先预览→可编辑→再采用；不会静默覆盖你的内容。',
          ),
          const SizedBox(height: 12),
          const Text('3) apiKey 与备份'),
          const SizedBox(height: 6),
          const Text(
            '- AI 的 apiKey 只在本地密文存储，不会进入导出/备份包。\n'
            '- 备份采用强加密（PIN 为恰好 6 位数字，允许 0 开头）；PIN 不保存、不回填。\n'
            '- 请妥善保管 PIN：遗失将无法恢复。',
          ),
          const SizedBox(height: 12),
          const Text('4) 权限最小化'),
          const SizedBox(height: 6),
          const Text(
            '- 通知权限仅用于番茄到点提醒（你开始专注后才会请求）。\n'
            '- 联网能力仅用于你主动触发 AI 时向你配置的 baseUrl 发起请求（普通权限，不会弹窗）。\n'
            '- 文件选择/分享仅在你导出/备份/恢复时触发。',
          ),
        ],
      ),
    );
  }
}
