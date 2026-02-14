import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_events/local_events_provider.dart';
import '../../../core/local_events/local_events_service.dart';
import '../../../core/providers/app_providers.dart';
import 'today_plan_providers.dart';

class CalendarConstraintsState {
  static const _unset = Object();

  const CalendarConstraintsState({
    required this.dayLocal,
    required this.permissionState,
    required this.dismissed,
    required this.showEventTitles,
    required this.loading,
    required this.titlesLoading,
    this.summary,
    this.error,
    this.titledEvents,
    this.titlesError,
  });

  final DateTime dayLocal;
  final domain.CalendarPermissionState permissionState;
  final bool dismissed;
  final bool showEventTitles;
  final bool loading;
  final bool titlesLoading;
  final domain.CalendarBusyFreeSummary? summary;
  final Object? error;
  final List<domain.CalendarTitledEvent>? titledEvents;
  final Object? titlesError;

  CalendarConstraintsState copyWith({
    DateTime? dayLocal,
    domain.CalendarPermissionState? permissionState,
    bool? dismissed,
    bool? showEventTitles,
    bool? loading,
    bool? titlesLoading,
    Object? summary = _unset,
    Object? error = _unset,
    Object? titledEvents = _unset,
    Object? titlesError = _unset,
  }) {
    return CalendarConstraintsState(
      dayLocal: dayLocal ?? this.dayLocal,
      permissionState: permissionState ?? this.permissionState,
      dismissed: dismissed ?? this.dismissed,
      showEventTitles: showEventTitles ?? this.showEventTitles,
      loading: loading ?? this.loading,
      titlesLoading: titlesLoading ?? this.titlesLoading,
      summary:
          summary == _unset ? this.summary : summary as domain.CalendarBusyFreeSummary?,
      error: error == _unset ? this.error : error,
      titledEvents:
          titledEvents == _unset
              ? this.titledEvents
              : titledEvents as List<domain.CalendarTitledEvent>?,
      titlesError: titlesError == _unset ? this.titlesError : titlesError,
    );
  }
}

class CalendarConstraintsController extends StateNotifier<CalendarConstraintsState> {
  CalendarConstraintsController({
    required domain.CalendarConstraintsRepository repository,
    required domain.AppearanceConfigRepository appearanceRepository,
    required LocalEventsService localEvents,
  }) : _repository = repository,
       _appearanceRepository = appearanceRepository,
       _localEvents = localEvents,
       super(
         CalendarConstraintsState(
           dayLocal: () {
             final now = DateTime.now();
             return DateTime(now.year, now.month, now.day);
           }(),
           permissionState: domain.CalendarPermissionState.unknown,
           dismissed: false,
           showEventTitles: false,
           loading: false,
           titlesLoading: false,
         ),
       );

  final domain.CalendarConstraintsRepository _repository;
  final domain.AppearanceConfigRepository _appearanceRepository;
  final LocalEventsService _localEvents;

  int _refreshGeneration = 0;

  String _permissionStateEventValue(domain.CalendarPermissionState state) {
    switch (state) {
      case domain.CalendarPermissionState.unknown:
        return 'unknown';
      case domain.CalendarPermissionState.granted:
        return 'granted';
      case domain.CalendarPermissionState.denied:
        return 'denied';
      case domain.CalendarPermissionState.restricted:
        return 'restricted';
      case domain.CalendarPermissionState.notSupported:
        return 'not_supported';
    }
  }

  void updateDay(DateTime dayLocal) {
    final normalized = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    if (normalized == state.dayLocal) return;
    state = state.copyWith(dayLocal: normalized);
    if (state.permissionState == domain.CalendarPermissionState.granted) {
      unawaited(refresh());
    }
  }

  void updatePreferences({
    required bool dismissed,
    required bool showEventTitles,
  }) {
    if (dismissed == state.dismissed && showEventTitles == state.showEventTitles) {
      return;
    }
    final wasDismissed = state.dismissed;
    final showTitlesChanged = showEventTitles != state.showEventTitles;
    state = state.copyWith(
      dismissed: dismissed,
      showEventTitles: showEventTitles,
      titlesLoading: showEventTitles ? state.titlesLoading : false,
      titledEvents: showEventTitles ? state.titledEvents : null,
      titlesError: showEventTitles ? state.titlesError : null,
    );
    if (wasDismissed && !dismissed) {
      unawaited(refresh());
    }
    if (showTitlesChanged &&
        showEventTitles &&
        state.permissionState == domain.CalendarPermissionState.granted) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    state = state.copyWith(
      loading: true,
      titlesLoading: state.showEventTitles,
      error: null,
      titlesError: null,
      summary: state.summary,
      titledEvents: state.titledEvents,
    );

    final permissionState = await _repository.getPermissionState();
    if (generation != _refreshGeneration) return;

    if (permissionState != state.permissionState) {
      state = state.copyWith(permissionState: permissionState);
    }

    if (permissionState != domain.CalendarPermissionState.granted) {
      state = state.copyWith(
        loading: false,
        titlesLoading: false,
        summary: null,
        titledEvents: null,
        error: null,
        titlesError: null,
      );
      return;
    }

    try {
      final summary = await _repository.getBusyFreeSummaryForDay(
        dayLocal: state.dayLocal,
      );
      if (generation != _refreshGeneration) return;
      state = state.copyWith(loading: false, summary: summary, error: null);
    } catch (e) {
      if (generation != _refreshGeneration) return;
      unawaited(
        _localEvents.record(
          eventName: domain.LocalEventNames.calendarPermissionPath,
          metaJson: const {'action': 'read', 'result': 'error', 'state': 'granted'},
        ),
      );
      state = state.copyWith(
        loading: false,
        titlesLoading: false,
        summary: null,
        titledEvents: null,
        error: e,
        titlesError: null,
      );
      return;
    }

    if (!state.showEventTitles) {
      state = state.copyWith(titlesLoading: false, titledEvents: null, titlesError: null);
      return;
    }

    try {
      final events = await _repository.getTitledEventsForDay(dayLocal: state.dayLocal);
      if (generation != _refreshGeneration) return;
      if (!state.showEventTitles) {
        state = state.copyWith(titlesLoading: false, titledEvents: null, titlesError: null);
        return;
      }
      state = state.copyWith(
        titlesLoading: false,
        titledEvents: events,
        titlesError: null,
      );
    } catch (e) {
      if (generation != _refreshGeneration) return;
      if (!state.showEventTitles) {
        state = state.copyWith(titlesLoading: false, titledEvents: null, titlesError: null);
        return;
      }
      state = state.copyWith(
        titlesLoading: false,
        titledEvents: null,
        titlesError: e,
      );
    }
  }

  Future<void> connect() async {
    unawaited(
      _localEvents.record(
        eventName: domain.LocalEventNames.calendarPermissionPath,
        metaJson: {
          'action': 'connect',
          'state': _permissionStateEventValue(state.permissionState),
        },
      ),
    );

    state = state.copyWith(loading: true, error: null, summary: state.summary);
    final permissionState = await _repository.requestPermission();
    unawaited(
      _localEvents.record(
        eventName: domain.LocalEventNames.calendarPermissionPath,
        metaJson: {
          'action': 'permission_result',
          'result': _permissionStateEventValue(permissionState),
          'state': _permissionStateEventValue(permissionState),
        },
      ),
    );

    state = state.copyWith(permissionState: permissionState);
    if (permissionState == domain.CalendarPermissionState.granted) {
      await _setDismissed(false);
      await refresh();
      return;
    }

    state = state.copyWith(loading: false, summary: null, error: null);
  }

  Future<void> skip() async {
    unawaited(
      _localEvents.record(
        eventName: domain.LocalEventNames.calendarPermissionPath,
        metaJson: {
          'action': 'skip',
          'state': _permissionStateEventValue(state.permissionState),
        },
      ),
    );
    await _setDismissed(true);
  }

  Future<void> openAppSettings() async {
    unawaited(
      _localEvents.record(
        eventName: domain.LocalEventNames.calendarPermissionPath,
        metaJson: {
          'action': 'open_settings',
          'state': _permissionStateEventValue(state.permissionState),
        },
      ),
    );
    await _repository.openAppSettings();
  }

  Future<void> setShowEventTitles(bool enabled) async {
    if (enabled == state.showEventTitles) return;

    state = state.copyWith(
      showEventTitles: enabled,
      titlesLoading: enabled,
      titledEvents: enabled ? state.titledEvents : null,
      titlesError: null,
    );

    final current = await _appearanceRepository.get();
    await _appearanceRepository.save(
      current.copyWith(calendarShowEventTitles: enabled),
    );
    if (!enabled) return;
    await refresh();
  }

  Future<void> _setDismissed(bool dismissed) async {
    final current = await _appearanceRepository.get();
    await _appearanceRepository.save(
      current.copyWith(calendarConstraintsDismissed: dismissed),
    );
  }
}

final calendarConstraintsControllerProvider = StateNotifierProvider<
  CalendarConstraintsController,
  CalendarConstraintsState
>((ref) {
  final controller = CalendarConstraintsController(
    repository: ref.watch(calendarConstraintsRepositoryProvider),
    appearanceRepository: ref.watch(appearanceConfigRepositoryProvider),
    localEvents: ref.watch(localEventsServiceProvider),
  );

  ref.listen<AsyncValue<domain.AppearanceConfig>>(appearanceConfigProvider, (
    _,
    next,
  ) {
    final config = next.valueOrNull;
    if (config == null) return;
    controller.updatePreferences(
      dismissed: config.calendarConstraintsDismissed,
      showEventTitles: config.calendarShowEventTitles,
    );
  }, fireImmediately: true);

  ref.listen<AsyncValue<DateTime>>(todayDayProvider, (_, next) {
    final day = next.valueOrNull;
    if (day == null) return;
    controller.updateDay(day);
  }, fireImmediately: true);

  unawaited(controller.refresh());
  return controller;
});
