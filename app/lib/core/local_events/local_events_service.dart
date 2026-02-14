import 'dart:async';

import 'package:domain/domain.dart' as domain;

import 'local_events_guard.dart';

class LocalEventsService {
  static const int defaultRetentionDays = 30;
  static const int minRetentionDays = 0;
  static const int maxRetentionDays = 365;
  static const int defaultMaxEvents = 5000;

  LocalEventsService({
    required domain.LocalEventsRepository repository,
    required LocalEventsGuard guard,
    required String Function() generateId,
    required int Function() nowUtcMs,
    required String Function() appVersion,
    required String Function() featureFlagsSnapshot,
    int retentionDays = defaultRetentionDays,
    int maxEvents = defaultMaxEvents,
  }) : _repository = repository,
       _guard = guard,
       _generateId = generateId,
       _nowUtcMs = nowUtcMs,
       _appVersion = appVersion,
       _featureFlagsSnapshot = featureFlagsSnapshot,
       _retentionDays = retentionDays,
       _maxEvents = maxEvents;

  final domain.LocalEventsRepository _repository;
  final LocalEventsGuard _guard;
  final String Function() _generateId;
  final int Function() _nowUtcMs;
  final String Function() _appVersion;
  final String Function() _featureFlagsSnapshot;
  final int _retentionDays;
  final int _maxEvents;

  Future<bool> record({
    required String eventName,
    required Map<String, Object?> metaJson,
  }) async {
    final guardResult = _guard.validate(eventName: eventName, metaJson: metaJson);
    if (!guardResult.ok) return false;

    final occurredAtUtcMs = _nowUtcMs();
    final event = domain.LocalEvent(
      id: _generateId(),
      eventName: eventName,
      occurredAtUtcMs: occurredAtUtcMs,
      appVersion: _appVersion(),
      featureFlags: _featureFlagsSnapshot(),
      metaJson: Map<String, Object?>.from(metaJson),
    );

    try {
      await _repository.insert(event);
      _schedulePrune(occurredAtUtcMs: occurredAtUtcMs);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _schedulePrune({required int occurredAtUtcMs}) {
    final clampedRetentionDays =
        _retentionDays
            .clamp(minRetentionDays, maxRetentionDays)
            .toInt();
    final maxEvents = _maxEvents;
    final minOccurredAtUtcMs = clampedRetentionDays == 0
        ? 0
        : occurredAtUtcMs - (clampedRetentionDays * Duration.millisecondsPerDay);
    unawaited(
      _repository
          .prune(
            minOccurredAtUtcMs: minOccurredAtUtcMs < 0 ? 0 : minOccurredAtUtcMs,
            maxEvents: maxEvents,
          )
          .catchError((_) {}),
    );
  }
}
