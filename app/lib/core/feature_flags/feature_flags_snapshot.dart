import 'dart:convert';

class FeatureFlagsSnapshotEntry {
  const FeatureFlagsSnapshotEntry({
    required this.key,
    required this.enabled,
    required this.killSwitch,
    required this.expiryAtUtcMillis,
    required this.owner,
    required this.forcedReason,
  });

  final String key;
  final bool enabled;
  final bool killSwitch;
  final int expiryAtUtcMillis;
  final String owner;
  final String? forcedReason;

  Map<String, Object?> toJson() {
    return {
      'key': key,
      'enabled': enabled,
      'kill_switch': killSwitch,
      'expiry_utc_ms': expiryAtUtcMillis,
      'owner': owner,
      'forced_reason': forcedReason,
    };
  }
}

class FeatureFlagsSnapshot {
  const FeatureFlagsSnapshot({required this.entries});

  final List<FeatureFlagsSnapshotEntry> entries;

  List<Map<String, Object?>> toJson() {
    return [for (final e in entries) e.toJson()];
  }

  String toJsonString() => jsonEncode(toJson());
}
