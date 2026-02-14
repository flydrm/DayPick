import 'dart:convert';
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

  test('json export includes kpi_daily_rollups', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final repo = data.DriftKpiRepository(db);
    await repo.upsert(
      const domain.KpiDailyRollup(
        dayKey: '2026-01-01',
        segment: 'all',
        segmentStrategy: 'by_onboarding_done',
        sampleThreshold: 5,
        computedAtUtcMs: 1000,
        clarityOkCount: 1,
        clarityTotalCount: 2,
        clarityInsufficient: true,
        clarityInsufficientReason: 'sample_lt_threshold',
        clarityFailureBucketCountsJson: '{"timeout":1}',
        ttfaSampleCount: 0,
        ttfaP50Ms: null,
        ttfaP90Ms: null,
        ttfaInsufficient: true,
        ttfaInsufficientReason: 'missing_event',
        mainlineCompletedCount: 0,
        mainlineInsufficient: true,
        mainlineInsufficientReason: 'missing_event',
        journalOpenedCount: 0,
        journalCompletedCount: 0,
        journalInsufficient: true,
        journalInsufficientReason: 'missing_event',
        activeDayCount: 0,
        r7Retained: null,
        r7Insufficient: true,
        r7InsufficientReason: 'not_yet_eligible',
        inboxPendingCount: 0,
        inboxCreatedCount: 0,
        inboxProcessedCount: 0,
      ),
    );

    final service = data.DataExportService(db);
    final jsonText = utf8.decode(await service.exportJsonBytes());
    final root = jsonDecode(jsonText);
    expect(root, isA<Map>());

    final schemaVersion = (root as Map)['schemaVersion'];
    expect(schemaVersion, data.DataExportService.exportSchemaVersion);

    final items = root['items'];
    expect(items, isA<Map>());
    final rollups = (items as Map)['kpi_daily_rollups'];
    expect(rollups, isA<List>());
    expect((rollups as List), hasLength(1));

    final rollup = rollups.single;
    expect(rollup, isA<Map>());
    expect((rollup as Map)['day_key'], '2026-01-01');
    expect(rollup['segment'], 'all');
    expect(rollup['clarity_insufficient'], isTrue);
    expect(rollup['r7_retained'], isNull);
  });
}
