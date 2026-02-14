import 'package:daypick/core/local_events/local_events_guard.dart';
import 'package:daypick/core/local_events/local_events_service.dart';
import 'package:daypick/features/today/providers/calendar_constraints_providers.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_appearance_config_repository.dart';

class _InMemoryLocalEventsRepository implements domain.LocalEventsRepository {
  final List<domain.LocalEvent> events = <domain.LocalEvent>[];

  @override
  Future<void> insert(domain.LocalEvent event) async {
    events.add(event);
  }

  @override
  Future<List<domain.LocalEvent>> getAll({int? limit}) async {
    final items = List<domain.LocalEvent>.from(events);
    return limit == null ? items : items.take(limit).toList();
  }

  @override
  Future<List<domain.LocalEvent>> getBetween({
    required int minOccurredAtUtcMsInclusive,
    required int maxOccurredAtUtcMsExclusive,
    List<String>? eventNames,
    int? limit,
  }) async {
    var items = events.where((e) {
      final inRange =
          e.occurredAtUtcMs >= minOccurredAtUtcMsInclusive &&
          e.occurredAtUtcMs < maxOccurredAtUtcMsExclusive;
      if (!inRange) return false;
      if (eventNames == null) return true;
      return eventNames.contains(e.eventName);
    }).toList();

    if (limit != null) items = items.take(limit).toList();
    return items;
  }

  @override
  Future<void> prune({required int minOccurredAtUtcMs, required int maxEvents}) async {}
}

class _FixedPermissionCalendarConstraintsRepository
    implements domain.CalendarConstraintsRepository {
  _FixedPermissionCalendarConstraintsRepository(this.permissionState);

  @override
  Future<domain.CalendarPermissionState> getPermissionState() async {
    return permissionState;
  }

  @override
  Future<domain.CalendarPermissionState> requestPermission() async {
    return permissionState;
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<domain.CalendarBusyFreeSummary> getBusyFreeSummaryForDay({
    required DateTime dayLocal,
  }) async {
    return const domain.CalendarBusyFreeCalculator().summarize(
      day: DateTime(2026, 1, 1),
      busyRangesLocal: const [],
    );
  }

  @override
  Future<List<domain.CalendarTitledEvent>> getTitledEventsForDay({
    required DateTime dayLocal,
  }) async {
    return const [];
  }

  @override
  Future<domain.CalendarBusyFreeSummary> computeBusyFreeSummary({
    required DateTime dayLocal,
    required List<domain.CalendarDateTimeRange> busyRangesLocal,
  }) async {
    return const domain.CalendarBusyFreeCalculator().summarize(
      day: dayLocal,
      busyRangesLocal: busyRangesLocal,
    );
  }

  final domain.CalendarPermissionState permissionState;
}

void main() {
  test('calendar_permission_path: permission state values are snake_case', () async {
    final eventsRepo = _InMemoryLocalEventsRepository();
    final localEvents = LocalEventsService(
      repository: eventsRepo,
      guard: LocalEventsGuard(),
      generateId: () => 'id',
      nowUtcMs: () => 123,
      appVersion: () => '1.0.0+1',
      featureFlagsSnapshot: () => '',
    );

    final appearanceRepo = FakeAppearanceConfigRepository(
      const domain.AppearanceConfig(onboardingDone: true),
    );
    addTearDown(appearanceRepo.dispose);

    final controller = CalendarConstraintsController(
      repository: _FixedPermissionCalendarConstraintsRepository(
        domain.CalendarPermissionState.notSupported,
      ),
      appearanceRepository: appearanceRepo,
      localEvents: localEvents,
    );

    await controller.refresh();
    await controller.skip();
    await Future<void>.delayed(Duration.zero);

    final last = eventsRepo.events.last;
    expect(last.eventName, domain.LocalEventNames.calendarPermissionPath);
    expect(last.metaJson['action'], 'skip');
    expect(last.metaJson['state'], 'not_supported');
  });
}
