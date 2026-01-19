import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import 'weave_insertion.dart';

class WeaveToLongformResult {
  const WeaveToLongformResult({
    required this.targetNoteId,
    required this.mode,
    required this.createdLinkIds,
    required this.tasksBefore,
    required this.notesBefore,
    required this.targetBefore,
    required this.didUpdateTargetBody,
  });

  final String targetNoteId;
  final domain.WeaveMode mode;
  final List<String> createdLinkIds;
  final List<domain.Task> tasksBefore;
  final List<domain.Note> notesBefore;
  final domain.Note? targetBefore;
  final bool didUpdateTargetBody;
}

Future<WeaveToLongformResult> weaveToLongform({
  required WidgetRef ref,
  required String targetNoteId,
  required domain.WeaveMode mode,
  List<domain.Task> tasks = const [],
  List<domain.Note> notes = const [],
}) async {
  final now = DateTime.now();
  final idGen = ref.read(weaveLinkIdGeneratorProvider);
  final weaveRepo = ref.read(weaveLinkRepositoryProvider);
  final taskRepo = ref.read(taskRepositoryProvider);
  final noteRepo = ref.read(noteRepositoryProvider);

  final tasksBefore = List<domain.Task>.from(tasks);
  final notesBefore = List<domain.Note>.from(notes);
  final createdLinkIds = <String>[];

  for (final task in tasksBefore) {
    final linkId = idGen();
    createdLinkIds.add(linkId);
    await weaveRepo.upsertLink(
      domain.WeaveLink(
        id: linkId,
        sourceType: domain.WeaveSourceType.task,
        sourceId: task.id,
        targetNoteId: targetNoteId,
        mode: mode,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await taskRepo.upsertTask(
      task.copyWith(triageStatus: domain.TriageStatus.weaved, updatedAt: now),
    );
  }

  for (final note in notesBefore) {
    final linkId = idGen();
    createdLinkIds.add(linkId);
    await weaveRepo.upsertLink(
      domain.WeaveLink(
        id: linkId,
        sourceType: domain.WeaveSourceType.note,
        sourceId: note.id,
        targetNoteId: targetNoteId,
        mode: mode,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await noteRepo.upsertNote(
      note.copyWith(triageStatus: domain.TriageStatus.weaved, updatedAt: now),
    );
  }

  domain.Note? targetBefore;
  var didUpdateTargetBody = false;

  if (mode == domain.WeaveMode.copy) {
    targetBefore = await noteRepo.getNoteById(targetNoteId);
    final target = targetBefore;
    if (target != null) {
      final blocks = <({DateTime updatedAt, String block})>[
        for (final t in tasksBefore)
          (updatedAt: t.updatedAt, block: formatWeaveCopyBlockFromTask(t)),
        for (final n in notesBefore)
          (updatedAt: n.updatedAt, block: formatWeaveCopyBlockFromNote(n)),
      ]..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

      final insert = blocks.map((b) => b.block).join('\n\n').trim();
      if (insert.isNotEmpty) {
        final nextBody = insertAfterCollectAnchor(target.body, insert);
        didUpdateTargetBody = nextBody != target.body;
        await noteRepo.upsertNote(
          target.copyWith(body: nextBody, updatedAt: now),
        );
      }
    }
  }

  return WeaveToLongformResult(
    targetNoteId: targetNoteId,
    mode: mode,
    createdLinkIds: List.unmodifiable(createdLinkIds),
    tasksBefore: List.unmodifiable(tasksBefore),
    notesBefore: List.unmodifiable(notesBefore),
    targetBefore: targetBefore,
    didUpdateTargetBody: didUpdateTargetBody,
  );
}

Future<void> undoWeaveToLongform(
  WidgetRef ref,
  WeaveToLongformResult result,
) async {
  final weaveRepo = ref.read(weaveLinkRepositoryProvider);
  final taskRepo = ref.read(taskRepositoryProvider);
  final noteRepo = ref.read(noteRepositoryProvider);
  final now = DateTime.now();

  for (final id in result.createdLinkIds) {
    await weaveRepo.deleteLink(id);
  }
  for (final task in result.tasksBefore) {
    await taskRepo.upsertTask(task.copyWith(updatedAt: now));
  }
  for (final note in result.notesBefore) {
    await noteRepo.upsertNote(note.copyWith(updatedAt: now));
  }

  if (result.mode == domain.WeaveMode.copy && result.targetBefore != null) {
    await noteRepo.upsertNote(result.targetBefore!.copyWith(updatedAt: now));
  }
}
