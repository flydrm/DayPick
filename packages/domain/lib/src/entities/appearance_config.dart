enum AppThemeMode { system, light, dark }

enum AppDensity { comfortable, compact }

enum AppAccent { a, b, c }

enum AppDefaultTab { ai, notes, today, tasks, focus }

enum InboxTypeFilter { all, tasks, memos, drafts }

enum TimeboxingLayout { full, minimal }

enum TodayWorkbenchModule {
  quickAdd,
  capture,
  weave,
  shortcuts,
  budget,
  focus,
  nextStep,
  todayPlan,
  timeboxing,
  yesterdayReview,
  stats,
}

class AppearanceConfig {
  static const List<TodayWorkbenchModule> defaultTodayModules = [
    TodayWorkbenchModule.nextStep,
    TodayWorkbenchModule.todayPlan,
    TodayWorkbenchModule.capture,
    TodayWorkbenchModule.weave,
    TodayWorkbenchModule.budget,
    TodayWorkbenchModule.focus,
    TodayWorkbenchModule.shortcuts,
    TodayWorkbenchModule.yesterdayReview,
  ];

  const AppearanceConfig({
    this.themeMode = AppThemeMode.system,
    this.density = AppDensity.comfortable,
    this.accent = AppAccent.a,
    this.defaultTab = AppDefaultTab.today,
    this.onboardingDone = false,
    this.statsEnabled = false,
    this.todayModules = defaultTodayModules,
    this.timeboxingStartMinutes,
    this.timeboxingLayout = TimeboxingLayout.full,
    this.timeboxingWorkdayStartMinutes = 7 * 60,
    this.timeboxingWorkdayEndMinutes = 21 * 60,
    this.inboxTypeFilter = InboxTypeFilter.all,
    this.inboxTodayOnly = false,
  });

  final AppThemeMode themeMode;
  final AppDensity density;
  final AppAccent accent;
  final AppDefaultTab defaultTab;
  final bool onboardingDone;
  final bool statsEnabled;
  final List<TodayWorkbenchModule> todayModules;
  final int? timeboxingStartMinutes;
  final TimeboxingLayout timeboxingLayout;
  final int timeboxingWorkdayStartMinutes;
  final int timeboxingWorkdayEndMinutes;
  final InboxTypeFilter inboxTypeFilter;
  final bool inboxTodayOnly;

  AppearanceConfig copyWith({
    AppThemeMode? themeMode,
    AppDensity? density,
    AppAccent? accent,
    AppDefaultTab? defaultTab,
    bool? onboardingDone,
    bool? statsEnabled,
    List<TodayWorkbenchModule>? todayModules,
    int? timeboxingStartMinutes,
    TimeboxingLayout? timeboxingLayout,
    int? timeboxingWorkdayStartMinutes,
    int? timeboxingWorkdayEndMinutes,
    InboxTypeFilter? inboxTypeFilter,
    bool? inboxTodayOnly,
  }) {
    return AppearanceConfig(
      themeMode: themeMode ?? this.themeMode,
      density: density ?? this.density,
      accent: accent ?? this.accent,
      defaultTab: defaultTab ?? this.defaultTab,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      statsEnabled: statsEnabled ?? this.statsEnabled,
      todayModules: todayModules ?? this.todayModules,
      timeboxingStartMinutes:
          timeboxingStartMinutes ?? this.timeboxingStartMinutes,
      timeboxingLayout: timeboxingLayout ?? this.timeboxingLayout,
      timeboxingWorkdayStartMinutes:
          timeboxingWorkdayStartMinutes ?? this.timeboxingWorkdayStartMinutes,
      timeboxingWorkdayEndMinutes:
          timeboxingWorkdayEndMinutes ?? this.timeboxingWorkdayEndMinutes,
      inboxTypeFilter: inboxTypeFilter ?? this.inboxTypeFilter,
      inboxTodayOnly: inboxTodayOnly ?? this.inboxTodayOnly,
    );
  }
}
