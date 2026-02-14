import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../providers/calendar_constraints_providers.dart';
import 'calendar_constraints_widgets.dart';

class CalendarConstraintsSheet extends ConsumerWidget {
  const CalendarConstraintsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final state = ref.watch(calendarConstraintsControllerProvider);
    final controller = ref.read(calendarConstraintsControllerProvider.notifier);

    String formatTimeRange(domain.CalendarTitledEvent event) {
      final localizations = MaterialLocalizations.of(context);
      final start = TimeOfDay.fromDateTime(event.start);
      final end = TimeOfDay.fromDateTime(event.end);
      return '${localizations.formatTimeOfDay(start)}–${localizations.formatTimeOfDay(end)}';
    }

    Widget permissionActions() {
      switch (state.permissionState) {
        case domain.CalendarPermissionState.granted:
          return Wrap(
            spacing: DpSpacing.sm,
            runSpacing: DpSpacing.sm,
            children: [
              ShadButton.outline(
                key: const ValueKey('calendar_constraints_sheet_refresh'),
                onPressed: () => unawaited(controller.refresh()),
                child: const Text('刷新'),
              ),
              ShadButton.outline(
                key: const ValueKey('calendar_constraints_sheet_open_settings'),
                onPressed: () => unawaited(controller.openAppSettings()),
                child: const Text('去设置'),
              ),
            ],
          );
        case domain.CalendarPermissionState.denied:
        case domain.CalendarPermissionState.restricted:
          return Wrap(
            spacing: DpSpacing.sm,
            runSpacing: DpSpacing.sm,
            children: [
              ShadButton.outline(
                key: const ValueKey('calendar_constraints_sheet_open_settings'),
                onPressed: () => unawaited(controller.openAppSettings()),
                child: const Text('去设置'),
              ),
              ShadButton.outline(
                key: const ValueKey('calendar_constraints_sheet_continue_without'),
                onPressed: () => unawaited(controller.skip()),
                child: const Text('继续无约束'),
              ),
            ],
          );
        case domain.CalendarPermissionState.notSupported:
          return ShadButton.outline(
            key: const ValueKey('calendar_constraints_sheet_continue_without'),
            onPressed: () => unawaited(controller.skip()),
            child: const Text('继续无约束'),
          );
        case domain.CalendarPermissionState.unknown:
          return Wrap(
            spacing: DpSpacing.sm,
            runSpacing: DpSpacing.sm,
            children: [
              ShadButton.outline(
                key: const ValueKey('calendar_constraints_sheet_connect'),
                onPressed: () => unawaited(controller.connect()),
                child: const Text('连接日历'),
              ),
              ShadButton.outline(
                key: const ValueKey('calendar_constraints_sheet_skip'),
                onPressed: () => unawaited(controller.skip()),
                child: const Text('跳过'),
              ),
            ],
          );
      }
    }

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.72,
        child: Padding(
          padding: EdgeInsets.only(
            left: DpSpacing.lg,
            right: DpSpacing.lg,
            top: DpSpacing.md,
            bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '时间约束',
                      style: shadTheme.textTheme.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: '关闭',
                    child: ShadIconButton.ghost(
                      key: const ValueKey('calendar_constraints_sheet_close'),
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                CalendarConstraintsCopy.prePermissionValue,
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                CalendarConstraintsCopy.prePermissionScope,
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                CalendarConstraintsCopy.prePermissionControl,
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              permissionActions(),
              const SizedBox(height: DpSpacing.md),
              if (state.permissionState == domain.CalendarPermissionState.granted) ...[
                if (state.loading && state.summary == null)
                  const ShadProgress(minHeight: 8)
                else if (state.summary != null)
                  ShadCard(
                    padding: const EdgeInsets.all(DpSpacing.md),
                    child: CalendarBusyFreeBar(summary: state.summary!),
                  ),
                const SizedBox(height: DpSpacing.md),
                ShadCard(
                  padding: const EdgeInsets.all(DpSpacing.md),
                  child: ShadSwitch(
                    key: const ValueKey('calendar_constraints_show_titles_switch'),
                    value: state.showEventTitles,
                    onChanged: (enabled) =>
                        unawaited(controller.setShowEventTitles(enabled)),
                    label: const Text('显示标题（默认关闭）'),
                    sublabel: const Text('默认只读取忙闲与空档；标题仅在显式开启后用于 UI 展示'),
                  ),
                ),
                if (state.showEventTitles) ...[
                  const SizedBox(height: DpSpacing.md),
                  ShadCard(
                    padding: const EdgeInsets.all(DpSpacing.md),
                    child: Builder(
                      builder: (context) {
                        if (state.titlesLoading && state.titledEvents == null) {
                          return const ShadProgress(minHeight: 8);
                        }

                        if (state.titlesError != null) {
                          return const DpInlineNotice(
                            variant: DpInlineNoticeVariant.destructive,
                            title: '标题读取失败',
                            description: '不影响忙闲概览。你可以重试，或稍后再试。',
                            icon: Icon(Icons.error_outline),
                          );
                        }

                        final events = state.titledEvents ?? const [];
                        if (events.isEmpty) {
                          return const Text('今日无日程事件');
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '今日事件',
                              style: shadTheme.textTheme.small.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.foreground,
                              ),
                            ),
                            const SizedBox(height: DpSpacing.sm),
                            for (final event in events) ...[
                              Row(
                                children: [
                                  Text(
                                    formatTimeRange(event),
                                    style: shadTheme.textTheme.muted.copyWith(
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(width: DpSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      event.title.isEmpty ? '（无标题）' : event.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: shadTheme.textTheme.small.copyWith(
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (state.titlesLoading) ...[
                              const SizedBox(height: DpSpacing.sm),
                              const ShadProgress(minHeight: 8),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ] else ...[
                const Spacer(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
