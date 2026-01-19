import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens/dp_spacing.dart';

class DatePickerSheet extends StatefulWidget {
  const DatePickerSheet({
    super.key,
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<DatePickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = _dateOnly(widget.initialDate);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSelectable(DateTime date) {
    final d = _dateOnly(date);
    final first = _dateOnly(widget.firstDate);
    final last = _dateOnly(widget.lastDate);
    return !d.isBefore(first) && !d.isAfter(last);
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
                ShadButton.ghost(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.md),
            ShadCalendar(
              selected: _selected,
              initialMonth: _selected,
              showOutsideDays: true,
              selectableDayPredicate: _isSelectable,
              onChanged: (date) {
                if (date == null) return;
                if (!_isSelectable(date)) return;
                setState(() => _selected = _dateOnly(date));
              },
            ),
            const SizedBox(height: DpSpacing.md),
            ShadButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}
