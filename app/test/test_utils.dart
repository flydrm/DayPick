import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dispose the current widget tree and flush any timers scheduled during
/// dispose (e.g. drift stream cleanup timers).
///
/// Call this at the end of widget tests that mount [DayPickApp] to avoid:
/// "A Timer is still pending even after the widget tree was disposed."
Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
