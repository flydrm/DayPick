import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftPomodoroSessionRepository
    implements domain.PomodoroSessionRepository {
  DriftPomodoroSessionRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<domain.PomodoroSession>> watchBetween(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    final startUtc = startInclusive.toUtc().millisecondsSinceEpoch;
    final endUtc = endExclusive.toUtc().millisecondsSinceEpoch;
    final query =
        (_db.select(_db.pomodoroSessions)
            ..where((t) => t.endAtUtcMillis.isBiggerOrEqualValue(startUtc))
            ..where((t) => t.endAtUtcMillis.isSmallerThanValue(endUtc)))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.endAtUtcMillis,
              mode: OrderingMode.desc,
            ),
          ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<domain.PomodoroSession>> watchByTaskId(String taskId) {
    final query =
        (_db.select(_db.pomodoroSessions)
            ..where((t) => t.taskId.equals(taskId)))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.endAtUtcMillis,
              mode: OrderingMode.desc,
            ),
          ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<int> watchCountByTaskId(String taskId) {
    final query = _db.selectOnly(_db.pomodoroSessions)
      ..addColumns([_db.pomodoroSessions.id.count()])
      ..where(_db.pomodoroSessions.taskId.equals(taskId));
    return query.watchSingle().map(
      (row) => row.read(_db.pomodoroSessions.id.count()) ?? 0,
    );
  }

  @override
  Stream<int> watchCountBetween(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    final startUtc = startInclusive.toUtc().millisecondsSinceEpoch;
    final endUtc = endExclusive.toUtc().millisecondsSinceEpoch;
    final query = _db.selectOnly(_db.pomodoroSessions)
      ..addColumns([_db.pomodoroSessions.id.count()])
      ..where(
        _db.pomodoroSessions.endAtUtcMillis.isBiggerOrEqualValue(startUtc),
      )
      ..where(_db.pomodoroSessions.endAtUtcMillis.isSmallerThanValue(endUtc));
    return query.watchSingle().map(
      (row) => row.read(_db.pomodoroSessions.id.count()) ?? 0,
    );
  }

  @override
  Future<void> upsertSession(domain.PomodoroSession session) async {
    await _db
        .into(_db.pomodoroSessions)
        .insertOnConflictUpdate(
          PomodoroSessionsCompanion.insert(
            id: session.id,
            taskId: session.taskId,
            startAtUtcMillis: session.startAt.toUtc().millisecondsSinceEpoch,
            endAtUtcMillis: session.endAt.toUtc().millisecondsSinceEpoch,
            isDraft: Value(session.isDraft),
            progressNote: Value(session.progressNote),
            createdAtUtcMillis: session.createdAt
                .toUtc()
                .millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await (_db.delete(
      _db.pomodoroSessions,
    )..where((t) => t.id.equals(sessionId))).go();
  }

  domain.PomodoroSession _toDomain(PomodoroSessionRow row) {
    return domain.PomodoroSession(
      id: row.id,
      taskId: row.taskId,
      startAt: DateTime.fromMillisecondsSinceEpoch(
        row.startAtUtcMillis,
        isUtc: true,
      ).toLocal(),
      endAt: DateTime.fromMillisecondsSinceEpoch(
        row.endAtUtcMillis,
        isUtc: true,
      ).toLocal(),
      isDraft: row.isDraft,
      progressNote: row.progressNote,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtUtcMillis,
        isUtc: true,
      ).toLocal(),
    );
  }
}
