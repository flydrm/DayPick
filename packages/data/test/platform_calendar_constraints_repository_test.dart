import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformCalendarConstraintsRepository', () {
    const channel = MethodChannel('daypick/calendar_constraints');
    var getTitledEventsCalls = 0;

    setUp(() async {
      getTitledEventsCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getPermissionState':
            return 'granted';
          case 'requestPermission':
            return 'granted';
          case 'getBusyIntervals':
            return [
              {'start_ms': DateTime(2026, 1, 30, 9).millisecondsSinceEpoch, 'end_ms': DateTime(2026, 1, 30, 10).millisecondsSinceEpoch},
              {'start_ms': DateTime(2026, 1, 30, 9, 30).millisecondsSinceEpoch, 'end_ms': DateTime(2026, 1, 30, 11).millisecondsSinceEpoch},
            ];
          case 'getTitledEvents':
            getTitledEventsCalls++;
            return [
              {
                'start_ms': DateTime(2026, 1, 30, 9).millisecondsSinceEpoch,
                'end_ms': DateTime(2026, 1, 30, 9, 30).millisecondsSinceEpoch,
                'title': 'Standup',
              },
              {
                'start_ms': DateTime(2026, 1, 30, 10).millisecondsSinceEpoch,
                'end_ms': DateTime(2026, 1, 30, 11).millisecondsSinceEpoch,
                'title': null,
              },
            ];
          default:
            throw PlatformException(code: 'unimplemented', message: call.method);
        }
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns merged busy intervals and free slots', () async {
      final repo = data.PlatformCalendarConstraintsRepository();
      final summary = await repo.getBusyFreeSummaryForDay(
        dayLocal: DateTime(2026, 1, 30),
      );
      expect(summary.dayKey, '2026-01-30');
      expect(
        summary.busyIntervals.map((b) => (b.startMinute, b.endMinute)).toList(),
        [(540, 660)],
      );
      expect(summary.freeSlotsCount, 2);
    });

    test('permission state mapping', () async {
      final repo = data.PlatformCalendarConstraintsRepository();
      final state = await repo.getPermissionState();
      expect(state, domain.CalendarPermissionState.granted);
    });

    test('returns titled events', () async {
      final repo = data.PlatformCalendarConstraintsRepository(
        isTitleReadEnabled: () => true,
      );
      final events = await repo.getTitledEventsForDay(
        dayLocal: DateTime(2026, 1, 30),
      );
      expect(getTitledEventsCalls, 1);
      expect(events.length, 2);
      expect(events[0].title, 'Standup');
      expect(events[1].title, '');
    });

    test('does not read titles when disabled', () async {
      final repo = data.PlatformCalendarConstraintsRepository(
        isTitleReadEnabled: () => false,
      );
      final events = await repo.getTitledEventsForDay(
        dayLocal: DateTime(2026, 1, 30),
      );
      expect(events, isEmpty);
      expect(getTitledEventsCalls, 0);
    });

    test('does not call titled events when summarizing busy/free', () async {
      final repo = data.PlatformCalendarConstraintsRepository();
      await repo.getBusyFreeSummaryForDay(dayLocal: DateTime(2026, 1, 30));
      expect(getTitledEventsCalls, 0);
    });
  });
}
