import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

typedef FeatureBranchBuilder = Widget Function(BuildContext context);

class FeatureGated extends ConsumerWidget {
  const FeatureGated({
    super.key,
    required this.flagKey,
    required this.oldBuilder,
    required this.newBuilder,
  });

  final String flagKey;
  final FeatureBranchBuilder oldBuilder;
  final FeatureBranchBuilder newBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(featureFlagEnabledProvider(flagKey));
    final enabled = enabledAsync.maybeWhen(data: (v) => v, orElse: () => false);
    return enabled ? newBuilder(context) : oldBuilder(context);
  }
}

