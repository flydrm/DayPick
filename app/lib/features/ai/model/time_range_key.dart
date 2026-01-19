class TimeRangeKey {
  const TimeRangeKey({
    required this.startInclusive,
    required this.endExclusive,
  });

  final DateTime startInclusive;
  final DateTime endExclusive;

  @override
  bool operator ==(Object other) {
    return other is TimeRangeKey &&
        other.startInclusive.millisecondsSinceEpoch ==
            startInclusive.millisecondsSinceEpoch &&
        other.endExclusive.millisecondsSinceEpoch ==
            endExclusive.millisecondsSinceEpoch;
  }

  @override
  int get hashCode => Object.hash(
    startInclusive.millisecondsSinceEpoch,
    endExclusive.millisecondsSinceEpoch,
  );
}
