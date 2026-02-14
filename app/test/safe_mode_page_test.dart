import 'package:daypick/features/safe_mode/model/safe_mode_reason.dart';
import 'package:daypick/features/safe_mode/view/safe_mode_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  Future<void> pumpSafeMode(WidgetTester tester) async {
    ShadThemeData themeFor(Brightness brightness) {
      final scheme = ShadColorScheme.fromName('blue', brightness: brightness);
      return ShadThemeData(brightness: brightness, colorScheme: scheme);
    }

    await tester.pumpWidget(
      ShadApp.custom(
        themeMode: ThemeMode.light,
        theme: themeFor(Brightness.light),
        darkTheme: themeFor(Brightness.dark),
        appBuilder: (context) => MaterialApp(
          home: ShadAppBuilder(
            child: SafeModePage(
              info: const SafeModeInfo(reason: SafeModeReason.dbKeyMissing),
              onRetryBootstrap: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders and shows clear confirm dialog', (tester) async {
    await pumpSafeMode(tester);

    expect(find.text('数据已锁定（安全模式）'), findsOneWidget);
    expect(find.text('清库重建'), findsOneWidget);

    await tester.tap(find.text('清库重建'));
    await tester.pumpAndSettle();

    expect(find.text('确认清空本地数据？'), findsOneWidget);
    expect(find.text('仍要清空'), findsOneWidget);
  });
}
