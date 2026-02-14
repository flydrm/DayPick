import 'package:daypick/core/local_events/local_events_guard.dart';
import 'package:daypick/core/local_events/local_events_service.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('record injects envelope fields and writes via repository', () async {
    final repo = _CapturingLocalEventsRepository();
    final guard = LocalEventsGuard();
    final service = LocalEventsService(
      repository: repo,
      guard: guard,
      generateId: () => 'event-id',
      nowUtcMs: () => 100000000,
      appVersion: () => '1.0.0+1',
      featureFlagsSnapshot: () => 'flags-snapshot',
      retentionDays: 1,
      maxEvents: 7,
    );

    final ok = await service.record(
      eventName: domain.LocalEventNames.todayOpened,
      metaJson: {'source': 'tab'},
    );

    expect(ok, isTrue);
    expect(repo.events, hasLength(1));
    final e = repo.events.single;
    expect(e.id, 'event-id');
    expect(e.eventName, domain.LocalEventNames.todayOpened);
    expect(e.occurredAtUtcMs, 100000000);
    expect(e.appVersion, '1.0.0+1');
    expect(e.featureFlags, 'flags-snapshot');
    expect(e.metaJson, {'source': 'tab'});

    expect(repo.pruneCalls, hasLength(1));
    expect(repo.pruneCalls.single.minOccurredAtUtcMs, 13600000);
    expect(repo.pruneCalls.single.maxEvents, 7);
  });

  test('record returns false and does not write when guard rejects', () async {
    final repo = _CapturingLocalEventsRepository();
    final guard = LocalEventsGuard();
    final service = LocalEventsService(
      repository: repo,
      guard: guard,
      generateId: () => 'event-id',
      nowUtcMs: () => 123,
      appVersion: () => '1.0.0+1',
      featureFlagsSnapshot: () => 'flags-snapshot',
    );

    final ok = await service.record(
      eventName: domain.LocalEventNames.todayOpened,
      metaJson: {'title': 'secret'},
    );

    expect(ok, isFalse);
    expect(repo.events, isEmpty);
    expect(repo.pruneCalls, isEmpty);
  });

  test('record returns false when repository throws', () async {
    final repo = _ThrowingLocalEventsRepository();
    final guard = LocalEventsGuard();
    final service = LocalEventsService(
      repository: repo,
      guard: guard,
      generateId: () => 'event-id',
      nowUtcMs: () => 123,
      appVersion: () => '1.0.0+1',
      featureFlagsSnapshot: () => 'flags-snapshot',
    );

    final ok = await service.record(
      eventName: domain.LocalEventNames.todayOpened,
      metaJson: {'source': 'tab'},
    );

    expect(ok, isFalse);
  });
}

class _PruneCall {
  const _PruneCall({required this.minOccurredAtUtcMs, required this.maxEvents});

  final int minOccurredAtUtcMs;
  final int maxEvents;
}

class _CapturingLocalEventsRepository implements domain.LocalEventsRepository {
  final events = <domain.LocalEvent>[];
  final pruneCalls = <_PruneCall>[];

  @override
  Future<void> insert(domain.LocalEvent event) async {
    events.add(event);
  }

  @override
  Future<List<domain.LocalEvent>> getAll({int? limit}) async {
    final all = List<domain.LocalEvent>.from(events);
    if (limit == null) return all;
    return all.take(limit).toList();
  }

  @override
  Future<List<domain.LocalEvent>> getBetween({
    required int minOccurredAtUtcMsInclusive,
    required int maxOccurredAtUtcMsExclusive,
    List<String>? eventNames,
    int? limit,
  }) async {
    final names = eventNames?.toSet();
    final hits = events
        .where(
          (e) =>
              e.occurredAtUtcMs >= minOccurredAtUtcMsInclusive &&
              e.occurredAtUtcMs < maxOccurredAtUtcMsExclusive,
        )
        .where((e) => names?.contains(e.eventName) ?? true)
        .toList();
    if (limit == null) return hits;
    return hits.take(limit).toList();
  }

  @override
  Future<void> prune({
    required int minOccurredAtUtcMs,
    required int maxEvents,
  }) async {
    pruneCalls.add(
      _PruneCall(minOccurredAtUtcMs: minOccurredAtUtcMs, maxEvents: maxEvents),
    );
  }
}

class _ThrowingLocalEventsRepository implements domain.LocalEventsRepository {
  @override
  Future<void> insert(domain.LocalEvent event) => Future.error('fail');

  @override
  Future<List<domain.LocalEvent>> getAll({int? limit}) => Future.error('fail');

  @override
  Future<List<domain.LocalEvent>> getBetween({
    required int minOccurredAtUtcMsInclusive,
    required int maxOccurredAtUtcMsExclusive,
    List<String>? eventNames,
    int? limit,
  }) => Future.error('fail');

  @override
  Future<void> prune({
    required int minOccurredAtUtcMs,
    required int maxEvents,
  }) => Future.error('fail');
}
