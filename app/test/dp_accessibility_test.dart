import 'package:daypick/ui/tokens/dp_accessibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpAccessibility reduceMotionEnabled reads MediaQuery', (
    tester,
  ) async {
    var reduced = false;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            reduced = DpAccessibility.reduceMotionEnabled(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(reduced, isTrue);
  });

  testWidgets(
    'DpAccessibility bottomSheetAnimationStyle follows reduce motion',
    (tester) async {
      AnimationStyle? reducedStyle;
      AnimationStyle? normalStyle;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reducedStyle = DpAccessibility.bottomSheetAnimationStyle(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              normalStyle = DpAccessibility.bottomSheetAnimationStyle(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reducedStyle, isNotNull);
      expect(normalStyle, isNull);
    },
  );
}
