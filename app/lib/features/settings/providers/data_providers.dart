import 'package:data/data.dart' as data;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

final dataExportServiceProvider = Provider<data.DataExportService>((ref) {
  return data.DataExportService(ref.watch(appDatabaseProvider));
});

final dataBackupServiceProvider = Provider<data.DataBackupService>((ref) {
  return data.DataBackupService(db: ref.watch(appDatabaseProvider));
});

final backupFileStoreProvider = Provider<data.BackupFileStore>((ref) {
  return const data.BackupFileStore();
});

final dataMaintenanceServiceProvider = Provider<data.DataMaintenanceService>((
  ref,
) {
  return data.DataMaintenanceService(ref.watch(appDatabaseProvider));
});
