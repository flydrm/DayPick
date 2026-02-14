import 'package:flutter/material.dart';

class DpAccessibility {
  const DpAccessibility._();

  static const double minTouchTarget = 48;

  static const BoxConstraints minTouchTargetConstraints = BoxConstraints(
    minWidth: minTouchTarget,
    minHeight: minTouchTarget,
  );

  static bool reduceMotionEnabled(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static AnimationStyle? bottomSheetAnimationStyle(BuildContext context) {
    if (!reduceMotionEnabled(context)) {
      return null;
    }
    return AnimationStyle.noAnimation;
  }
}
