import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/task_check_items.dart';
import 'tables/tasks.dart';
import 'tables/active_pomodoros.dart';
import 'tables/pomodoro_sessions.dart';
import 'tables/notes.dart';
import 'tables/pomodoro_configs.dart';
import 'tables/appearance_configs.dart';
import 'tables/today_plan_items.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Tasks,
    TaskCheckItems,
    ActivePomodoros,
    PomodoroSessions,
    Notes,
    PomodoroConfigs,
    AppearanceConfigs,
    TodayPlanItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  static AppDatabase inMemoryForTesting() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return AppDatabase.forTesting(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await _ensureDefaultSingletons();
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(activePomodoros);
            await migrator.createTable(pomodoroSessions);
          }
          if (from < 3) {
            await migrator.createTable(notes);
          }
          if (from < 4) {
            await migrator.createTable(pomodoroConfigs);
            await migrator.createTable(appearanceConfigs);
            await _ensureDefaultSingletons();
          }
          if (from < 5) {
            if (from >= 4) {
              await migrator.addColumn(pomodoroConfigs, pomodoroConfigs.shortBreakMinutes);
              await migrator.addColumn(pomodoroConfigs, pomodoroConfigs.longBreakMinutes);
              await migrator.addColumn(pomodoroConfigs, pomodoroConfigs.longBreakEvery);
              await migrator.addColumn(pomodoroConfigs, pomodoroConfigs.autoStartBreak);
              await migrator.addColumn(pomodoroConfigs, pomodoroConfigs.autoStartFocus);
              await migrator.addColumn(pomodoroConfigs, pomodoroConfigs.notificationSound);
              await migrator.addColumn(
                pomodoroConfigs,
                pomodoroConfigs.notificationVibration,
              );
            }
            if (from >= 2) {
              await migrator.addColumn(activePomodoros, activePomodoros.phase);
            }
            await _ensureDefaultSingletons();
          }
          if (from < 6) {
            await migrator.createTable(todayPlanItems);
          }
          if (from < 7) {
            if (from >= 4) {
              await migrator.addColumn(
                appearanceConfigs,
                appearanceConfigs.accent,
              );
            }
            await _ensureDefaultSingletons();
          }
        },
      );

  Future<void> _ensureDefaultSingletons() async {
    const singletonId = 1;
    await into(pomodoroConfigs).insert(
      PomodoroConfigsCompanion.insert(
        id: const Value(singletonId),
        workDurationMinutes: const Value(25),
        shortBreakMinutes: const Value(5),
        longBreakMinutes: const Value(15),
        longBreakEvery: const Value(4),
        autoStartBreak: const Value(false),
        autoStartFocus: const Value(false),
        notificationSound: const Value(false),
        notificationVibration: const Value(false),
        updatedAtUtcMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await into(appearanceConfigs).insert(
      AppearanceConfigsCompanion.insert(
        id: const Value(singletonId),
        themeMode: const Value(0),
        density: const Value(0),
        accent: const Value(0),
        updatedAtUtcMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final target = File(p.join(dbFolder.path, 'daypick.sqlite'));
    if (await target.exists()) return NativeDatabase(target);

    final sqliteFiles = await dbFolder
        .list()
        .where((e) => e is File && e.path.endsWith('.sqlite'))
        .map((e) => e as File)
        .toList();
    if (sqliteFiles.length == 1) {
      final existing = sqliteFiles.single;
      try {
        await existing.rename(target.path);
        return NativeDatabase(target);
      } catch (_) {
        return NativeDatabase(existing);
      }
    }

    return NativeDatabase(target);
  });
}
