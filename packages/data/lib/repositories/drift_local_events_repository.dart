import 'dart:convert';

import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftLocalEventsRepository implements domain.LocalEventsRepository {
  DriftLocalEventsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> insert(domain.LocalEvent event) async {
    await _db
        .into(_db.localEvents)
        .insert(
          LocalEventsCompanion.insert(
            id: event.id,
            eventName: event.eventName,
            occurredAtUtcMs: event.occurredAtUtcMs,
            appVersion: event.appVersion,
            featureFlags: event.featureFlags,
            metaJson: jsonEncode(event.metaJson),
          ),
          mode: InsertMode.insert,
        );
  }

  @override
  Future<List<domain.LocalEvent>> getAll({int? limit}) async {
    final query = _db.select(_db.localEvents)
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.occurredAtUtcMs, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<domain.LocalEvent>> getBetween({
    required int minOccurredAtUtcMsInclusive,
    required int maxOccurredAtUtcMsExclusive,
    List<String>? eventNames,
    int? limit,
  }) async {
    if (maxOccurredAtUtcMsExclusive <= minOccurredAtUtcMsInclusive) {
      return const [];
    }

    final query =
        (_db.select(_db.localEvents)..where(
            (t) =>
                t.occurredAtUtcMs.isBiggerOrEqualValue(
                  minOccurredAtUtcMsInclusive,
                ) &
                t.occurredAtUtcMs.isSmallerThanValue(
                  maxOccurredAtUtcMsExclusive,
                ),
          ))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.occurredAtUtcMs,
              mode: OrderingMode.asc,
            ),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc),
          ]);

    final effectiveEventNames = eventNames == null
        ? null
        : eventNames
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList(growable: false);
    if (effectiveEventNames != null && effectiveEventNames.isNotEmpty) {
      query.where((t) => t.eventName.isIn(effectiveEventNames));
    }
    if (limit != null) {
      query.limit(limit);
    }

    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> prune({
    required int minOccurredAtUtcMs,
    required int maxEvents,
  }) async {
    await _db.transaction(() async {
      if (minOccurredAtUtcMs > 0) {
        await (_db.delete(_db.localEvents)..where(
              (t) => t.occurredAtUtcMs.isSmallerThanValue(minOccurredAtUtcMs),
            ))
            .go();
      }

      if (maxEvents <= 0) {
        await (_db.delete(_db.localEvents)).go();
        return;
      }

      final countExp = _db.localEvents.id.count();
      final countQuery = _db.selectOnly(_db.localEvents)
        ..addColumns([countExp]);
      final row = await countQuery.getSingle();
      final total = row.read(countExp) ?? 0;
      if (total <= maxEvents) return;

      final toDelete = total - maxEvents;
      await _db.customStatement(
        'DELETE FROM local_events '
        'WHERE id IN ('
        '  SELECT id FROM local_events '
        '  ORDER BY occurred_at_utc_ms ASC, id ASC '
        '  LIMIT ?'
        ')',
        [toDelete],
      );
    });
  }

  domain.LocalEvent _toDomain(LocalEventRow row) {
    final decoded = jsonDecode(row.metaJson);
    final metaJson = decoded is Map<String, Object?>
        ? decoded
        : Map<String, Object?>.from(decoded as Map);

    return domain.LocalEvent(
      id: row.id,
      eventName: row.eventName,
      occurredAtUtcMs: row.occurredAtUtcMs,
      appVersion: row.appVersion,
      featureFlags: row.featureFlags,
      metaJson: metaJson,
    );
  }
}
