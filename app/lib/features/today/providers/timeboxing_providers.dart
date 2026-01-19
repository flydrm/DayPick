import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

int _roundUpMinutes(int minutes, int step) {
  if (step <= 1) return minutes;
  return ((minutes + step - 1) ~/ step) * step;
}

int _defaultStartMinutes() {
  const defaultStart = 9 * 60;
  final now = DateTime.now();
  final minutes = now.hour * 60 + now.minute;
  if (minutes <= defaultStart) return defaultStart;
  return _roundUpMinutes(minutes, 5).clamp(0, 24 * 60 - 1);
}

final timeboxingStartMinutesProvider = Provider<int>((ref) {
  final appearance = ref.watch(appearanceConfigProvider).valueOrNull;
  final stored = appearance?.timeboxingStartMinutes;
  if (stored != null) return stored.clamp(0, 24 * 60 - 1);
  return _defaultStartMinutes();
});
