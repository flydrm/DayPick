import 'dart:io';

import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

bool get _isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

final uuidProvider = Provider<Uuid>((ref) => Uuid());

final taskIdGeneratorProvider = Provider<domain.TaskIdGenerator>((ref) {
  final uuid = ref.watch(uuidProvider);
  return () => uuid.v4();
});

final checklistItemIdGeneratorProvider =
    Provider<domain.ChecklistItemIdGenerator>((ref) {
      final uuid = ref.watch(uuidProvider);
      return () => uuid.v4();
    });

final pomodoroSessionIdGeneratorProvider =
    Provider<domain.PomodoroSessionIdGenerator>((ref) {
      final uuid = ref.watch(uuidProvider);
      return () => uuid.v4();
    });

final noteIdGeneratorProvider = Provider<domain.NoteIdGenerator>((ref) {
  final uuid = ref.watch(uuidProvider);
  return () => uuid.v4();
});

final weaveLinkIdGeneratorProvider = Provider<String Function()>((ref) {
  final uuid = ref.watch(uuidProvider);
  return () => uuid.v4();
});

final appDatabaseProvider = Provider<data.AppDatabase>((ref) {
  final db = _isFlutterTest
      ? data.AppDatabase.inMemoryForTesting()
      : data.AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final taskRepositoryProvider = Provider<domain.TaskRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return data.DriftTaskRepository(db);
});

final noteRepositoryProvider = Provider<domain.NoteRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return data.DriftNoteRepository(db);
});

final taskChecklistRepositoryProvider =
    Provider<domain.TaskChecklistRepository>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return data.DriftTaskChecklistRepository(db);
    });

final activePomodoroRepositoryProvider =
    Provider<domain.ActivePomodoroRepository>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return data.DriftActivePomodoroRepository(db);
    });

final pomodoroSessionRepositoryProvider =
    Provider<domain.PomodoroSessionRepository>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return data.DriftPomodoroSessionRepository(db);
    });

final pomodoroConfigRepositoryProvider =
    Provider<domain.PomodoroConfigRepository>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return data.DriftPomodoroConfigRepository(db);
    });

final appearanceConfigRepositoryProvider =
    Provider<domain.AppearanceConfigRepository>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return data.DriftAppearanceConfigRepository(db);
    });

final todayPlanRepositoryProvider = Provider<domain.TodayPlanRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return data.DriftTodayPlanRepository(db);
});

final weaveLinkRepositoryProvider = Provider<domain.WeaveLinkRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return data.DriftWeaveLinkRepository(db);
});

final localNotificationsServiceProvider =
    Provider<data.LocalNotificationsService>((ref) {
      return data.LocalNotificationsService();
    });

final aiConfigRepositoryProvider = Provider<domain.AiConfigRepository>((ref) {
  if (_isFlutterTest) {
    return _InMemoryAiConfigRepository();
  }
  return data.SecureAiConfigRepository();
});

final createTaskUseCaseProvider = Provider<domain.CreateTaskUseCase>((ref) {
  return domain.CreateTaskUseCase(
    repository: ref.watch(taskRepositoryProvider),
    generateId: ref.watch(taskIdGeneratorProvider),
  );
});

final createNoteUseCaseProvider = Provider<domain.CreateNoteUseCase>((ref) {
  return domain.CreateNoteUseCase(
    repository: ref.watch(noteRepositoryProvider),
    generateId: ref.watch(noteIdGeneratorProvider),
  );
});

final updateNoteUseCaseProvider = Provider<domain.UpdateNoteUseCase>((ref) {
  return domain.UpdateNoteUseCase(
    repository: ref.watch(noteRepositoryProvider),
  );
});

final updateTaskUseCaseProvider = Provider<domain.UpdateTaskUseCase>((ref) {
  return domain.UpdateTaskUseCase(
    repository: ref.watch(taskRepositoryProvider),
  );
});

final createChecklistItemUseCaseProvider =
    Provider<domain.CreateChecklistItemUseCase>((ref) {
      return domain.CreateChecklistItemUseCase(
        repository: ref.watch(taskChecklistRepositoryProvider),
        generateId: ref.watch(checklistItemIdGeneratorProvider),
      );
    });

final toggleChecklistItemUseCaseProvider =
    Provider<domain.ToggleChecklistItemUseCase>((ref) {
      return domain.ToggleChecklistItemUseCase(
        repository: ref.watch(taskChecklistRepositoryProvider),
      );
    });

final pomodoroConfigProvider = StreamProvider<domain.PomodoroConfig>((ref) {
  return ref.watch(pomodoroConfigRepositoryProvider).watch();
});

final appearanceConfigProvider = StreamProvider<domain.AppearanceConfig>((ref) {
  return ref.watch(appearanceConfigRepositoryProvider).watch();
});

final startPomodoroUseCaseProvider = Provider<domain.StartPomodoroUseCase>((
  ref,
) {
  return domain.StartPomodoroUseCase(
    repository: ref.watch(activePomodoroRepositoryProvider),
  );
});

final pausePomodoroUseCaseProvider = Provider<domain.PausePomodoroUseCase>((
  ref,
) {
  return domain.PausePomodoroUseCase(
    repository: ref.watch(activePomodoroRepositoryProvider),
  );
});

final resumePomodoroUseCaseProvider = Provider<domain.ResumePomodoroUseCase>((
  ref,
) {
  return domain.ResumePomodoroUseCase(
    repository: ref.watch(activePomodoroRepositoryProvider),
  );
});

final schedulePomodoroNotificationUseCaseProvider =
    Provider<domain.SchedulePomodoroNotificationUseCase>((ref) {
      return domain.SchedulePomodoroNotificationUseCase(
        scheduler: ref.watch(localNotificationsServiceProvider),
      );
    });

final cancelPomodoroNotificationUseCaseProvider =
    Provider<domain.CancelPomodoroNotificationUseCase>((ref) {
      return domain.CancelPomodoroNotificationUseCase(
        scheduler: ref.watch(localNotificationsServiceProvider),
      );
    });

final completePomodoroUseCaseProvider =
    Provider<domain.CompletePomodoroUseCase>((ref) {
      return domain.CompletePomodoroUseCase(
        activeRepository: ref.watch(activePomodoroRepositoryProvider),
        sessionRepository: ref.watch(pomodoroSessionRepositoryProvider),
        generateSessionId: ref.watch(pomodoroSessionIdGeneratorProvider),
      );
    });

class _InMemoryAiConfigRepository implements domain.AiConfigRepository {
  domain.AiProviderConfig? _config;

  @override
  Future<domain.AiProviderConfig?> getConfig() async => _config;

  @override
  Future<void> saveConfig(domain.AiProviderConfig config) async {
    _config = config;
  }

  @override
  Future<void> clearApiKey() async {
    final current = _config;
    if (current == null) return;
    _config = domain.AiProviderConfig(
      baseUrl: current.baseUrl,
      model: current.model,
      apiKey: null,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clear() async {
    _config = null;
  }
}
