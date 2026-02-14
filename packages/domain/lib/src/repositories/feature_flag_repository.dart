import '../entities/feature_flag.dart';

abstract interface class FeatureFlagRepository {
  Stream<List<FeatureFlag>> watchAllFlags();
  Future<List<FeatureFlag>> getAllFlags();

  /// Ensures every flag exists and is up-to-date with the provided definitions.
  ///
  /// Implementations must preserve user-controlled runtime state such as
  /// `overrideValue` and `killSwitch` for existing rows.
  Future<void> ensureAllFlags(List<FeatureFlag> seeds);

  Future<void> setOverrideValue(String key, bool? value);
  Future<void> setKillSwitch(String key, bool value);
}
