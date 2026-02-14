class LocalEventNames {
  // App / Session
  static const appLaunchStarted = 'app_launch_started';

  // Today / 3s clarity
  static const todayOpened = 'today_opened';
  static const todayFirstInteractive = 'today_first_interactive';
  static const primaryActionInvoked = 'primary_action_invoked';
  static const effectiveExecutionStateEntered = 'effective_execution_state_entered';
  static const todayClarityResult = 'today_clarity_result';
  static const fullscreenOpened = 'fullscreen_opened';
  static const tabSwitched = 'tab_switched';
  static const todayLeft = 'today_left';
  static const todayScrolled = 'today_scrolled';

  // Calendar / Permissions
  static const calendarPermissionPath = 'calendar_permission_path';

  // Capture / Inbox / Health
  static const captureSubmitted = 'capture_submitted';
  static const openInbox = 'open_inbox';
  static const inboxItemCreated = 'inbox_item_created';
  static const inboxItemProcessed = 'inbox_item_processed';
  static const inboxDailySnapshot = 'inbox_daily_snapshot';
  static const todayPlanOpened = 'today_plan_opened';

  // Journal / Review
  static const journalOpened = 'journal_opened';
  static const journalCompleted = 'journal_completed';

  // Export / Backup / Restore / Security
  static const exportStarted = 'export_started';
  static const exportCompleted = 'export_completed';
  static const backupCreated = 'backup_created';
  static const restoreStarted = 'restore_started';
  static const restoreCompleted = 'restore_completed';
  static const safeModeEntered = 'safe_mode_entered';

  static const all = <String>{
    appLaunchStarted,
    todayOpened,
    todayFirstInteractive,
    primaryActionInvoked,
    effectiveExecutionStateEntered,
    todayClarityResult,
    fullscreenOpened,
    tabSwitched,
    todayLeft,
    todayScrolled,
    calendarPermissionPath,
    captureSubmitted,
    openInbox,
    inboxItemCreated,
    inboxItemProcessed,
    inboxDailySnapshot,
    todayPlanOpened,
    journalOpened,
    journalCompleted,
    exportStarted,
    exportCompleted,
    backupCreated,
    restoreStarted,
    restoreCompleted,
    safeModeEntered,
  };
}
