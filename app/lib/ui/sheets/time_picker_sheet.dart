import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens/dp_spacing.dart';

class TimePickerSheet extends StatefulWidget {
  const TimePickerSheet({
    super.key,
    required this.title,
    required this.initialMinutes,
    this.stepMinutes = 5,
  });

  final String title;
  final int initialMinutes;
  final int stepMinutes;

  @override
  State<TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<TimePickerSheet> {
  late int _hour;
  late int _minute;

  List<int> get _minuteOptions {
    final step = widget.stepMinutes <= 0 ? 5 : widget.stepMinutes;
    return [for (var m = 0; m < 60; m += step) m];
  }

  @override
  void initState() {
    super.initState();
    final clamped = widget.initialMinutes.clamp(0, 24 * 60 - 1);
    _hour = clamped ~/ 60;
    final rawMinute = clamped % 60;
    _minute = _snapMinute(rawMinute);
  }

  int _snapMinute(int minute) {
    final options = _minuteOptions;
    if (options.isEmpty) return minute;
    var best = options.first;
    var bestDist = (minute - best).abs();
    for (final m in options.skip(1)) {
      final dist = (minute - m).abs();
      if (dist < bestDist) {
        best = m;
        bestDist = dist;
      }
    }
    return best;
  }

  String _format(int hour, int minute) {
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _setNow() {
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final minutes = now.hour * 60 + now.minute;
    final step = widget.stepMinutes <= 0 ? 5 : widget.stepMinutes;
    final snapped = ((minutes + step - 1) ~/ step) * step;
    setState(() {
      _hour = (snapped ~/ 60).clamp(0, 23);
      _minute = _snapMinute(snapped % 60);
    });
  }

  void _setNine() {
    setState(() {
      _hour = 9;
      _minute = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.lg,
          bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: shadTheme.textTheme.h4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                Tooltip(
                  message: '关闭',
                  child: ShadIconButton.ghost(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '当前选择：${_format(_hour, _minute)}',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: DpSpacing.lg),
            ShadCard(
              padding: const EdgeInsets.all(DpSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: ShadSelect<int>(
                      initialValue: _hour,
                      options: [
                        for (var h = 0; h < 24; h++)
                          ShadOption(
                            value: h,
                            child: Text(h.toString().padLeft(2, '0')),
                          ),
                      ],
                      selectedOptionBuilder: (context, value) => Text(
                        value.toString().padLeft(2, '0'),
                        style: shadTheme.textTheme.small.copyWith(
                          color: colorScheme.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _hour = value);
                      },
                    ),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  Text(
                    ':',
                    style: shadTheme.textTheme.h4.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  Expanded(
                    child: ShadSelect<int>(
                      initialValue: _minute,
                      options: [
                        for (final m in _minuteOptions)
                          ShadOption(
                            value: m,
                            child: Text(m.toString().padLeft(2, '0')),
                          ),
                      ],
                      selectedOptionBuilder: (context, value) => Text(
                        value.toString().padLeft(2, '0'),
                        style: shadTheme.textTheme.small.copyWith(
                          color: colorScheme.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _minute = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DpSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: _setNow,
                    child: const Text('现在'),
                  ),
                ),
                const SizedBox(width: DpSpacing.sm),
                Expanded(
                  child: ShadButton.outline(
                    onPressed: _setNine,
                    child: const Text('09:00'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: DpSpacing.sm),
                Expanded(
                  child: ShadButton(
                    onPressed: () {
                      final minutes = _hour * 60 + _minute;
                      Navigator.of(context).pop(minutes);
                    },
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
