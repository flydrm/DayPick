class _Unset {
  const _Unset();
}

const _unset = _Unset();

class FeatureFlag {
  const FeatureFlag({
    required this.key,
    required this.owner,
    required this.expiryAt,
    required this.defaultValue,
    required this.killSwitch,
    required this.updatedAt,
    this.overrideValue,
  });

  final String key;
  final String owner;
  final DateTime expiryAt;
  final bool defaultValue;
  final bool killSwitch;
  final bool? overrideValue;
  final DateTime updatedAt;

  FeatureFlag copyWith({
    String? owner,
    DateTime? expiryAt,
    bool? defaultValue,
    bool? killSwitch,
    Object? overrideValue = _unset,
    DateTime? updatedAt,
  }) {
    return FeatureFlag(
      key: key,
      owner: owner ?? this.owner,
      expiryAt: expiryAt ?? this.expiryAt,
      defaultValue: defaultValue ?? this.defaultValue,
      killSwitch: killSwitch ?? this.killSwitch,
      overrideValue: identical(overrideValue, _unset)
          ? this.overrideValue
          : overrideValue as bool?,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
