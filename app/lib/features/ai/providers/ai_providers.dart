import 'package:ai/ai.dart' as ai;
import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../model/time_range_key.dart';

final openAiClientProvider = Provider<ai.OpenAiCompatibleClient>((ref) {
  return ai.OpenAiCompatibleClient();
});

final aiConfigProvider = FutureProvider<domain.AiProviderConfig?>((ref) async {
  return ref.watch(aiConfigRepositoryProvider).getConfig();
});

final pomodoroSessionsBetweenProvider =
    StreamProvider.family<List<domain.PomodoroSession>, TimeRangeKey>((
      ref,
      range,
    ) {
      return ref
          .watch(pomodoroSessionRepositoryProvider)
          .watchBetween(range.startInclusive, range.endExclusive);
    });
