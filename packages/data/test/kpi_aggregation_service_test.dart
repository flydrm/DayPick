import 'dart:convert';
import 'dart:ffi';

import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

void main() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  test('aggregateDay computes rollups and is idempotent', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final day = DateTime(2026, 1, 1);
    final now = DateTime(2026, 1, 9, 12, 0);

    final service = data.KpiAggregationService(
      db,
      sampleThreshold: 1,
      now: () => now,
    );

    final eventsRepo = data.DriftLocalEventsRepository(db);
    final noonUtcMs = day
        .add(const Duration(hours: 12))
        .toUtc()
        .millisecondsSinceEpoch;
    final day7UtcMs = day
        .add(const Duration(days: 7, hours: 12))
        .toUtc()
        .millisecondsSinceEpoch;

    Future<void> insertEvent({
      required String id,
      required String eventName,
      required int occurredAtUtcMs,
      required Map<String, Object?> metaJson,
    }) {
      return eventsRepo.insert(
        domain.LocalEvent(
          id: id,
          eventName: eventName,
          occurredAtUtcMs: occurredAtUtcMs,
          appVersion: '1.0.0+1',
          featureFlags: '[]',
          metaJson: metaJson,
        ),
      );
    }

    await insertEvent(
      id: 'e0',
      eventName: 'today_opened',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {'source': 'tab'},
    );
    await insertEvent(
      id: 'e1',
      eventName: 'today_clarity_result',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {'result': 'ok', 'elapsed_ms': 900},
    );
    await insertEvent(
      id: 'e2',
      eventName: 'primary_action_invoked',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {'action': 'open_inbox', 'elapsed_ms': 1200},
    );
    await insertEvent(
      id: 'e3',
      eventName: 'capture_submitted',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {'entry_kind': 'note', 'result': 'ok'},
    );
    await insertEvent(
      id: 'e4',
      eventName: 'today_plan_opened',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {'source': 'tab'},
    );
    await insertEvent(
      id: 'e5',
      eventName: 'journal_opened',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {'day_key': '2026-01-01', 'source': 'tab'},
    );
    await insertEvent(
      id: 'e6',
      eventName: 'journal_completed',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {
        'day_key': '2026-01-01',
        'answered_prompts_count': 3,
        'refs_count': 0,
        'has_text': false,
      },
    );
    await insertEvent(
      id: 'e7',
      eventName: 'app_launch_started',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {'cold_start': true, 'source': 'icon'},
    );
    await insertEvent(
      id: 'e8',
      eventName: 'inbox_item_created',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {'item_kind': 'task', 'source': 'capture'},
    );
    await insertEvent(
      id: 'e9',
      eventName: 'inbox_item_processed',
      occurredAtUtcMs: noonUtcMs,
      metaJson: {'item_kind': 'task', 'action': 'archive', 'batch': false},
    );

    await insertEvent(
      id: 'e10',
      eventName: 'app_launch_started',
      occurredAtUtcMs: day7UtcMs,
      metaJson: {'cold_start': true, 'source': 'icon'},
    );

    final nowUtcMs = DateTime(2026, 1, 1).toUtc().millisecondsSinceEpoch;
    await db
        .into(db.tasks)
        .insert(
          data.TasksCompanion.insert(
            id: 't-1',
            title: 'Inbox task',
            status: 0,
            priority: 0,
            triageStatus: const Value(0),
            createdAtUtcMillis: nowUtcMs,
            updatedAtUtcMillis: nowUtcMs,
          ),
        );
    await db
        .into(db.notes)
        .insert(
          data.NotesCompanion.insert(
            id: 'n-1',
            title: 'Inbox memo',
            triageStatus: const Value(0),
            createdAtUtcMillis: nowUtcMs,
            updatedAtUtcMillis: nowUtcMs,
          ),
        );

    await service.aggregateDay(dayLocal: day);
    await service.aggregateDay(dayLocal: day);

    final repo = data.DriftKpiRepository(db);
    final rollups = await repo.getByDayKeyRange(
      startDayKeyInclusive: '2026-01-01',
      endDayKeyInclusive: '2026-01-01',
    );
    expect(rollups, hasLength(2));

    final all = rollups.singleWhere((r) => r.segment == 'all');
    expect(all.dayKey, '2026-01-01');
    expect(all.sampleThreshold, 1);
    expect(all.computedAtUtcMs, now.toUtc().millisecondsSinceEpoch);

    expect(all.clarityOkCount, 1);
    expect(all.clarityTotalCount, 1);
    expect(all.clarityInsufficient, isFalse);
    expect(all.ttfaSampleCount, 1);
    expect(all.ttfaP50Ms, 1200);
    expect(all.ttfaP90Ms, 1200);

    expect(all.mainlineCompletedCount, 1);
    expect(all.mainlineInsufficient, isFalse);

    expect(all.journalOpenedCount, 1);
    expect(all.journalCompletedCount, 1);
    expect(all.journalInsufficient, isFalse);

    expect(all.activeDayCount, 1);
    expect(all.r7Retained, isTrue);
    expect(all.r7Insufficient, isFalse);

    expect(all.inboxPendingCount, 2);
    expect(all.inboxCreatedCount, 1);
    expect(all.inboxProcessedCount, 1);

    final seg = rollups.singleWhere((r) => r.segment == 'new');
    expect(seg.dayKey, '2026-01-01');
  });

  test('aggregateDay writes inbox_daily_snapshot and is idempotent', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final day = DateTime(2026, 1, 1);
    final now = DateTime(2026, 1, 9, 12, 0);

    final service = data.KpiAggregationService(
      db,
      sampleThreshold: 1,
      now: () => now,
    );

    final noonUtcMs = day
        .add(const Duration(hours: 12))
        .toUtc()
        .millisecondsSinceEpoch;
    await data.DriftLocalEventsRepository(db).insert(
      domain.LocalEvent(
        id: 'e0',
        eventName: 'app_launch_started',
        occurredAtUtcMs: noonUtcMs,
        appVersion: '1.0.0+1',
        featureFlags: '[]',
        metaJson: {'cold_start': true, 'source': 'icon'},
      ),
    );

    final nowUtcMs = DateTime(2026, 1, 1).toUtc().millisecondsSinceEpoch;
    await db
        .into(db.tasks)
        .insert(
          data.TasksCompanion.insert(
            id: 't-1',
            title: 'Inbox task',
            status: 0,
            priority: 0,
            triageStatus: const Value(0),
            createdAtUtcMillis: nowUtcMs,
            updatedAtUtcMillis: nowUtcMs,
          ),
        );
    await db
        .into(db.notes)
        .insert(
          data.NotesCompanion.insert(
            id: 'n-1',
            title: 'Inbox memo',
            triageStatus: const Value(0),
            createdAtUtcMillis: nowUtcMs,
            updatedAtUtcMillis: nowUtcMs,
          ),
        );

    await service.aggregateDay(dayLocal: day);
    await service.aggregateDay(dayLocal: day);

    final snapshots = await (db.select(
      db.localEvents,
    )..where((t) => t.eventName.equals('inbox_daily_snapshot'))).get();
    expect(snapshots, hasLength(1));

    final row = snapshots.single;
    expect(row.id, 'inbox_daily_snapshot:2026-01-01');

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    expect(row.occurredAtUtcMs, dayEnd.toUtc().millisecondsSinceEpoch - 1);

    final meta = jsonDecode(row.metaJson) as Map;
    expect(meta['day_key'], '2026-01-01');
    expect(meta['inbox_pending_count'], 2);
  });

  test(
    'aggregateDay reuses existing inbox_daily_snapshot count when recomputing',
    () async {
      final db = data.AppDatabase.inMemoryForTesting();
      addTearDown(() async => db.close());

      final day = DateTime(2026, 1, 1);
      final now = DateTime(2026, 1, 9, 12, 0);

      final service = data.KpiAggregationService(
        db,
        sampleThreshold: 1,
        now: () => now,
      );

      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      await data.DriftLocalEventsRepository(db).insert(
        domain.LocalEvent(
          id: 'inbox_daily_snapshot:2026-01-01',
          eventName: domain.LocalEventNames.inboxDailySnapshot,
          occurredAtUtcMs: dayEnd.toUtc().millisecondsSinceEpoch - 1,
          appVersion: '1.0.0+1',
          featureFlags: '[]',
          metaJson: const {'day_key': '2026-01-01', 'inbox_pending_count': 1},
        ),
      );

      final nowUtcMs = DateTime(2026, 1, 1).toUtc().millisecondsSinceEpoch;
      await db
          .into(db.tasks)
          .insert(
            data.TasksCompanion.insert(
              id: 't-1',
              title: 'Inbox task',
              status: 0,
              priority: 0,
              triageStatus: const Value(0),
              createdAtUtcMillis: nowUtcMs,
              updatedAtUtcMillis: nowUtcMs,
            ),
          );
      await db
          .into(db.notes)
          .insert(
            data.NotesCompanion.insert(
              id: 'n-1',
              title: 'Inbox memo',
              triageStatus: const Value(0),
              createdAtUtcMillis: nowUtcMs,
              updatedAtUtcMillis: nowUtcMs,
            ),
          );

      await service.aggregateDay(dayLocal: day);

      final rollup = (await data.DriftKpiRepository(db).getByDayKeyRange(
        startDayKeyInclusive: '2026-01-01',
        endDayKeyInclusive: '2026-01-01',
        segment: 'all',
      )).single;
      expect(rollup.inboxPendingCount, 1);

      final snapshotRow =
          await (db.select(db.localEvents)
                ..where((t) => t.id.equals('inbox_daily_snapshot:2026-01-01')))
              .getSingle();
      final meta = jsonDecode(snapshotRow.metaJson) as Map;
      expect(meta['inbox_pending_count'], 1);
    },
  );

  test('aggregateRecentDays backfills eligible R7 cohort day', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final now = DateTime(2026, 1, 9, 12, 0);
    final service = data.KpiAggregationService(
      db,
      sampleThreshold: 1,
      now: () => now,
    );

    final eventsRepo = data.DriftLocalEventsRepository(db);
    Future<void> insertLaunch({
      required String id,
      required DateTime dayLocal,
    }) async {
      final ts = DateTime(
        dayLocal.year,
        dayLocal.month,
        dayLocal.day,
      ).add(const Duration(hours: 12)).toUtc().millisecondsSinceEpoch;
      await eventsRepo.insert(
        domain.LocalEvent(
          id: id,
          eventName: domain.LocalEventNames.appLaunchStarted,
          occurredAtUtcMs: ts,
          appVersion: '1.0.0+1',
          featureFlags: '[]',
          metaJson: const {'cold_start': true, 'source': 'icon'},
        ),
      );
    }

    final cohortDay = DateTime(2026, 1, 1);
    await insertLaunch(id: 'cohort', dayLocal: cohortDay);
    await insertLaunch(id: 'day7', dayLocal: DateTime(2026, 1, 8));

    await service.aggregateRecentDays();

    final rollup = (await data.DriftKpiRepository(db).getByDayKeyRange(
      startDayKeyInclusive: '2026-01-01',
      endDayKeyInclusive: '2026-01-01',
      segment: 'all',
    )).single;
    expect(rollup.r7Insufficient, isFalse);
    expect(rollup.r7Retained, isTrue);
  });

  test('ttfa percentiles use nearest-rank', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final day = DateTime(2026, 1, 1);
    final now = DateTime(2026, 1, 20, 12, 0);

    final service = data.KpiAggregationService(
      db,
      sampleThreshold: 5,
      now: () => now,
    );

    final eventsRepo = data.DriftLocalEventsRepository(db);
    final noonUtcMs = day
        .add(const Duration(hours: 12))
        .toUtc()
        .millisecondsSinceEpoch;
    for (var i = 0; i < 5; i += 1) {
      final elapsed = [1, 2, 3, 4, 100][i];
      await eventsRepo.insert(
        domain.LocalEvent(
          id: 'p$i',
          eventName: 'primary_action_invoked',
          occurredAtUtcMs: noonUtcMs + i,
          appVersion: '1.0.0+1',
          featureFlags: '[]',
          metaJson: {'action': 'open_inbox', 'elapsed_ms': elapsed},
        ),
      );
    }

    await service.aggregateDay(dayLocal: day);

    final rollup = (await data.DriftKpiRepository(db).getByDayKeyRange(
      startDayKeyInclusive: '2026-01-01',
      endDayKeyInclusive: '2026-01-01',
      segment: 'all',
    )).single;

    expect(rollup.ttfaInsufficient, isFalse);
    expect(rollup.ttfaP50Ms, 3);
    expect(rollup.ttfaP90Ms, 100);
  });
}
