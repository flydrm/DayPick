import '../db/app_database.dart';

class DataMaintenanceService {
  DataMaintenanceService(this._db);

  final AppDatabase _db;

  Future<void> clearAllData() async {
    await _db.transaction(() async {
      await (_db.delete(_db.taskCheckItems)).go();
      await (_db.delete(_db.pomodoroSessions)).go();
      await (_db.delete(_db.weaveLinks)).go();
      await (_db.delete(_db.notes)).go();
      await (_db.delete(_db.todayPlanItems)).go();
      await (_db.delete(_db.tasks)).go();
      await (_db.delete(_db.activePomodoros)).go();
      await (_db.delete(_db.pomodoroConfigs)).go();
      await (_db.delete(_db.appearanceConfigs)).go();
    });
  }
}
