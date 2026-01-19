import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_section_card.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';

class PomodoroSettingsPage extends ConsumerWidget {
  const PomodoroSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(pomodoroConfigProvider);

    return AppPageScaffold(
      title: '番茄',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: configAsync.when(
        loading: () => const Center(child: ShadProgress(minHeight: 8)),
        error: (error, stack) => Center(child: Text('加载失败：$error')),
        data: (config) => _PomodoroSettingsBody(config: config),
      ),
    );
  }
}

class _PomodoroSettingsBody extends ConsumerWidget {
  const _PomodoroSettingsBody({required this.config});

  final domain.PomodoroConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final repo = ref.read(pomodoroConfigRepositoryProvider);
    final current = config.workDurationMinutes;
    final shortBreak = config.shortBreakMinutes;
    final longBreak = config.longBreakMinutes;
    final longBreakEvery = config.longBreakEvery;
    final dailyBudgetPomodoros = config.dailyBudgetPomodoros;
    final autoStartBreak = config.autoStartBreak;
    final autoStartFocus = config.autoStartFocus;
    final sound = config.notificationSound;
    final vibration = config.notificationVibration;
    final isDefault =
        current == 25 &&
        shortBreak == 5 &&
        longBreak == 15 &&
        longBreakEvery == 4 &&
        dailyBudgetPomodoros == 8 &&
        autoStartBreak == false &&
        autoStartFocus == false &&
        sound == false &&
        vibration == false;

    Future<void> save({
      int? workMinutes,
      int? shortBreakMinutes,
      int? longBreakMinutes,
      int? longBreakEveryCount,
      int? budgetPomodoros,
      bool? autoStartBreakValue,
      bool? autoStartFocusValue,
      bool? notificationSoundValue,
      bool? notificationVibrationValue,
    }) async {
      await repo.save(
        domain.PomodoroConfig(
          workDurationMinutes: workMinutes ?? current,
          shortBreakMinutes: shortBreakMinutes ?? shortBreak,
          longBreakMinutes: longBreakMinutes ?? longBreak,
          longBreakEvery: longBreakEveryCount ?? longBreakEvery,
          dailyBudgetPomodoros: budgetPomodoros ?? dailyBudgetPomodoros,
          autoStartBreak: autoStartBreakValue ?? autoStartBreak,
          autoStartFocus: autoStartFocusValue ?? autoStartFocus,
          notificationSound: notificationSoundValue ?? sound,
          notificationVibration: notificationVibrationValue ?? vibration,
        ),
      );
    }

    return ListView(
      padding: DpInsets.page,
      children: [
        DpSectionCard(
          title: '番茄配置',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '当前：专注 $current 分钟 / 短休 $shortBreak 分钟 / 长休 $longBreak 分钟（每 $longBreakEvery 次专注 1 次长休）',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              ShadSelect<int>(
                initialValue: current,
                selectedOptionBuilder: (context, value) => Text(
                  '专注：$value 分钟',
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: [
                  for (var m = 10; m <= 60; m += 5)
                    ShadOption<int>(value: m, child: Text('$m 分钟')),
                ],
                onChanged: (value) async {
                  if (value == null || value == current) return;
                  await save(workMinutes: value);
                },
              ),
              const SizedBox(height: DpSpacing.md),
              ShadSelect<int>(
                initialValue: shortBreak,
                selectedOptionBuilder: (context, value) => Text(
                  '短休：$value 分钟',
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: [
                  for (var m = 3; m <= 30; m += 1)
                    ShadOption<int>(value: m, child: Text('$m 分钟')),
                ],
                onChanged: (value) async {
                  if (value == null || value == shortBreak) return;
                  await save(shortBreakMinutes: value);
                },
              ),
              const SizedBox(height: DpSpacing.md),
              ShadSelect<int>(
                initialValue: longBreak,
                selectedOptionBuilder: (context, value) => Text(
                  '长休：$value 分钟',
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: [
                  for (var m = 5; m <= 60; m += 5)
                    ShadOption<int>(value: m, child: Text('$m 分钟')),
                ],
                onChanged: (value) async {
                  if (value == null || value == longBreak) return;
                  await save(longBreakMinutes: value);
                },
              ),
              const SizedBox(height: DpSpacing.md),
              ShadSelect<int>(
                initialValue: longBreakEvery,
                selectedOptionBuilder: (context, value) => Text(
                  '长休间隔：每 $value 次专注',
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: [
                  for (var n = 2; n <= 10; n += 1)
                    ShadOption<int>(value: n, child: Text('每 $n 次专注')),
                ],
                onChanged: (value) async {
                  if (value == null || value == longBreakEvery) return;
                  await save(longBreakEveryCount: value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        DpSectionCard(
          title: '预算',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadSelect<int>(
                initialValue: dailyBudgetPomodoros,
                selectedOptionBuilder: (context, value) => Text(
                  value == 0 ? '每日预算：不限制' : '每日预算：$value 番茄',
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: const [
                  ShadOption<int>(value: 0, child: Text('不限制')),
                  ShadOption<int>(value: 4, child: Text('4')),
                  ShadOption<int>(value: 6, child: Text('6')),
                  ShadOption<int>(value: 8, child: Text('8')),
                  ShadOption<int>(value: 10, child: Text('10')),
                  ShadOption<int>(value: 12, child: Text('12')),
                  ShadOption<int>(value: 14, child: Text('14')),
                  ShadOption<int>(value: 16, child: Text('16')),
                ],
                onChanged: (value) async {
                  if (value == null || value == dailyBudgetPomodoros) return;
                  await save(budgetPomodoros: value);
                },
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                '预算用于 Today 过载提示（不会强制限制）。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        DpSectionCard(
          title: '自动化',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadSwitch(
                value: autoStartBreak,
                onChanged: (v) async {
                  if (v == autoStartBreak) return;
                  await save(autoStartBreakValue: v);
                },
                label: const Text('自动开始休息'),
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                '专注结束并保存后，自动进入短休/长休。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              ShadSwitch(
                value: autoStartFocus,
                onChanged: (v) async {
                  if (v == autoStartFocus) return;
                  await save(autoStartFocusValue: v);
                },
                label: const Text('休息结束自动开始下一段'),
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                '默认关闭，避免打扰；开启后会自动开始下一段专注。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        DpSectionCard(
          title: '提醒',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadSwitch(
                value: sound,
                onChanged: (v) async {
                  if (v == sound) return;
                  await save(notificationSoundValue: v);
                },
                label: const Text('声音'),
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadSwitch(
                value: vibration,
                onChanged: (v) async {
                  if (v == vibration) return;
                  await save(notificationVibrationValue: v);
                },
                label: const Text('震动'),
              ),
              const SizedBox(height: DpSpacing.md),
              ShadButton.outline(
                onPressed: isDefault
                    ? null
                    : () async {
                        await repo.save(const domain.PomodoroConfig());
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已恢复默认番茄配置')),
                        );
                      },
                leading: const Icon(Icons.refresh_outlined, size: 18),
                child: const Text('恢复默认'),
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        const ShadAlert(
          icon: Icon(Icons.lightbulb_outline),
          title: Text('建议'),
          description: Text('专注 25–45 分钟更稳；短休 5–10 分钟；长休 15–20 分钟。'),
        ),
      ],
    );
  }
}
