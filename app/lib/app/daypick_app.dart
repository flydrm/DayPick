import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart' as domain;

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

    return MaterialApp.router(
      title: 'DayPick · 一页今日',
      theme: buildAppTheme(
        brightness: Brightness.light,
        appearance: appearance,
      ),
      darkTheme: buildAppTheme(
        brightness: Brightness.dark,
        appearance: appearance,
      ),
      themeMode: _toThemeMode(appearance.themeMode),
      routerConfig: router,
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

Color _seedColorFor(domain.AppAccent accent, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return switch (accent) {
    domain.AppAccent.a => isDark
        ? const Color(0xFF7AA6FF) // Slate Blue (dark)
        : const Color(0xFF2F5D9B), // Slate Blue (light)
    domain.AppAccent.b => isDark
        ? const Color(0xFF44C2B3) // Deep Teal (dark)
        : const Color(0xFF0F766E), // Deep Teal (light)
    domain.AppAccent.c => isDark
        ? const Color(0xFFB8C48A) // Olive Gray (dark)
        : const Color(0xFF5B6B3A), // Olive Gray (light)
  };
}

ThemeData buildAppTheme({
  required domain.AppearanceConfig appearance,
  Brightness brightness = Brightness.light,
}) {
  final seedColor = _seedColorFor(appearance.accent, brightness);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    visualDensity: _toVisualDensity(appearance.density),
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF0B0F14) : const Color(0xFFF6F7F9),
    appBarTheme: AppBarTheme(
      backgroundColor:
          isDark ? const Color(0xFF0B0F14) : const Color(0xFFF6F7F9),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
