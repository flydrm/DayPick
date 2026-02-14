import 'package:domain/domain.dart' as domain;
import 'dart:convert';
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftAppearanceConfigRepository
    implements domain.AppearanceConfigRepository {
  DriftAppearanceConfigRepository(this._db);

  static const _singletonId = 1;

  final AppDatabase _db;

  @override
  Stream<domain.AppearanceConfig> watch() {
    final query = _db.select(_db.appearanceConfigs)
      ..where((t) => t.id.equals(_singletonId));
    return query.watchSingleOrNull().map(_toDomainOrDefault);
  }

  @override
  Future<domain.AppearanceConfig> get() async {
    final query = _db.select(_db.appearanceConfigs)
      ..where((t) => t.id.equals(_singletonId));
    final row = await query.getSingleOrNull();
    return _toDomainOrDefault(row);
  }

  @override
  Future<void> save(domain.AppearanceConfig config) async {
    final todayModulesJson = jsonEncode(
      config.todayModules.map((m) => m.name).toList(growable: false),
    );
    await _db
        .into(_db.appearanceConfigs)
        .insertOnConflictUpdate(
          AppearanceConfigsCompanion.insert(
            id: const Value(_singletonId),
            themeMode: Value(config.themeMode.index),
            density: Value(config.density.index),
            accent: Value(config.accent.index),
            defaultTab: Value(config.defaultTab.index),
            onboardingDone: Value(config.onboardingDone),
            statsEnabled: Value(config.statsEnabled),
            todayModulesJson: Value(todayModulesJson),
            timeboxingStartMinutes: Value(config.timeboxingStartMinutes),
            timeboxingLayout: Value(config.timeboxingLayout.index),
            timeboxingWorkdayStartMinutes: Value(
              config.timeboxingWorkdayStartMinutes,
            ),
            timeboxingWorkdayEndMinutes: Value(
              config.timeboxingWorkdayEndMinutes,
            ),
            calendarConstraintsDismissed: Value(config.calendarConstraintsDismissed),
            calendarShowEventTitles: Value(config.calendarShowEventTitles),
            inboxTypeFilter: Value(config.inboxTypeFilter.index),
            inboxTodayOnly: Value(config.inboxTodayOnly),
            updatedAtUtcMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<void> clear() async {
    await (_db.delete(
      _db.appearanceConfigs,
    )..where((t) => t.id.equals(_singletonId))).go();
  }

  domain.AppearanceConfig _toDomainOrDefault(AppearanceConfigRow? row) {
    if (row == null) return const domain.AppearanceConfig();

    final themeModeIndex = row.themeMode;
    final densityIndex = row.density;
    final accentIndex = row.accent;
    final defaultTabIndex = row.defaultTab;
    final onboardingDone = row.onboardingDone;
    final statsEnabled = row.statsEnabled;
    final todayModules = _parseTodayModules(row.todayModulesJson);
    final timeboxingStartMinutes = row.timeboxingStartMinutes;
    final timeboxingLayoutIndex = row.timeboxingLayout;
    final timeboxingWorkdayStartMinutes = row.timeboxingWorkdayStartMinutes;
    final timeboxingWorkdayEndMinutes = row.timeboxingWorkdayEndMinutes;
    final calendarConstraintsDismissed = row.calendarConstraintsDismissed;
    final calendarShowEventTitles = row.calendarShowEventTitles;
    final inboxTypeFilterIndex = row.inboxTypeFilter;
    final inboxTodayOnly = row.inboxTodayOnly;

    final themeMode =
        themeModeIndex >= 0 &&
            themeModeIndex < domain.AppThemeMode.values.length
        ? domain.AppThemeMode.values[themeModeIndex]
        : domain.AppThemeMode.system;

    final density =
        densityIndex >= 0 && densityIndex < domain.AppDensity.values.length
        ? domain.AppDensity.values[densityIndex]
        : domain.AppDensity.comfortable;

    final accent =
        accentIndex >= 0 && accentIndex < domain.AppAccent.values.length
        ? domain.AppAccent.values[accentIndex]
        : domain.AppAccent.a;

    final defaultTab =
        defaultTabIndex >= 0 &&
            defaultTabIndex < domain.AppDefaultTab.values.length
        ? domain.AppDefaultTab.values[defaultTabIndex]
        : domain.AppDefaultTab.today;

    final inboxTypeFilter =
        inboxTypeFilterIndex >= 0 &&
            inboxTypeFilterIndex < domain.InboxTypeFilter.values.length
        ? domain.InboxTypeFilter.values[inboxTypeFilterIndex]
        : domain.InboxTypeFilter.all;

    final timeboxingLayout =
        timeboxingLayoutIndex >= 0 &&
            timeboxingLayoutIndex < domain.TimeboxingLayout.values.length
        ? domain.TimeboxingLayout.values[timeboxingLayoutIndex]
        : domain.TimeboxingLayout.full;

    return domain.AppearanceConfig(
      themeMode: themeMode,
      density: density,
      accent: accent,
      defaultTab: defaultTab,
      onboardingDone: onboardingDone,
      statsEnabled: statsEnabled,
      todayModules: todayModules,
      timeboxingStartMinutes: timeboxingStartMinutes,
      timeboxingLayout: timeboxingLayout,
      timeboxingWorkdayStartMinutes: timeboxingWorkdayStartMinutes
          .clamp(0, 24 * 60 - 1)
          .toInt(),
      timeboxingWorkdayEndMinutes: timeboxingWorkdayEndMinutes
          .clamp(0, 24 * 60 - 1)
          .toInt(),
      calendarConstraintsDismissed: calendarConstraintsDismissed,
      calendarShowEventTitles: calendarShowEventTitles,
      inboxTypeFilter: inboxTypeFilter,
      inboxTodayOnly: inboxTodayOnly,
    );
  }

  List<domain.TodayWorkbenchModule> _parseTodayModules(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return domain.AppearanceConfig.defaultTodayModules;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return domain.AppearanceConfig.defaultTodayModules;

      const legacyDefault = [
        'quickAdd',
        'shortcuts',
        'budget',
        'focus',
        'nextStep',
        'todayPlan',
        'yesterdayReview',
      ];
      const previousDefault = [
        'nextStep',
        'todayPlan',
        'weave',
        'quickAdd',
        'budget',
        'focus',
        'shortcuts',
        'yesterdayReview',
      ];
      const oldDefault = [
        'nextStep',
        'todayPlan',
        'weave',
        'budget',
        'focus',
        'shortcuts',
        'yesterdayReview',
      ];
      const nextDefault = [
        'nextStep',
        'todayPlan',
        'capture',
        'weave',
        'budget',
        'focus',
        'shortcuts',
        'yesterdayReview',
      ];

      final decodedStrings = decoded.whereType<String>().toList();
      bool sameList(List<String> a, List<String> b) {
        if (a.length != b.length) return false;
        for (var i = 0; i < a.length; i++) {
          if (a[i] != b[i]) return false;
        }
        return true;
      }

      if (decodedStrings.length == decoded.length &&
          (sameList(decodedStrings, legacyDefault) ||
              sameList(decodedStrings, previousDefault) ||
              sameList(decodedStrings, oldDefault))) {
        return [
          for (final name in nextDefault)
            domain.TodayWorkbenchModule.values.firstWhere(
              (m) => m.name == name,
            ),
        ];
      }

      final found = <domain.TodayWorkbenchModule>[];
      for (final v in decoded) {
        if (v is! String) continue;
        if (v == 'quickAdd') continue;
        final match = domain.TodayWorkbenchModule.values
            .where((m) => m.name == v)
            .toList();
        if (match.isEmpty) continue;
        final module = match.first;
        if (!found.contains(module)) found.add(module);
      }
      return found.isEmpty
          ? domain.AppearanceConfig.defaultTodayModules
          : found;
    } catch (_) {
      return domain.AppearanceConfig.defaultTodayModules;
    }
  }
}
