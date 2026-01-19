import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart' as domain;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/providers/app_providers.dart';
import '../routing/app_router.dart';

class DayPickApp extends ConsumerWidget {
  const DayPickApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final appearanceAsync = ref.watch(appearanceConfigProvider);
    final appearance = appearanceAsync.maybeWhen(
      data: (v) => v,
      orElse: () => const domain.AppearanceConfig(),
    );

    return ShadApp.custom(
      themeMode: _toThemeMode(appearance.themeMode),
      theme: _buildShadThemeData(
        appearance: appearance,
        brightness: Brightness.light,
      ),
      darkTheme: _buildShadThemeData(
        appearance: appearance,
        brightness: Brightness.dark,
      ),
      appBuilder: (context) {
        final baseTheme = Theme.of(context);
        final materialTheme = ThemeData.from(
          colorScheme: baseTheme.colorScheme,
          textTheme: baseTheme.textTheme,
          useMaterial3: false,
        ).copyWith(visualDensity: _toVisualDensity(appearance.density));
        return MaterialApp.router(
          title: 'DayPick · 一页今日',
          debugShowCheckedModeBanner: false,
          theme: materialTheme,
          routerConfig: router,
          builder: (context, child) =>
              ShadAppBuilder(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

ThemeMode _toThemeMode(domain.AppThemeMode mode) {
  return switch (mode) {
    domain.AppThemeMode.system => ThemeMode.system,
    domain.AppThemeMode.light => ThemeMode.light,
    domain.AppThemeMode.dark => ThemeMode.dark,
  };
}

VisualDensity _toVisualDensity(domain.AppDensity density) {
  return switch (density) {
    domain.AppDensity.comfortable => VisualDensity.standard,
    domain.AppDensity.compact => VisualDensity.compact,
  };
}

String _shadSchemeNameFor(domain.AppAccent accent) {
  return switch (accent) {
    domain.AppAccent.a => 'blue',
    domain.AppAccent.b => 'green',
    domain.AppAccent.c => 'stone',
  };
}

ShadThemeData _buildShadThemeData({
  required domain.AppearanceConfig appearance,
  required Brightness brightness,
}) {
  final schemeName = _shadSchemeNameFor(appearance.accent);
  final colorScheme = ShadColorScheme.fromName(
    schemeName,
    brightness: brightness,
  );
  return ShadThemeData(brightness: brightness, colorScheme: colorScheme);
}
