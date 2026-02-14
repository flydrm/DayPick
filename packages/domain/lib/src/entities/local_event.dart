class LocalEvent {
  const LocalEvent({
    required this.id,
    required this.eventName,
    required this.occurredAtUtcMs,
    required this.appVersion,
    required this.featureFlags,
    required this.metaJson,
  });

  final String id;
  final String eventName;
  final int occurredAtUtcMs;
  final String appVersion;
  final String featureFlags;
  final Map<String, Object?> metaJson;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'event_name': eventName,
      'occurred_at_utc_ms': occurredAtUtcMs,
      'app_version': appVersion,
      'feature_flags': featureFlags,
      'meta_json': metaJson,
    };
  }
}
