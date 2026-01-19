import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_section_card.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/sheets/time_picker_sheet.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearanceAsync = ref.watch(appearanceConfigProvider);

    return AppPageScaffold(
      title: '外观',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: appearanceAsync.when(
        loading: () => const Center(child: ShadProgress(minHeight: 8)),
        error: (error, stack) => Center(child: Text('加载失败：$error')),
        data: (config) => _AppearanceSettingsBody(config: config),
      ),
    );
  }
}

class _AppearanceSettingsBody extends ConsumerWidget {
  const _AppearanceSettingsBody({required this.config});

  final domain.AppearanceConfig config;

  String _formatTime(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    final hh = (clamped ~/ 60).toString().padLeft(2, '0');
    final mm = (clamped % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Color _accentSwatch(domain.AppAccent accent, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (accent) {
      domain.AppAccent.a =>
        isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2F5D9B),
      domain.AppAccent.b =>
        isDark ? const Color(0xFF44C2B3) : const Color(0xFF0F766E),
      domain.AppAccent.c =>
        isDark ? const Color(0xFFB8C48A) : const Color(0xFF5B6B3A),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(appearanceConfigRepositoryProvider);
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDefault =
        config.themeMode == domain.AppThemeMode.system &&
        config.density == domain.AppDensity.comfortable &&
        config.accent == domain.AppAccent.a &&
        config.defaultTab == domain.AppDefaultTab.today;

    return ListView(
      padding: DpInsets.page,
      children: [
        DpSectionCard(
          title: '主题',
          child: ShadSelect<domain.AppThemeMode>(
            initialValue: config.themeMode,
            selectedOptionBuilder: (context, value) => Text(
              switch (value) {
                domain.AppThemeMode.system => '系统',
                domain.AppThemeMode.light => '浅色',
                domain.AppThemeMode.dark => '深色',
              },
              style: shadTheme.textTheme.small.copyWith(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            options: const [
              ShadOption<domain.AppThemeMode>(
                value: domain.AppThemeMode.system,
                child: Text('系统'),
              ),
              ShadOption<domain.AppThemeMode>(
                value: domain.AppThemeMode.light,
                child: Text('浅色'),
              ),
              ShadOption<domain.AppThemeMode>(
                value: domain.AppThemeMode.dark,
                child: Text('深色'),
              ),
            ],
            onChanged: (next) async {
              if (next == null || next == config.themeMode) return;
              await repo.save(config.copyWith(themeMode: next));
            },
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        DpSectionCard(
          title: '密度',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadSwitch(
                value: config.density == domain.AppDensity.compact,
                onChanged: (v) async {
                  final next = v
                      ? domain.AppDensity.compact
                      : domain.AppDensity.comfortable;
                  if (next == config.density) return;
                  await repo.save(config.copyWith(density: next));
                },
                label: const Text('紧凑模式'),
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                '列表更紧凑，信息密度更高。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        DpSectionCard(
          title: 'Accent',
          child: ShadSelect<domain.AppAccent>(
            initialValue: config.accent,
            selectedOptionBuilder: (context, value) => Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: _accentSwatch(value, brightness),
                ),
                const SizedBox(width: 8),
                Text(
                  switch (value) {
                    domain.AppAccent.a => 'A',
                    domain.AppAccent.b => 'B',
                    domain.AppAccent.c => 'C',
                  },
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            options: [
              ShadOption<domain.AppAccent>(
                value: domain.AppAccent.a,
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: _accentSwatch(domain.AppAccent.a, brightness),
                    ),
                    const SizedBox(width: 8),
                    const Text('A'),
                  ],
                ),
              ),
              ShadOption<domain.AppAccent>(
                value: domain.AppAccent.b,
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: _accentSwatch(domain.AppAccent.b, brightness),
                    ),
                    const SizedBox(width: 8),
                    const Text('B'),
                  ],
                ),
              ),
              ShadOption<domain.AppAccent>(
                value: domain.AppAccent.c,
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: _accentSwatch(domain.AppAccent.c, brightness),
                    ),
                    const SizedBox(width: 8),
                    const Text('C'),
                  ],
                ),
              ),
            ],
            onChanged: (next) async {
              if (next == null || next == config.accent) return;
              await repo.save(config.copyWith(accent: next));
            },
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        DpSectionCard(
          title: '默认入口',
          child: ShadSelect<domain.AppDefaultTab>(
            initialValue: config.defaultTab,
            selectedOptionBuilder: (context, value) => Text(
              switch (value) {
                domain.AppDefaultTab.ai => 'AI',
                domain.AppDefaultTab.notes => '笔记',
                domain.AppDefaultTab.today => '今天',
                domain.AppDefaultTab.tasks => '任务',
                domain.AppDefaultTab.focus => '专注',
              },
              style: shadTheme.textTheme.small.copyWith(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            options: const [
              ShadOption<domain.AppDefaultTab>(
                value: domain.AppDefaultTab.ai,
                child: Text('AI'),
              ),
              ShadOption<domain.AppDefaultTab>(
                value: domain.AppDefaultTab.notes,
                child: Text('笔记'),
              ),
              ShadOption<domain.AppDefaultTab>(
                value: domain.AppDefaultTab.today,
                child: Text('今天'),
              ),
              ShadOption<domain.AppDefaultTab>(
                value: domain.AppDefaultTab.tasks,
                child: Text('任务'),
              ),
              ShadOption<domain.AppDefaultTab>(
                value: domain.AppDefaultTab.focus,
                child: Text('专注'),
              ),
            ],
            onChanged: (next) async {
              if (next == null || next == config.defaultTab) return;
              await repo.save(config.copyWith(defaultTab: next));
            },
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        DpSectionCard(
          title: '时间轴（Timeboxing）',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadSelect<domain.TimeboxingLayout>(
                initialValue: config.timeboxingLayout,
                selectedOptionBuilder: (context, value) => Text(
                  switch (value) {
                    domain.TimeboxingLayout.full => 'Full',
                    domain.TimeboxingLayout.minimal => 'Minimal',
                  },
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: const [
                  ShadOption(
                    value: domain.TimeboxingLayout.full,
                    child: Text('布局：Full'),
                  ),
                  ShadOption(
                    value: domain.TimeboxingLayout.minimal,
                    child: Text('布局：Minimal'),
                  ),
                ],
                onChanged: (next) async {
                  if (next == null || next == config.timeboxingLayout) return;
                  await repo.save(config.copyWith(timeboxingLayout: next));
                },
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadButton.outline(
                onPressed: () async {
                  final initial = config.timeboxingStartMinutes ?? 9 * 60;
                  final picked = await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (context) => TimePickerSheet(
                      title: '时间轴开始时间',
                      initialMinutes: initial,
                      stepMinutes: 5,
                    ),
                  );
                  if (picked == null) return;
                  await repo.save(
                    config.copyWith(
                      timeboxingStartMinutes: picked.clamp(0, 24 * 60 - 1),
                    ),
                  );
                },
                leading: const Icon(Icons.schedule_outlined, size: 18),
                child: Text(
                  '开始时间：${config.timeboxingStartMinutes == null ? '自动' : _formatTime(config.timeboxingStartMinutes!)}',
                ),
              ),
              const SizedBox(height: DpSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () async {
                        final picked = await showModalBottomSheet<int>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => TimePickerSheet(
                            title: '工作时段开始',
                            initialMinutes:
                                config.timeboxingWorkdayStartMinutes,
                            stepMinutes: 15,
                          ),
                        );
                        if (picked == null) return;
                        final nextStart = picked.clamp(0, 24 * 60 - 1);
                        var nextEnd = config.timeboxingWorkdayEndMinutes;
                        if (nextEnd <= nextStart) {
                          nextEnd = (nextStart + 8 * 60).clamp(0, 24 * 60 - 1);
                        }
                        await repo.save(
                          config.copyWith(
                            timeboxingWorkdayStartMinutes: nextStart,
                            timeboxingWorkdayEndMinutes: nextEnd,
                          ),
                        );
                      },
                      child: Text(
                        '开始：${_formatTime(config.timeboxingWorkdayStartMinutes)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () async {
                        final picked = await showModalBottomSheet<int>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => TimePickerSheet(
                            title: '工作时段结束',
                            initialMinutes: config.timeboxingWorkdayEndMinutes,
                            stepMinutes: 15,
                          ),
                        );
                        if (picked == null) return;
                        final nextEnd = picked.clamp(0, 24 * 60 - 1);
                        var nextStart = config.timeboxingWorkdayStartMinutes;
                        if (nextEnd <= nextStart) {
                          nextStart = (nextEnd - 8 * 60).clamp(0, 24 * 60 - 1);
                        }
                        await repo.save(
                          config.copyWith(
                            timeboxingWorkdayStartMinutes: nextStart,
                            timeboxingWorkdayEndMinutes: nextEnd,
                          ),
                        );
                      },
                      child: Text(
                        '结束：${_formatTime(config.timeboxingWorkdayEndMinutes)}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        ShadButton.outline(
          onPressed: isDefault
              ? null
              : () async {
                  await repo.save(
                    config.copyWith(
                      themeMode: domain.AppThemeMode.system,
                      density: domain.AppDensity.comfortable,
                      accent: domain.AppAccent.a,
                      defaultTab: domain.AppDefaultTab.today,
                    ),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已恢复默认外观')));
                },
          leading: const Icon(Icons.refresh_outlined, size: 18),
          child: const Text('恢复默认'),
        ),
        const SizedBox(height: DpSpacing.md),
        ShadCard(
          padding: DpInsets.card,
          child: Text(
            '风格默认偏“安静、商务、稳重”：低饱和配色 + 清晰层级。',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}
