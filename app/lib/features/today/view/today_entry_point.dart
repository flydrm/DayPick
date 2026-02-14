import 'package:flutter/widgets.dart';

import '../../../core/feature_flags/feature_flag_keys.dart';
import '../../../core/feature_flags/feature_gated.dart';
import 'today_page.dart';
import 'today_v2_page.dart';

class TodayEntryPoint extends StatelessWidget {
  const TodayEntryPoint({
    super.key,
    this.rawHighlight,
  });

  final String? rawHighlight;

  @override
  Widget build(BuildContext context) {
    return FeatureGated(
      flagKey: FeatureFlagKeys.todayV2,
      oldBuilder: (_) => TodayPage(rawHighlight: rawHighlight),
      newBuilder: (_) => TodayV2Page(rawHighlight: rawHighlight),
    );
  }
}
