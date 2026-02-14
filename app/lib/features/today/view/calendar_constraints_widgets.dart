import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/dp_spacing.dart';

class CalendarConstraintsCopy {
  static const prePermissionValue = '用于帮你看清今天的时间约束（忙/闲与空档）';
  static const prePermissionScope = '默认只读取忙闲与空档，不读取标题；你可随时开启/关闭';
  static const prePermissionControl = '可跳过；拒绝也不影响使用';
}

class CalendarBusyFreeBar extends StatelessWidget {
  const CalendarBusyFreeBar({super.key, required this.summary});

  final domain.CalendarBusyFreeSummary summary;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final freeSlotsCount = summary.freeSlotsCount;
    final intervals = summary.busyIntervals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final background = colorScheme.muted;
            final busy = colorScheme.mutedForeground.withAlpha(90);

            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 10,
                width: width,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: background),
                    for (final interval in intervals)
                      Positioned(
                        left: (interval.startMinute / 1440.0) * width,
                        width: ((interval.endMinute - interval.startMinute) / 1440.0) * width,
                        top: 0,
                        bottom: 0,
                        child: ColoredBox(color: busy),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: DpSpacing.sm),
        Row(
          children: [
            Text(
              '仅忙闲（推荐）',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const Spacer(),
            Text(
              '今日空档 $freeSlotsCount 段',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
