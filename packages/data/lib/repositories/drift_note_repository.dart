import 'dart:convert';

import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftNoteRepository implements domain.NoteRepository {
  DriftNoteRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<domain.Note>> watchAllNotes() {
    final query = _db.select(_db.notes)
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.updatedAtUtcMillis,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<domain.Note>> watchNotesByTaskId(String taskId) {
    final query = (_db.select(_db.notes)..where((t) => t.taskId.equals(taskId)))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.updatedAtUtcMillis,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<domain.Note>> watchMemos({bool includeArchived = false}) {
    final archivedIndex = domain.TriageStatus.archived.index;
    final query = _db.select(_db.notes)
      ..where((t) => t.kind.equals(domain.NoteKind.memo.index));
    if (!includeArchived) {
      query.where((t) => t.triageStatus.isNotIn([archivedIndex]));
    }
    query.orderBy([
      (t) => OrderingTerm(
        expression: t.updatedAtUtcMillis,
        mode: OrderingMode.desc,
      ),
    ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<domain.Note>> watchDrafts({bool includeArchived = false}) {
    final archivedIndex = domain.TriageStatus.archived.index;
    final query = _db.select(_db.notes)
      ..where((t) => t.kind.equals(domain.NoteKind.draft.index));
    if (!includeArchived) {
      query.where((t) => t.triageStatus.isNotIn([archivedIndex]));
    }
    query.orderBy([
      (t) => OrderingTerm(
        expression: t.updatedAtUtcMillis,
        mode: OrderingMode.desc,
      ),
    ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<domain.Note>> watchUnprocessedNotes() {
    final inboxIndex = domain.TriageStatus.inbox.index;
    final memoIndex = domain.NoteKind.memo.index;
    final draftIndex = domain.NoteKind.draft.index;
    final query = _db.select(_db.notes)
      ..where((t) => t.triageStatus.equals(inboxIndex))
      ..where((t) => t.kind.isIn([memoIndex, draftIndex]))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.updatedAtUtcMillis,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<domain.Note?> getNoteById(String noteId) async {
    final query = _db.select(_db.notes)..where((t) => t.id.equals(noteId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> upsertNote(domain.Note note) async {
    await _db.into(_db.notes).insertOnConflictUpdate(_toCompanion(note));
  }

  @override
  Future<void> deleteNote(String noteId) async {
    await (_db.delete(_db.notes)..where((t) => t.id.equals(noteId))).go();
  }

  NotesCompanion _toCompanion(domain.Note note) {
    return NotesCompanion.insert(
      id: note.id,
      title: note.title.value,
      body: Value(note.body),
      tagsJson: Value(jsonEncode(note.tags)),
      taskId: Value(note.taskId),
      kind: Value(note.kind.index),
      triageStatus: Value(note.triageStatus.index),
      createdAtUtcMillis: note.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAtUtcMillis: note.updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  domain.Note _toDomain(NoteRow row) {
    return domain.Note(
      id: row.id,
      title: domain.NoteTitle(row.title),
      body: row.body,
      tags: _decodeTags(row.tagsJson),
      taskId: row.taskId,
      kind: _decodeNoteKind(row.kind),
      triageStatus: _decodeTriageStatus(row.triageStatus),
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

  domain.NoteKind _decodeNoteKind(int value) {
    if (value < 0 || value >= domain.NoteKind.values.length) {
      return domain.NoteKind.longform;
    }
    return domain.NoteKind.values[value];
  }

  domain.TriageStatus _decodeTriageStatus(int value) {
    if (value < 0 || value >= domain.TriageStatus.values.length) {
      return domain.TriageStatus.scheduledLater;
    }
    return domain.TriageStatus.values[value];
  }

  List<String> _decodeTags(String tagsJson) {
    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return const [];
  }
}
