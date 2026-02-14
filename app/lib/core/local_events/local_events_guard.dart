import 'dart:convert';

import 'package:domain/domain.dart' as domain;

class LocalEventsGuardResult {
  const LocalEventsGuardResult._({required this.ok, required this.reason});

  final bool ok;
  final String? reason;

  static const okResult = LocalEventsGuardResult._(ok: true, reason: null);

  static LocalEventsGuardResult reject(String reason) =>
      LocalEventsGuardResult._(ok: false, reason: reason);
}

class LocalEventsGuard {
  static const int _maxMetaJsonBytes = 1024;
  static const int _maxStringLength = 200;
  static const int _maxStringListLength = 20;

  static const Set<String> _banlistKeysLower = {
    'title',
    'body',
    'content',
    'description',
    'prompt',
    'response',
    'api_key',
    'apikey',
  };

  static const Map<String, Set<String>> _metaAllowlistByEventName = {
    domain.LocalEventNames.appLaunchStarted: {'cold_start', 'source'},
    domain.LocalEventNames.todayOpened: {'source'},
    domain.LocalEventNames.todayFirstInteractive: {'elapsed_ms', 'segment'},
    domain.LocalEventNames.primaryActionInvoked: {'action', 'elapsed_ms'},
    domain.LocalEventNames.effectiveExecutionStateEntered: {'source', 'kind'},
    domain.LocalEventNames.todayClarityResult: {
      'result',
      'elapsed_ms',
      'failure_bucket',
      'failure_flags',
    },
    domain.LocalEventNames.fullscreenOpened: {'screen', 'reason'},
    domain.LocalEventNames.tabSwitched: {'from_tab', 'to_tab'},
    domain.LocalEventNames.todayLeft: {'destination'},
    domain.LocalEventNames.todayScrolled: {'delta_px'},
    domain.LocalEventNames.calendarPermissionPath: {'action', 'result', 'state'},
    domain.LocalEventNames.captureSubmitted: {'entry_kind', 'result'},
    domain.LocalEventNames.openInbox: {'source'},
    domain.LocalEventNames.inboxItemCreated: {'item_kind', 'source'},
    domain.LocalEventNames.inboxItemProcessed: {'item_kind', 'action', 'batch'},
    domain.LocalEventNames.inboxDailySnapshot: {'day_key', 'inbox_pending_count'},
    domain.LocalEventNames.todayPlanOpened: {'source'},
    domain.LocalEventNames.journalOpened: {'day_key', 'source'},
    domain.LocalEventNames.journalCompleted: {
      'day_key',
      'answered_prompts_count',
      'refs_count',
      'has_text',
    },
    domain.LocalEventNames.exportStarted: {'format', 'result'},
    domain.LocalEventNames.exportCompleted: {'format', 'result'},
    domain.LocalEventNames.backupCreated: {'includes_secrets', 'result'},
    domain.LocalEventNames.restoreStarted: {'includes_secrets', 'result'},
    domain.LocalEventNames.restoreCompleted: {'includes_secrets', 'result'},
    domain.LocalEventNames.safeModeEntered: {'reason'},
  };

  LocalEventsGuardResult validate({
    required String eventName,
    required Map<String, Object?> metaJson,
  }) {
    final allowlist = _metaAllowlistByEventName[eventName];
    if (allowlist == null) {
      return LocalEventsGuardResult.reject('unknown_event_name');
    }

    for (final entry in metaJson.entries) {
      final key = entry.key;
      final value = entry.value;

      if (_banlistKeysLower.contains(key.toLowerCase())) {
        return LocalEventsGuardResult.reject('banlisted_key:$key');
      }

      if (!allowlist.contains(key)) {
        return LocalEventsGuardResult.reject('unknown_key:$key');
      }

      final valueResult = _validateValue(key: key, value: value);
      if (!valueResult.ok) return valueResult;
    }

    if (!_validateEncodedSize(metaJson)) {
      return LocalEventsGuardResult.reject('meta_json_too_large');
    }

    return LocalEventsGuardResult.okResult;
  }

  LocalEventsGuardResult _validateValue({
    required String key,
    required Object? value,
  }) {
    if (value == null) {
      return LocalEventsGuardResult.reject('null_value:$key');
    }

    if (value is String) {
      if (value.length > _maxStringLength) {
        return LocalEventsGuardResult.reject('string_too_long:$key');
      }
      return LocalEventsGuardResult.okResult;
    }

    if (value is int || value is double || value is bool) {
      return LocalEventsGuardResult.okResult;
    }

    if (value is List) {
      if (value.length > _maxStringListLength) {
        return LocalEventsGuardResult.reject('string_list_too_long:$key');
      }
      for (final element in value) {
        if (element is! String) {
          return LocalEventsGuardResult.reject('invalid_list_element_type:$key');
        }
        if (element.length > _maxStringLength) {
          return LocalEventsGuardResult.reject('string_too_long:$key');
        }
      }
      return LocalEventsGuardResult.okResult;
    }

    return LocalEventsGuardResult.reject('invalid_value_type:$key');
  }

  bool _validateEncodedSize(Map<String, Object?> metaJson) {
    try {
      final encoded = utf8.encode(jsonEncode(metaJson));
      return encoded.length <= _maxMetaJsonBytes;
    } catch (_) {
      return false;
    }
  }
}
