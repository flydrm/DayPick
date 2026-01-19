import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftWeaveLinkRepository implements domain.WeaveLinkRepository {
  DriftWeaveLinkRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<domain.WeaveLink>> watchLinksByTargetNoteId(String targetNoteId) {
    final query =
        (_db.select(_db.weaveLinks)
            ..where((t) => t.targetNoteId.equals(targetNoteId)))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.createdAtUtcMillis,
              mode: OrderingMode.asc,
            ),
          ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<domain.WeaveLink>> watchLinksBySource({
    required domain.WeaveSourceType sourceType,
    required String sourceId,
  }) {
    final query =
        (_db.select(_db.weaveLinks)
            ..where((t) => t.sourceType.equals(sourceType.index))
            ..where((t) => t.sourceId.equals(sourceId)))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.createdAtUtcMillis,
              mode: OrderingMode.asc,
            ),
          ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<void> upsertLink(domain.WeaveLink link) async {
    await _db.into(_db.weaveLinks).insertOnConflictUpdate(_toCompanion(link));
  }

  @override
  Future<void> deleteLink(String linkId) async {
    await (_db.delete(_db.weaveLinks)..where((t) => t.id.equals(linkId))).go();
  }

  WeaveLinksCompanion _toCompanion(domain.WeaveLink link) {
    return WeaveLinksCompanion.insert(
      id: link.id,
      sourceType: link.sourceType.index,
      sourceId: link.sourceId,
      targetNoteId: link.targetNoteId,
      mode: Value(link.mode.index),
      createdAtUtcMillis: link.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAtUtcMillis: link.updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  domain.WeaveLink _toDomain(WeaveLinkRow row) {
    return domain.WeaveLink(
      id: row.id,
      sourceType: _decodeSourceType(row.sourceType),
      sourceId: row.sourceId,
      targetNoteId: row.targetNoteId,
      mode: _decodeMode(row.mode),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtUtcMillis,
        isUtc: true,
      ).toLocal(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtUtcMillis,
        isUtc: true,
      ).toLocal(),
    );
  }

  domain.WeaveSourceType _decodeSourceType(int value) {
    if (value < 0 || value >= domain.WeaveSourceType.values.length) {
      return domain.WeaveSourceType.note;
    }
    return domain.WeaveSourceType.values[value];
  }

  domain.WeaveMode _decodeMode(int value) {
    if (value < 0 || value >= domain.WeaveMode.values.length) {
      return domain.WeaveMode.reference;
    }
    return domain.WeaveMode.values[value];
  }
}
