import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftPomodoroConfigRepository implements domain.PomodoroConfigRepository {
  DriftPomodoroConfigRepository(this._db);

  static const _singletonId = 1;

  final AppDatabase _db;

  @override
  Stream<domain.PomodoroConfig> watch() {
    final query = _db.select(_db.pomodoroConfigs)
      ..where((t) => t.id.equals(_singletonId));
    return query.watchSingleOrNull().map(_toDomainOrDefault);
  }

  @override
  Future<domain.PomodoroConfig> get() async {
    final query = _db.select(_db.pomodoroConfigs)
      ..where((t) => t.id.equals(_singletonId));
    final row = await query.getSingleOrNull();
    return _toDomainOrDefault(row);
  }

  @override
  Future<void> save(domain.PomodoroConfig config) async {
    await _db
        .into(_db.pomodoroConfigs)
        .insertOnConflictUpdate(
          PomodoroConfigsCompanion.insert(
            id: const Value(_singletonId),
            workDurationMinutes: Value(config.workDurationMinutes),
            shortBreakMinutes: Value(config.shortBreakMinutes),
            longBreakMinutes: Value(config.longBreakMinutes),
            longBreakEvery: Value(config.longBreakEvery),
            dailyBudgetPomodoros: Value(config.dailyBudgetPomodoros),
            autoStartBreak: Value(config.autoStartBreak),
            autoStartFocus: Value(config.autoStartFocus),
            notificationSound: Value(config.notificationSound),
            notificationVibration: Value(config.notificationVibration),
            updatedAtUtcMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<void> clear() async {
    await (_db.delete(
      _db.pomodoroConfigs,
    )..where((t) => t.id.equals(_singletonId))).go();
  }

  domain.PomodoroConfig _toDomainOrDefault(PomodoroConfigRow? row) {
    if (row == null) return const domain.PomodoroConfig();
    return domain.PomodoroConfig(
      workDurationMinutes: row.workDurationMinutes,
      shortBreakMinutes: row.shortBreakMinutes,
      longBreakMinutes: row.longBreakMinutes,
      longBreakEvery: row.longBreakEvery,
      dailyBudgetPomodoros: row.dailyBudgetPomodoros,
      autoStartBreak: row.autoStartBreak,
      autoStartFocus: row.autoStartFocus,
      notificationSound: row.notificationSound,
      notificationVibration: row.notificationVibration,
    );
  }
}
