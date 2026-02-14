import 'package:data/data.dart' as data;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'local_events_guard.dart';
import 'local_events_service.dart';

final localEventsRepositoryProvider = Provider((ref) {
  final db = ref.watch(appDatabaseProvider);
  return data.DriftLocalEventsRepository(db);
});

final localEventsGuardProvider = Provider((ref) => LocalEventsGuard());

String _resolveAppVersion() {
  const buildName = String.fromEnvironment('FLUTTER_BUILD_NAME');
  const buildNumber = String.fromEnvironment('FLUTTER_BUILD_NUMBER');
  if (buildName.isNotEmpty && buildNumber.isNotEmpty) {
    return '$buildName+$buildNumber';
  }
  return '1.0.0+1';
}

final localEventsServiceProvider = Provider((ref) {
  return LocalEventsService(
    repository: ref.watch(localEventsRepositoryProvider),
    guard: ref.watch(localEventsGuardProvider),
    generateId: () => ref.read(uuidProvider).v4(),
    nowUtcMs: () => DateTime.now().toUtc().millisecondsSinceEpoch,
    appVersion: _resolveAppVersion,
    featureFlagsSnapshot:
        () => ref.read(featureFlagsProvider).snapshot().toJsonString(),
  );
});

