import 'dart:async';

import 'package:domain/domain.dart' as domain;

import 'feature_flags_snapshot.dart';

class FeatureFlags {
  FeatureFlags({
    required domain.FeatureFlagRepository repository,
    required List<domain.FeatureFlag> seeds,
    DateTime Function()? now,
  }) : _repository = repository,
       _definitions = {for (final f in seeds) f.key: f},
       _now = now ?? (() => DateTime.now().toUtc());

  final domain.FeatureFlagRepository _repository;
  final Map<String, domain.FeatureFlag> _definitions;
  final DateTime Function() _now;

  final Map<String, domain.FeatureFlag> _runtime = {};
  StreamSubscription<List<domain.FeatureFlag>>? _subscription;
  bool _initialized = false;
  Future<void>? _initializeFuture;

  Future<void> initialize() {
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    try {
      await _repository.ensureAllFlags(_definitions.values.toList());

      final all = await _repository.getAllFlags();
      _updateRuntime(all);

      _subscription = _repository.watchAllFlags().listen(
        _updateRuntime,
        onError: (Object error, StackTrace stackTrace) {},
      );

      try {
        await _clearExpiredOverrides(all);
      } catch (_) {}

      _initialized = true;
    } catch (_) {
      dispose();
      _initializeFuture = null;
      _initialized = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  bool isEnabled(String key) {
    final definition = _definitions[key];
    if (definition == null) return false;

    try {
      final runtime = _runtime[key] ?? definition;
      return _evaluate(
        definition: definition,
        runtime: runtime,
        now: _now(),
      ).$1;
    } catch (_) {
      return false;
    }
  }

  Stream<bool> watchEnabled(String key) {
    final definition = _definitions[key];
    if (definition == null) return Stream.value(false);

    return _repository
        .watchAllFlags()
        .map((all) {
          final runtime = all.where((f) => f.key == key);
          final r = runtime.isEmpty ? definition : runtime.first;
          return _evaluate(definition: definition, runtime: r, now: _now()).$1;
        })
        .handleError((Object error, StackTrace stackTrace) {});
  }

  Future<void> setOverride(String key, bool? value) async {
    final definition = _definitions[key];
    if (definition == null) return;

    try {
      final now = _now();
      if (now.isAfter(definition.expiryAt)) {
        await _repository.setOverrideValue(key, null);
        return;
      }
      await _repository.setOverrideValue(key, value);
    } catch (_) {}
  }

  Future<void> setKillSwitch(String key, bool value) async {
    if (!_definitions.containsKey(key)) return;
    try {
      await _repository.setKillSwitch(key, value);
    } catch (_) {}
  }

  FeatureFlagsSnapshot snapshot() {
    final now = _now();
    final entries = [
      for (final definition in _definitions.values)
        () {
          final runtime = _runtime[definition.key] ?? definition;
          final (enabled, forcedReason) = _evaluate(
            definition: definition,
            runtime: runtime,
            now: now,
          );
          return FeatureFlagsSnapshotEntry(
            key: definition.key,
            enabled: enabled,
            killSwitch: runtime.killSwitch,
            expiryAtUtcMillis: definition.expiryAt
                .toUtc()
                .millisecondsSinceEpoch,
            owner: definition.owner,
            forcedReason: forcedReason,
          );
        }(),
    ]..sort((a, b) => a.key.compareTo(b.key));

    return FeatureFlagsSnapshot(entries: entries);
  }

  void _updateRuntime(List<domain.FeatureFlag> all) {
    _runtime
      ..clear()
      ..addEntries([for (final f in all) MapEntry(f.key, f)]);
  }

  Future<void> _clearExpiredOverrides(List<domain.FeatureFlag> all) async {
    final now = _now();
    final keys = <String>[];
    for (final runtime in all) {
      final definition = _definitions[runtime.key];
      if (definition == null) continue;
      if (!now.isAfter(definition.expiryAt)) continue;
      if (runtime.overrideValue == null) continue;
      keys.add(runtime.key);
    }

    for (final key in keys) {
      try {
        await _repository.setOverrideValue(key, null);
      } catch (_) {}
    }
  }

  (bool, String?) _evaluate({
    required domain.FeatureFlag definition,
    required domain.FeatureFlag runtime,
    required DateTime now,
  }) {
    if (runtime.killSwitch) return (false, 'kill_switch');

    if (now.isAfter(definition.expiryAt)) {
      return (definition.defaultValue, 'expired');
    }

    final overrideValue = runtime.overrideValue;
    if (overrideValue != null) return (overrideValue, null);

    return (definition.defaultValue, null);
  }
}
