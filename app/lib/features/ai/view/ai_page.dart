import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/kit/dp_action_card.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../providers/ai_providers.dart';

class AiPage extends ConsumerWidget {
  const AiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(aiConfigProvider);
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    const todayTabIndex = 2;

    void continueToday() {
      final navigationShell =
          context.findAncestorWidgetOfExactType<StatefulNavigationShell>();
      if (navigationShell != null) {
        navigationShell.goBranch(todayTabIndex, initialLocation: false);
        return;
      }
      context.go('/today');
    }

    return AppPageScaffold(
      title: 'AI（效率台）',
      body: ListView(
        padding: DpInsets.page,
        children: [
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              key: const ValueKey('ai_continue_today'),
              onPressed: continueToday,
              child: const Text('继续今天 / 回到 Today'),
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          configAsync.when(
            loading: () => const ShadProgress(minHeight: 8),
            error: (error, stack) => ShadAlert.destructive(
              icon: const Icon(Icons.error_outline),
              title: const Text('AI 配置读取失败'),
              description: Text('$error'),
            ),
            data: (config) {
              final ready =
                  config != null &&
                  config.apiKey != null &&
                  config.apiKey!.trim().isNotEmpty;

              final title = ready ? 'AI 已就绪' : 'AI 未配置';
              final subtitle = ready
                  ? '${config.model} · ${_shortBaseUrl(config.baseUrl)}'
                  : '先在设置里配置 baseUrl / model / apiKey';

              return ShadCard(
                padding: DpInsets.card,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      ready
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                      color: ready
                          ? colorScheme.primary
                          : colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: DpSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: shadTheme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: DpSpacing.xs),
                          Text(
                            subtitle,
                            style: shadTheme.textTheme.muted.copyWith(
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: DpSpacing.md),
                          ShadButton.secondary(
                            onPressed: () => context.push('/settings/ai'),
                            size: ShadButtonSize.sm,
                            child: const Text('去设置'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: DpSpacing.md),
          DpActionCard(
            title: 'AI 速记',
            description: '把零散输入整理成可保存的笔记草稿。',
            cta: '开始',
            ctaVariant: ShadButtonVariant.secondary,
            onTap: () => context.push('/ai/quick-note'),
            leading: const Icon(Icons.edit_note_outlined, size: 18),
          ),
          const SizedBox(height: DpSpacing.md),
          DpActionCard(
            title: '一句话拆任务',
            description: '把输入变清楚：生成可编辑的任务清单草稿。',
            cta: '开始',
            ctaVariant: ShadButtonVariant.secondary,
            onTap: () => context.push('/ai/breakdown'),
            leading: const Icon(Icons.splitscreen_outlined, size: 18),
          ),
          const SizedBox(height: DpSpacing.md),
          DpActionCard(
            title: '问答检索',
            description: 'Evidence-first：回答必须附可跳转引用。',
            cta: '进入',
            ctaVariant: ShadButtonVariant.secondary,
            onTap: () => context.push('/ai/ask'),
            leading: const Icon(Icons.question_answer_outlined, size: 18),
          ),
          const SizedBox(height: DpSpacing.md),
          DpActionCard(
            title: '今日计划',
            description: '从现有任务生成“今日计划”草稿（可编辑后保存）。',
            cta: '进入',
            ctaVariant: ShadButtonVariant.secondary,
            onTap: () => context.push('/ai/today-plan'),
            leading: const Icon(Icons.today_outlined, size: 18),
          ),
          const SizedBox(height: DpSpacing.md),
          DpActionCard(
            title: '昨日回顾',
            description: '基于本地证据生成日报草稿，且只追加不覆盖。',
            cta: '进入',
            ctaVariant: ShadButtonVariant.secondary,
            onTap: () => context.push('/ai/daily'),
            leading: const Icon(Icons.history_edu_outlined, size: 18),
          ),
          const SizedBox(height: DpSpacing.md),
          DpActionCard(
            title: '周复盘',
            description: '基于本地证据生成草稿，且只追加不覆盖。',
            cta: '进入',
            ctaVariant: ShadButtonVariant.secondary,
            onTap: () => context.push('/ai/weekly'),
            leading: const Icon(Icons.calendar_view_week_outlined, size: 18),
          ),
        ],
      ),
    );
  }

  String _shortBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.length <= 32) return trimmed;
    return '${trimmed.substring(0, 32)}…';
  }
}
