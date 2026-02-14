import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftFeatureFlagRepository implements domain.FeatureFlagRepository {
  DriftFeatureFlagRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<domain.FeatureFlag>> watchAllFlags() {
    final query = _db.select(_db.featureFlags)
      ..orderBy([
        (t) => OrderingTerm(expression: t.key, mode: OrderingMode.asc),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<domain.FeatureFlag>> getAllFlags() async {
    final query = _db.select(_db.featureFlags)
      ..orderBy([
        (t) => OrderingTerm(expression: t.key, mode: OrderingMode.asc),
      ]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> ensureAllFlags(List<domain.FeatureFlag> seeds) async {
    if (seeds.isEmpty) return;

    await _db.transaction(() async {
      for (final seed in seeds) {
        final existing = await (_db.select(
          _db.featureFlags,
        )..where((t) => t.key.equals(seed.key))).getSingleOrNull();

        if (existing == null) {
          await _db
              .into(_db.featureFlags)
              .insert(_toCompanion(seed), mode: InsertMode.insert);
          continue;
        }

        await (_db.update(
          _db.featureFlags,
        )..where((t) => t.key.equals(seed.key))).write(
          FeatureFlagsCompanion(
            owner: Value(seed.owner),
            expiryAtUtcMillis: Value(
              seed.expiryAt.toUtc().millisecondsSinceEpoch,
            ),
            defaultValue: Value(seed.defaultValue),
          ),
        );
      }
    });
  }

  @override
  Future<void> setOverrideValue(String key, bool? value) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.featureFlags)..where((t) => t.key.equals(key))).write(
      FeatureFlagsCompanion(
        overrideValue: Value(value),
        updatedAtUtcMillis: Value(now),
      ),
    );
  }

  @override
  Future<void> setKillSwitch(String key, bool value) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.featureFlags)..where((t) => t.key.equals(key))).write(
      FeatureFlagsCompanion(
        killSwitch: Value(value),
        updatedAtUtcMillis: Value(now),
      ),
    );
  }

  FeatureFlagsCompanion _toCompanion(domain.FeatureFlag flag) {
    return FeatureFlagsCompanion.insert(
      key: flag.key,
      owner: flag.owner,
      expiryAtUtcMillis: flag.expiryAt.toUtc().millisecondsSinceEpoch,
      defaultValue: flag.defaultValue,
      killSwitch: Value(flag.killSwitch),
      overrideValue: Value(flag.overrideValue),
      updatedAtUtcMillis: flag.updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  domain.FeatureFlag _toDomain(FeatureFlagRow row) {
    return domain.FeatureFlag(
      key: row.key,
      owner: row.owner,
      expiryAt: DateTime.fromMillisecondsSinceEpoch(
        row.expiryAtUtcMillis,
        isUtc: true,
      ),
      defaultValue: row.defaultValue,
      killSwitch: row.killSwitch,
      overrideValue: row.overrideValue,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtUtcMillis,
        isUtc: true,
      ),
    );
  }
}
