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
import 'tables/weave_links.dart';

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
    WeaveLinks,
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
  int get schemaVersion => 15;

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
      }
      if (from < 5) {
        if (from >= 4) {
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.shortBreakMinutes,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.longBreakMinutes,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.longBreakEvery,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.autoStartBreak,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.autoStartFocus,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.notificationSound,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.notificationVibration,
          );
        }
        if (from >= 2) {
          await migrator.addColumn(activePomodoros, activePomodoros.phase);
        }
      }
      if (from < 6) {
        await migrator.createTable(todayPlanItems);
      }
      if (from < 7) {
        if (from >= 4) {
          await migrator.addColumn(appearanceConfigs, appearanceConfigs.accent);
        }
      }
      if (from < 8) {
        await migrator.addColumn(tasks, tasks.triageStatus);
        await migrator.addColumn(notes, notes.kind);
        await migrator.addColumn(notes, notes.triageStatus);
        await migrator.createTable(weaveLinks);
      }
      if (from < 9) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.defaultTab,
          );
        }
      }
      if (from < 10) {
        if (from >= 4) {
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.dailyBudgetPomodoros,
          );
        }
      }
      if (from < 11) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.statsEnabled,
          );
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.todayModulesJson,
          );
        }
      }
      if (from < 12) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.inboxTypeFilter,
          );
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.inboxTodayOnly,
          );
        }
      }
      if (from < 13) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.timeboxingStartMinutes,
          );
        }
      }
      if (from < 14) {
        if (from >= 2) {
          await migrator.addColumn(activePomodoros, activePomodoros.focusNote);
        }
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.timeboxingLayout,
          );
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.timeboxingWorkdayStartMinutes,
          );
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.timeboxingWorkdayEndMinutes,
          );
        }
        if (from >= 6) {
          await migrator.addColumn(todayPlanItems, todayPlanItems.segment);
        }
      }
      if (from < 15) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.onboardingDone,
          );
        }
      }
      await _ensureDefaultSingletons();
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
        dailyBudgetPomodoros: const Value(8),
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
        defaultTab: const Value(2),
        onboardingDone: const Value(false),
        statsEnabled: const Value(false),
        todayModulesJson: const Value(
          '["nextStep","todayPlan","capture","weave","budget","focus","shortcuts","yesterdayReview"]',
        ),
        inboxTypeFilter: const Value(0),
        inboxTodayOnly: const Value(false),
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
