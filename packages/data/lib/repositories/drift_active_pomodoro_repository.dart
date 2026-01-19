import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftActivePomodoroRepository implements domain.ActivePomodoroRepository {
  DriftActivePomodoroRepository(this._db);

  static const _singletonId = 1;

  final AppDatabase _db;

  @override
  Stream<domain.ActivePomodoro?> watch() {
    final query = _db.select(_db.activePomodoros)
      ..where((t) => t.id.equals(_singletonId));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  @override
  Future<domain.ActivePomodoro?> get() async {
    final query = _db.select(_db.activePomodoros)
      ..where((t) => t.id.equals(_singletonId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> upsert(domain.ActivePomodoro state) async {
    await _db
        .into(_db.activePomodoros)
        .insertOnConflictUpdate(
          ActivePomodorosCompanion.insert(
            id: const Value(_singletonId),
            taskId: state.taskId,
            phase: Value(state.phase.index),
            status: state.status.index,
            startAtUtcMillis: state.startAt.toUtc().millisecondsSinceEpoch,
            endAtUtcMillis: state.endAt == null
                ? const Value.absent()
                : Value(state.endAt!.toUtc().millisecondsSinceEpoch),
            remainingMs: state.remainingMs == null
                ? const Value.absent()
                : Value(state.remainingMs),
            focusNote: Value(state.focusNote),
            updatedAtUtcMillis: state.updatedAt.toUtc().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<void> clear() async {
    await (_db.delete(
      _db.activePomodoros,
    )..where((t) => t.id.equals(_singletonId))).go();
  }

  domain.ActivePomodoro _toDomain(ActivePomodoroRow row) {
    return domain.ActivePomodoro(
      taskId: row.taskId,
      phase: _phaseFromRow(row.phase),
      status: domain.ActivePomodoroStatus.values[row.status],
      startAt: DateTime.fromMillisecondsSinceEpoch(
        row.startAtUtcMillis,
        isUtc: true,
      ).toLocal(),
      endAt: row.endAtUtcMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row.endAtUtcMillis!,
              isUtc: true,
            ).toLocal(),
      remainingMs: row.remainingMs,
      focusNote: row.focusNote,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtUtcMillis,
        isUtc: true,
      ).toLocal(),
    );
  }

  domain.PomodoroPhase _phaseFromRow(int value) {
    if (value < 0 || value >= domain.PomodoroPhase.values.length) {
      return domain.PomodoroPhase.focus;
    }
    return domain.PomodoroPhase.values[value];
  }
}
