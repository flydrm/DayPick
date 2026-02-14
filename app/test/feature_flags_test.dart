import 'dart:async';

import 'package:daypick/core/feature_flags/feature_flags.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kill switch overrides override', () async {
    final repo = _InMemoryFeatureFlagRepository();
    final expiry = DateTime.utc(2099, 1, 1);
    final seeds = [_seed(key: 'a_flag', expiryAt: expiry, defaultValue: false)];

    final flags = FeatureFlags(repository: repo, seeds: seeds);
    addTearDown(flags.dispose);

    await flags.initialize();

    await flags.setOverride('a_flag', true);
    await flags.setKillSwitch('a_flag', true);

    expect(flags.isEnabled('a_flag'), isFalse);
  });

  test('expiry forces default and records reason in snapshot', () async {
    final repo = _InMemoryFeatureFlagRepository();
    final expired = DateTime.utc(2000, 1, 1);
    final seeds = [
      _seed(key: 'a_flag', expiryAt: expired, defaultValue: false),
    ];

    final flags = FeatureFlags(repository: repo, seeds: seeds);
    addTearDown(flags.dispose);

    await flags.initialize();

    await flags.setOverride('a_flag', true);
    expect(flags.isEnabled('a_flag'), isFalse);

    final entry = flags.snapshot().entries.single;
    expect(entry.enabled, isFalse);
    expect(entry.forcedReason, 'expired');
  });

  test('snapshot is deterministic and sorted by key', () async {
    final repo = _InMemoryFeatureFlagRepository();
    final expiry = DateTime.utc(2099, 1, 1);
    final seeds = [
      _seed(key: 'b_flag', expiryAt: expiry),
      _seed(key: 'a_flag', expiryAt: expiry),
    ];

    final flags = FeatureFlags(repository: repo, seeds: seeds);
    addTearDown(flags.dispose);

    await flags.initialize();

    final snap1 = flags.snapshot();
    final snap2 = flags.snapshot();

    expect(snap1.toJsonString(), snap2.toJsonString());
    expect([for (final e in snap1.entries) e.key], ['a_flag', 'b_flag']);
  });

  test('initialize does not throw if repository fails', () async {
    final repo = _ThrowingFeatureFlagRepository();
    final expiry = DateTime.utc(2099, 1, 1);
    final seeds = [_seed(key: 'a_flag', expiryAt: expiry)];
    final flags = FeatureFlags(repository: repo, seeds: seeds);
    addTearDown(flags.dispose);

    await expectLater(flags.initialize(), completes);
    expect(flags.isEnabled('a_flag'), isFalse);
  });

  test('initialize can be retried after failure', () async {
    final repo = _FlakyFeatureFlagRepository();
    final expiry = DateTime.utc(2099, 1, 1);
    final seeds = [_seed(key: 'a_flag', expiryAt: expiry, defaultValue: false)];
    final flags = FeatureFlags(repository: repo, seeds: seeds);
    addTearDown(flags.dispose);

    await expectLater(flags.initialize(), completes);
    expect(repo.ensureCalls, 1);

    await expectLater(flags.initialize(), completes);
    expect(repo.ensureCalls, 2);
    expect(await repo.getAllFlags(), hasLength(1));
  });
}

domain.FeatureFlag _seed({
  required String key,
  required DateTime expiryAt,
  bool defaultValue = false,
  String owner = 'test',
}) {
  return domain.FeatureFlag(
    key: key,
    owner: owner,
    expiryAt: expiryAt,
    defaultValue: defaultValue,
    killSwitch: false,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

class _InMemoryFeatureFlagRepository implements domain.FeatureFlagRepository {
  final _flags = <String, domain.FeatureFlag>{};
  final _controller = StreamController<List<domain.FeatureFlag>>.broadcast();

  @override
  Stream<List<domain.FeatureFlag>> watchAllFlags() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<List<domain.FeatureFlag>> getAllFlags() async => _snapshot();

  @override
  Future<void> ensureAllFlags(List<domain.FeatureFlag> seeds) async {
    for (final seed in seeds) {
      final existing = _flags[seed.key];
      if (existing == null) {
        _flags[seed.key] = seed;
        continue;
      }
      _flags[seed.key] = existing.copyWith(
        owner: seed.owner,
        expiryAt: seed.expiryAt,
        defaultValue: seed.defaultValue,
      );
    }
    _emit();
  }

  @override
  Future<void> setOverrideValue(String key, bool? value) async {
    final existing = _flags[key];
    if (existing == null) return;
    _flags[key] = existing.copyWith(
      overrideValue: value,
      updatedAt: DateTime.now().toUtc(),
    );
    _emit();
  }

  @override
  Future<void> setKillSwitch(String key, bool value) async {
    final existing = _flags[key];
    if (existing == null) return;
    _flags[key] = existing.copyWith(
      killSwitch: value,
      updatedAt: DateTime.now().toUtc(),
    );
    _emit();
  }

  List<domain.FeatureFlag> _snapshot() {
    final rows = _flags.values.toList();
    rows.sort((a, b) => a.key.compareTo(b.key));
    return rows;
  }

  void _emit() {
    _controller.add(_snapshot());
  }
}

class _ThrowingFeatureFlagRepository implements domain.FeatureFlagRepository {
  @override
  Stream<List<domain.FeatureFlag>> watchAllFlags() => const Stream.empty();

  @override
  Future<List<domain.FeatureFlag>> getAllFlags() => Future.error('fail');

  @override
  Future<void> ensureAllFlags(List<domain.FeatureFlag> seeds) =>
      Future.error('fail');

  @override
  Future<void> setOverrideValue(String key, bool? value) =>
      Future.error('fail');

  @override
  Future<void> setKillSwitch(String key, bool value) => Future.error('fail');
}

class _FlakyFeatureFlagRepository implements domain.FeatureFlagRepository {
  _FlakyFeatureFlagRepository();

  final _delegate = _InMemoryFeatureFlagRepository();
  var ensureCalls = 0;

  @override
  Stream<List<domain.FeatureFlag>> watchAllFlags() => _delegate.watchAllFlags();

  @override
  Future<List<domain.FeatureFlag>> getAllFlags() => _delegate.getAllFlags();

  @override
  Future<void> ensureAllFlags(List<domain.FeatureFlag> seeds) async {
    ensureCalls++;
    if (ensureCalls == 1) throw 'fail';
    await _delegate.ensureAllFlags(seeds);
  }

  @override
  Future<void> setOverrideValue(String key, bool? value) =>
      _delegate.setOverrideValue(key, value);

  @override
  Future<void> setKillSwitch(String key, bool value) =>
      _delegate.setKillSwitch(key, value);
}
