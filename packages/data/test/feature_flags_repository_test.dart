import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'dart:ffi';

void main() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  test('feature flags repository roundtrips override + kill switch', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final repo = data.DriftFeatureFlagRepository(db);

    final seeds = [
      domain.FeatureFlag(
        key: 'a_flag',
        owner: 'test',
        expiryAt: DateTime.utc(2099, 1, 1),
        defaultValue: false,
        killSwitch: false,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ];

    await repo.ensureAllFlags(seeds);

    var all = await repo.getAllFlags();
    expect(all, hasLength(1));
    expect(all.single.key, 'a_flag');
    expect(all.single.overrideValue, isNull);
    expect(all.single.killSwitch, isFalse);

    await repo.setOverrideValue('a_flag', true);
    all = await repo.getAllFlags();
    expect(all.single.overrideValue, isTrue);

    await repo.setKillSwitch('a_flag', true);
    all = await repo.getAllFlags();
    expect(all.single.killSwitch, isTrue);
  });

  test('watchAllFlags returns flags sorted by key', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final repo = data.DriftFeatureFlagRepository(db);

    await repo.ensureAllFlags([
      domain.FeatureFlag(
        key: 'b_flag',
        owner: 'test',
        expiryAt: DateTime.utc(2099, 1, 1),
        defaultValue: false,
        killSwitch: false,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      domain.FeatureFlag(
        key: 'a_flag',
        owner: 'test',
        expiryAt: DateTime.utc(2099, 1, 1),
        defaultValue: false,
        killSwitch: false,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);

    final rows = await repo.watchAllFlags().first;
    expect([for (final r in rows) r.key], ['a_flag', 'b_flag']);
  });
}
