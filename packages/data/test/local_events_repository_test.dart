import 'dart:ffi';

import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

void main() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  test('local events repository roundtrips insert + getAll', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final repo = data.DriftLocalEventsRepository(db);

    await repo.insert(
      domain.LocalEvent(
        id: 'a',
        eventName: 'today_opened',
        occurredAtUtcMs: 1,
        appVersion: '1.0.0+1',
        featureFlags: '[]',
        metaJson: {'source': 'tab'},
      ),
    );

    await repo.insert(
      domain.LocalEvent(
        id: 'b',
        eventName: 'today_opened',
        occurredAtUtcMs: 2,
        appVersion: '1.0.0+1',
        featureFlags: '[]',
        metaJson: {'source': 'tab'},
      ),
    );

    final all = await repo.getAll();
    expect([for (final e in all) e.id], ['a', 'b']);
  });

  test('prune deletes old events and trims to maxEvents', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final repo = data.DriftLocalEventsRepository(db);

    for (var i = 0; i < 10; i++) {
      await repo.insert(
        domain.LocalEvent(
          id: 'e$i',
          eventName: 'today_opened',
          occurredAtUtcMs: i,
          appVersion: '1.0.0+1',
          featureFlags: '[]',
          metaJson: {'source': 'tab'},
        ),
      );
    }

    await repo.prune(minOccurredAtUtcMs: 0, maxEvents: 5);

    final all = await repo.getAll();
    expect(all, hasLength(5));
    expect([for (final e in all) e.id], ['e5', 'e6', 'e7', 'e8', 'e9']);
  });

  test(
    'getBetween returns events filtered by time range and event name',
    () async {
      final db = data.AppDatabase.inMemoryForTesting();
      addTearDown(() async => db.close());

      final repo = data.DriftLocalEventsRepository(db);

      await repo.insert(
        domain.LocalEvent(
          id: 'a',
          eventName: 'today_opened',
          occurredAtUtcMs: 100,
          appVersion: '1.0.0+1',
          featureFlags: '[]',
          metaJson: {'source': 'tab'},
        ),
      );
      await repo.insert(
        domain.LocalEvent(
          id: 'b',
          eventName: 'capture_submitted',
          occurredAtUtcMs: 110,
          appVersion: '1.0.0+1',
          featureFlags: '[]',
          metaJson: {'entry_kind': 'note', 'result': 'ok'},
        ),
      );
      await repo.insert(
        domain.LocalEvent(
          id: 'c',
          eventName: 'today_opened',
          occurredAtUtcMs: 120,
          appVersion: '1.0.0+1',
          featureFlags: '[]',
          metaJson: {'source': 'tab'},
        ),
      );

      final hits = await repo.getBetween(
        minOccurredAtUtcMsInclusive: 105,
        maxOccurredAtUtcMsExclusive: 200,
        eventNames: ['today_opened'],
      );
      expect([for (final e in hits) e.id], ['c']);
    },
  );

  test('prune trims large event sets without sqlite variable limits', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final repo = data.DriftLocalEventsRepository(db);

    const total = 1500;
    const maxEvents = 10;
    for (var i = 0; i < total; i++) {
      await repo.insert(
        domain.LocalEvent(
          id: 'e$i',
          eventName: 'today_opened',
          occurredAtUtcMs: i,
          appVersion: '1.0.0+1',
          featureFlags: '[]',
          metaJson: {'source': 'tab'},
        ),
      );
    }

    await repo.prune(minOccurredAtUtcMs: 0, maxEvents: maxEvents);

    final all = await repo.getAll();
    expect(all, hasLength(maxEvents));
    final expectedIds = [for (var i = total - maxEvents; i < total; i++) 'e$i'];
    expect([for (final e in all) e.id], expectedIds);
  });
}
