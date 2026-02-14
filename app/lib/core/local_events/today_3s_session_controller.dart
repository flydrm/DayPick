import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_events_provider.dart';

class Today3sSessionState {
  const Today3sSessionState({
    required this.sessionStart,
    required this.primaryActionInvokedDeduped,
    required this.effectiveExecutionEnteredDeduped,
    required this.clarityResultWritten,
    required this.firstFailureBucket,
    required this.firstFailureElapsedMs,
    required this.failureFlags,
  });

  const Today3sSessionState.initial()
    : sessionStart = null,
      primaryActionInvokedDeduped = false,
      effectiveExecutionEnteredDeduped = false,
      clarityResultWritten = false,
      firstFailureBucket = null,
      firstFailureElapsedMs = null,
      failureFlags = const <String>[];

  final Duration? sessionStart;
  final bool primaryActionInvokedDeduped;
  final bool effectiveExecutionEnteredDeduped;
  final bool clarityResultWritten;
  final String? firstFailureBucket;
  final int? firstFailureElapsedMs;
  final List<String> failureFlags;

  bool get isActive => sessionStart != null;

  Today3sSessionState copyWith({
    Duration? sessionStart,
    bool? primaryActionInvokedDeduped,
    bool? effectiveExecutionEnteredDeduped,
    bool? clarityResultWritten,
    String? firstFailureBucket,
    int? firstFailureElapsedMs,
    List<String>? failureFlags,
  }) {
    return Today3sSessionState(
      sessionStart: sessionStart ?? this.sessionStart,
      primaryActionInvokedDeduped:
          primaryActionInvokedDeduped ?? this.primaryActionInvokedDeduped,
      effectiveExecutionEnteredDeduped:
          effectiveExecutionEnteredDeduped ??
          this.effectiveExecutionEnteredDeduped,
      clarityResultWritten: clarityResultWritten ?? this.clarityResultWritten,
      firstFailureBucket: firstFailureBucket ?? this.firstFailureBucket,
      firstFailureElapsedMs: firstFailureElapsedMs ?? this.firstFailureElapsedMs,
      failureFlags: failureFlags ?? this.failureFlags,
    );
  }
}

final today3sSessionControllerProvider =
    NotifierProvider<Today3sSessionController, Today3sSessionState>(
      Today3sSessionController.new,
    );

class Today3sSessionController extends Notifier<Today3sSessionState> {
  static const Duration _window = Duration(milliseconds: 3000);

  Timer? _timeoutTimer;

  @override
  Today3sSessionState build() {
    ref.onDispose(() {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
    });

    return const Today3sSessionState.initial();
  }

  int _elapsedMs() {
    final start = state.sessionStart;
    if (start == null) return 0;
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final elapsed = (now - start).inMilliseconds;
    return elapsed < 0 ? 0 : elapsed;
  }

  bool _withinWindow() {
    if (!state.isActive) return false;
    return _elapsedMs() <= _window.inMilliseconds;
  }

  Future<void> recordTodayOpened({required String source}) async {
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.todayOpened,
      metaJson: {'source': source},
    );
  }

  Future<void> startSession({required String? segment}) async {
    if (state.isActive) return;

    final start = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    state = Today3sSessionState(
      sessionStart: start,
      primaryActionInvokedDeduped: false,
      effectiveExecutionEnteredDeduped: false,
      clarityResultWritten: false,
      firstFailureBucket: null,
      firstFailureElapsedMs: null,
      failureFlags: const <String>[],
    );

    final metaJson = <String, Object?>{};
    if (segment != null && segment.isNotEmpty) {
      metaJson['segment'] = segment;
    }
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.todayFirstInteractive,
      metaJson: metaJson,
    );

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_window, () {
      unawaited(_onTimeout());
    });
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) return;
    if (!_withinWindow()) return;
    await _registerFailure(bucket: 'other');
    await _finalizeAndEndSession();
  }

  Future<void> recordPrimaryActionInvoked({required String action}) async {
    if (!_withinWindow()) return;
    if (state.primaryActionInvokedDeduped) return;

    state = state.copyWith(primaryActionInvokedDeduped: true);
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.primaryActionInvoked,
      metaJson: {'action': action, 'elapsed_ms': _elapsedMs()},
    );
  }

  Future<void> recordEffectiveExecutionStateEntered({
    required String source,
    required String kind,
  }) async {
    if (!_withinWindow()) return;
    if (state.effectiveExecutionEnteredDeduped) return;

    state = state.copyWith(effectiveExecutionEnteredDeduped: true);
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.effectiveExecutionStateEntered,
      metaJson: {'source': source, 'kind': kind},
    );

    // Success is only valid if no failure reason happened first.
    if (state.firstFailureBucket == null && !state.clarityResultWritten) {
      await _writeClarityOk();
    }
  }

  Future<void> recordTodayScrolled({required int deltaPx}) async {
    if (!_withinWindow()) return;
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.todayScrolled,
      metaJson: {'delta_px': deltaPx},
    );
    await _registerFailure(bucket: 'scroll');
  }

  Future<void> recordFullscreenOpened({
    required String screen,
    required String reason,
  }) async {
    if (!_withinWindow()) return;
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.fullscreenOpened,
      metaJson: {'screen': screen, 'reason': reason},
    );
    await _registerFailure(bucket: 'fullscreen');
    await _finalizeAndEndSession();
  }

  Future<void> recordTabSwitched({
    required String fromTab,
    required String toTab,
  }) async {
    if (!_withinWindow()) return;
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.tabSwitched,
      metaJson: {'from_tab': fromTab, 'to_tab': toTab},
    );
    await _registerFailure(bucket: 'tab_switch');
    await _finalizeAndEndSession();
  }

  Future<void> recordTodayLeft({required String destination}) async {
    if (!_withinWindow()) return;
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.todayLeft,
      metaJson: {'destination': destination},
    );
    await _registerFailure(bucket: 'leave_today');
    await _finalizeAndEndSession();
  }

  Future<void> recordClarityFailOther() async {
    if (!_withinWindow()) return;
    await _registerFailure(bucket: 'other');
  }

  Future<void> _writeClarityOk() async {
    state = state.copyWith(clarityResultWritten: true);
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.todayClarityResult,
      metaJson: {'result': 'ok', 'elapsed_ms': _elapsedMs()},
    );
  }

  Future<void> _writeClarityFail({
    required int elapsedMs,
    required String bucket,
    required List<String> flags,
  }) async {
    state = state.copyWith(clarityResultWritten: true);

    final metaJson = <String, Object?>{
      'result': 'fail',
      'elapsed_ms': elapsedMs,
      'failure_bucket': bucket,
    };
    if (flags.isNotEmpty) {
      metaJson['failure_flags'] = List<String>.unmodifiable(flags);
    }
    await ref.read(localEventsServiceProvider).record(
      eventName: domain.LocalEventNames.todayClarityResult,
      metaJson: metaJson,
    );
  }

  Future<void> _onTimeout() async {
    if (!state.isActive) return;
    if (state.clarityResultWritten) {
      _endSession();
      return;
    }

    final firstBucket = state.firstFailureBucket;
    final firstElapsedMs = state.firstFailureElapsedMs;
    if (firstBucket != null && firstElapsedMs != null) {
      await _writeClarityFail(
        elapsedMs: firstElapsedMs,
        bucket: firstBucket,
        flags: state.failureFlags,
      );
      _endSession();
      return;
    }

    await _writeClarityFail(
      elapsedMs: _window.inMilliseconds,
      bucket: 'timeout',
      flags: const <String>[],
    );
    _endSession();
  }

  Future<void> _registerFailure({required String bucket}) async {
    if (!state.isActive) return;

    final firstBucket = state.firstFailureBucket;
    if (firstBucket == null) {
      state = state.copyWith(
        firstFailureBucket: bucket,
        firstFailureElapsedMs: _elapsedMs(),
      );
      return;
    }

    if (bucket == firstBucket) return;
    if (state.failureFlags.contains(bucket)) return;

    state = state.copyWith(
      failureFlags: List<String>.unmodifiable([...state.failureFlags, bucket]),
    );
  }

  Future<void> _finalizeAndEndSession() async {
    if (!state.isActive) return;
    if (state.clarityResultWritten) {
      _endSession();
      return;
    }

    final bucket = state.firstFailureBucket ?? 'other';
    final elapsedMs = state.firstFailureElapsedMs ?? _elapsedMs();
    await _writeClarityFail(
      elapsedMs: elapsedMs,
      bucket: bucket,
      flags: state.failureFlags,
    );
    _endSession();
  }

  void _endSession() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    state = Today3sSessionState(
      sessionStart: null,
      primaryActionInvokedDeduped: false,
      effectiveExecutionEnteredDeduped: false,
      clarityResultWritten: false,
      firstFailureBucket: null,
      firstFailureElapsedMs: null,
      failureFlags: const <String>[],
    );
  }
}
