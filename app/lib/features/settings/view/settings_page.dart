import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomodoroAsync = ref.watch(pomodoroConfigProvider);
    final pomodoroSubtitle = pomodoroAsync.maybeWhen(
      data: (c) => '专注时长：${c.workDurationMinutes} 分钟',
      orElse: () => '专注时长：加载中…',
    );

    final appearanceAsync = ref.watch(appearanceConfigProvider);
    final appearanceSubtitle = appearanceAsync.maybeWhen(
      data: (c) =>
          '主题：${_themeModeLabel(c.themeMode)} / 密度：${_densityLabel(c.density)}',
      orElse: () => '主题：加载中…',
    );

    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return AppPageScaffold(
      title: '设置',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: ListView(
        padding: DpInsets.page,
        children: [
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI',
                  subtitle: 'baseUrl / model / apiKey',
                  onTap: () => context.push('/settings/ai'),
                ),
                Divider(height: 0, color: colorScheme.border),
                _SettingsRow(
                  icon: Icons.timer_outlined,
                  title: '番茄',
                  subtitle: pomodoroSubtitle,
                  onTap: () => context.push('/settings/pomodoro'),
                ),
                Divider(height: 0, color: colorScheme.border),
                _SettingsRow(
                  icon: Icons.storage_outlined,
                  title: '数据',
                  subtitle: '导出/备份/恢复/清空',
                  onTap: () => context.push('/settings/data'),
                ),
                Divider(height: 0, color: colorScheme.border),
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  title: '外观',
                  subtitle: appearanceSubtitle,
                  onTap: () => context.push('/settings/appearance'),
                ),
                Divider(height: 0, color: colorScheme.border),
                _SettingsRow(
                  icon: Icons.toggle_on_outlined,
                  title: '功能开关',
                  subtitle: 'override / kill-switch / snapshot',
                  onTap: () => context.push('/settings/flags'),
                ),
              ],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            child: Text(
              '建议：把默认入口设为「今天」，并用工作台编辑把模块组合成你的工作流。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.mutedForeground),
            const SizedBox(width: DpSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
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
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}

String _themeModeLabel(domain.AppThemeMode mode) {
  return switch (mode) {
    domain.AppThemeMode.system => '系统',
    domain.AppThemeMode.light => '浅色',
    domain.AppThemeMode.dark => '深色',
  };
}

String _densityLabel(domain.AppDensity density) {
  return switch (density) {
    domain.AppDensity.comfortable => '舒适',
    domain.AppDensity.compact => '紧凑',
  };
}
