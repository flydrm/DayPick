import 'package:domain/domain.dart' as domain;

class FeatureFlagKeys {
  static const todayV2 = 'today_v2';
  static const captureBar = 'capture_bar';
  static const journalLink = 'journal_link';
  static const aiNodes = 'ai_nodes';

  static const all = [todayV2, captureBar, journalLink, aiNodes];
}

List<domain.FeatureFlag> defaultFeatureFlagSeeds({DateTime? nowUtc}) {
  final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
  final expiry = DateTime.utc(2026, 12, 31);

  return [
    domain.FeatureFlag(
      key: FeatureFlagKeys.todayV2,
      owner: 'today',
      expiryAt: expiry,
      defaultValue: false,
      killSwitch: false,
      updatedAt: now,
    ),
    domain.FeatureFlag(
      key: FeatureFlagKeys.captureBar,
      owner: 'capture',
      expiryAt: expiry,
      defaultValue: false,
      killSwitch: false,
      updatedAt: now,
    ),
    domain.FeatureFlag(
      key: FeatureFlagKeys.journalLink,
      owner: 'journal',
      expiryAt: expiry,
      defaultValue: false,
      killSwitch: false,
      updatedAt: now,
    ),
    domain.FeatureFlag(
      key: FeatureFlagKeys.aiNodes,
      owner: 'ai',
      expiryAt: expiry,
      defaultValue: false,
      killSwitch: false,
      updatedAt: now,
    ),
  ];
}
