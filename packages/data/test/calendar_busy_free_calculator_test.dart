import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

DateTime _day(int year, int month, int day) => DateTime(year, month, day);

domain.CalendarDateTimeRange _range(DateTime start, DateTime end) =>
    domain.CalendarDateTimeRange(start: start, end: end);

void main() {
  group('CalendarBusyFreeCalculator', () {
    test('merges overlaps and adjacency, clamps to day boundary', () {
      final day = _day(2026, 1, 30);
      final ranges = [
        _range(DateTime(2026, 1, 30, 9, 0), DateTime(2026, 1, 30, 10, 0)),
        _range(DateTime(2026, 1, 30, 9, 30), DateTime(2026, 1, 30, 11, 0)),
        _range(DateTime(2026, 1, 30, 11, 0), DateTime(2026, 1, 30, 11, 30)),
        _range(DateTime(2026, 1, 29, 23, 0), DateTime(2026, 1, 30, 1, 0)),
      ];

      final summary = const domain.CalendarBusyFreeCalculator().summarize(
        day: day,
        busyRangesLocal: ranges,
      );

      expect(summary.dayKey, '2026-01-30');
      expect(
        summary.busyIntervals.map((b) => (b.startMinute, b.endMinute)).toList(),
        [
          (0, 60),
          (540, 690),
        ],
      );
      expect(summary.freeSlotsCount, 2);
    });

    test('empty ranges yields 1 free slot (whole day)', () {
      final summary = const domain.CalendarBusyFreeCalculator().summarize(
        day: _day(2026, 1, 30),
        busyRangesLocal: const [],
      );
      expect(summary.busyIntervals, isEmpty);
      expect(summary.freeSlotsCount, 1);
    });

    test('full-day busy yields 0 free slots', () {
      final day = _day(2026, 1, 30);
      final summary = const domain.CalendarBusyFreeCalculator().summarize(
        day: day,
        busyRangesLocal: [
          _range(DateTime(2026, 1, 30, 0, 0), DateTime(2026, 1, 31, 0, 0)),
        ],
      );
      expect(
        summary.busyIntervals.map((b) => (b.startMinute, b.endMinute)).toList(),
        [(0, 1440)],
      );
      expect(summary.freeSlotsCount, 0);
    });

    test('counts free slots between busy segments', () {
      final day = _day(2026, 1, 30);
      final summary = const domain.CalendarBusyFreeCalculator().summarize(
        day: day,
        busyRangesLocal: [
          _range(DateTime(2026, 1, 30, 1, 0), DateTime(2026, 1, 30, 2, 0)),
          _range(DateTime(2026, 1, 30, 3, 0), DateTime(2026, 1, 30, 4, 0)),
        ],
      );
      expect(summary.freeSlotsCount, 3);
    });
  });
}

