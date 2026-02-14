import '../../entities/calendar_busy_free_summary.dart';
import '../../entities/calendar_date_time_range.dart';

class CalendarBusyFreeCalculator {
  const CalendarBusyFreeCalculator();

  CalendarBusyFreeSummary summarize({
    required DateTime day,
    required Iterable<CalendarDateTimeRange> busyRangesLocal,
  }) {
    final dayStartLocal = DateTime(day.year, day.month, day.day);
    final dayEndLocal = dayStartLocal.add(const Duration(days: 1));

    int toMinute(DateTime t) => t.difference(dayStartLocal).inMinutes;

    final intervals = <CalendarBusyInterval>[];
    for (final range in busyRangesLocal) {
      final start = range.start.isBefore(dayStartLocal) ? dayStartLocal : range.start;
      final end = range.end.isAfter(dayEndLocal) ? dayEndLocal : range.end;
      final startMinute = toMinute(start).clamp(0, 24 * 60).toInt();
      final endMinute = toMinute(end).clamp(0, 24 * 60).toInt();
      if (endMinute <= startMinute) continue;
      intervals.add(
        CalendarBusyInterval(startMinute: startMinute, endMinute: endMinute),
      );
    }

    intervals.sort((a, b) => a.startMinute.compareTo(b.startMinute));

    final merged = <CalendarBusyInterval>[];
    for (final interval in intervals) {
      if (merged.isEmpty) {
        merged.add(interval);
        continue;
      }

      final last = merged.last;
      if (interval.startMinute <= last.endMinute) {
        merged[merged.length - 1] = CalendarBusyInterval(
          startMinute: last.startMinute,
          endMinute: interval.endMinute > last.endMinute
              ? interval.endMinute
              : last.endMinute,
        );
        continue;
      }

      merged.add(interval);
    }

    final freeSlotsCount = _countFreeSlots(merged);

    return CalendarBusyFreeSummary(
      dayKey: _formatDayKey(dayStartLocal),
      busyIntervals: merged,
      freeSlotsCount: freeSlotsCount,
    );
  }

  int _countFreeSlots(List<CalendarBusyInterval> busyIntervals) {
    if (busyIntervals.isEmpty) return 1;

    var slots = 0;
    var cursor = 0;
    for (final interval in busyIntervals) {
      if (interval.startMinute > cursor) slots++;
      if (interval.endMinute > cursor) cursor = interval.endMinute;
    }
    if (cursor < 24 * 60) slots++;
    return slots;
  }

  String _formatDayKey(DateTime dayStartLocal) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dayStartLocal.year}-${two(dayStartLocal.month)}-${two(dayStartLocal.day)}';
  }
}

