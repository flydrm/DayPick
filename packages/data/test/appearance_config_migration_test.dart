import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'dart:ffi';
import 'package:sqlite3/sqlite3.dart';

void main() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  test('migrates appearance config schema 10 → 15', () async {
    final rawDb = sqlite3.openInMemory();

    rawDb.execute('''
CREATE TABLE pomodoro_configs (
  id INTEGER NOT NULL PRIMARY KEY,
  work_duration_minutes INTEGER NOT NULL DEFAULT 25,
  short_break_minutes INTEGER NOT NULL DEFAULT 5,
  long_break_minutes INTEGER NOT NULL DEFAULT 15,
  long_break_every INTEGER NOT NULL DEFAULT 4,
  daily_budget_pomodoros INTEGER NOT NULL DEFAULT 8,
  auto_start_break INTEGER NOT NULL DEFAULT 0,
  auto_start_focus INTEGER NOT NULL DEFAULT 0,
  notification_sound INTEGER NOT NULL DEFAULT 0,
  notification_vibration INTEGER NOT NULL DEFAULT 0,
  updated_at_utc_millis INTEGER NOT NULL
);
''');

    rawDb.execute('''
CREATE TABLE appearance_configs (
  id INTEGER NOT NULL PRIMARY KEY,
  theme_mode INTEGER NOT NULL DEFAULT 0,
  density INTEGER NOT NULL DEFAULT 0,
  accent INTEGER NOT NULL DEFAULT 0,
  default_tab INTEGER NOT NULL DEFAULT 2,
  updated_at_utc_millis INTEGER NOT NULL
);
''');

    rawDb.execute('''
CREATE TABLE active_pomodoros (
  id INTEGER NOT NULL PRIMARY KEY,
  task_id TEXT NOT NULL,
  phase INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL,
  start_at_utc_millis INTEGER NOT NULL,
  end_at_utc_millis INTEGER NULL,
  remaining_ms INTEGER NULL,
  updated_at_utc_millis INTEGER NOT NULL
);
''');

    rawDb.execute('''
CREATE TABLE today_plan_items (
  day_key TEXT NOT NULL,
  task_id TEXT NOT NULL,
  order_index INTEGER NOT NULL,
  created_at_utc_millis INTEGER NOT NULL,
  updated_at_utc_millis INTEGER NOT NULL,
  PRIMARY KEY (day_key, task_id)
);
''');

    rawDb.execute('PRAGMA user_version = 10;');

    final db = data.AppDatabase.forTesting(NativeDatabase.opened(rawDb));
    addTearDown(() async => db.close());

    final columns = await db
        .customSelect("PRAGMA table_info('appearance_configs')")
        .get();
    final columnNames = columns.map((row) => row.read<String>('name')).toList();
    expect(columnNames, contains('stats_enabled'));
    expect(columnNames, contains('today_modules_json'));
    expect(columnNames, contains('timeboxing_start_minutes'));
    expect(columnNames, contains('timeboxing_layout'));
    expect(columnNames, contains('timeboxing_workday_start_minutes'));
    expect(columnNames, contains('timeboxing_workday_end_minutes'));
    expect(columnNames, contains('inbox_type_filter'));
    expect(columnNames, contains('inbox_today_only'));
    expect(columnNames, contains('onboarding_done'));

    final row = await (db.select(
      db.appearanceConfigs,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.onboardingDone, isFalse);
    expect(row.statsEnabled, isFalse);
    expect(row.todayModulesJson, isNot(contains('quickAdd')));
    expect(row.todayModulesJson, contains('nextStep'));
    expect(row.todayModulesJson, contains('todayPlan'));
    expect(row.todayModulesJson, contains('weave'));
    expect(row.inboxTypeFilter, 0);
    expect(row.inboxTodayOnly, isFalse);
    expect(row.timeboxingLayout, 0);
    expect(row.timeboxingWorkdayStartMinutes, 7 * 60);
    expect(row.timeboxingWorkdayEndMinutes, 21 * 60);
  });

  test('appearance config repository roundtrips stats + modules', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final repo = data.DriftAppearanceConfigRepository(db);
    final input = domain.AppearanceConfig(
      onboardingDone: true,
      statsEnabled: true,
      todayModules: const [
        domain.TodayWorkbenchModule.quickAdd,
        domain.TodayWorkbenchModule.nextStep,
        domain.TodayWorkbenchModule.stats,
      ],
      timeboxingStartMinutes: 9 * 60,
      timeboxingLayout: domain.TimeboxingLayout.minimal,
      timeboxingWorkdayStartMinutes: 8 * 60,
      timeboxingWorkdayEndMinutes: 20 * 60,
      inboxTypeFilter: domain.InboxTypeFilter.drafts,
      inboxTodayOnly: true,
    );

    await repo.save(input);
    final output = await repo.get();

    expect(output.onboardingDone, isTrue);
    expect(output.statsEnabled, isTrue);
    expect(output.todayModules, const [
      domain.TodayWorkbenchModule.nextStep,
      domain.TodayWorkbenchModule.stats,
    ]);
    expect(output.timeboxingStartMinutes, 9 * 60);
    expect(output.timeboxingLayout, domain.TimeboxingLayout.minimal);
    expect(output.timeboxingWorkdayStartMinutes, 8 * 60);
    expect(output.timeboxingWorkdayEndMinutes, 20 * 60);
    expect(output.inboxTypeFilter, domain.InboxTypeFilter.drafts);
    expect(output.inboxTodayOnly, isTrue);
  });
}
