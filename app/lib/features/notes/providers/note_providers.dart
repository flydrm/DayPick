import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

final notesStreamProvider = StreamProvider<List<domain.Note>>((ref) {
  return ref.watch(noteRepositoryProvider).watchAllNotes();
});

final memosStreamProvider = StreamProvider<List<domain.Note>>((ref) {
  return ref.watch(noteRepositoryProvider).watchMemos();
});

final draftsStreamProvider = StreamProvider<List<domain.Note>>((ref) {
  return ref.watch(noteRepositoryProvider).watchDrafts();
});

final unprocessedNotesStreamProvider = StreamProvider<List<domain.Note>>((ref) {
  return ref.watch(noteRepositoryProvider).watchUnprocessedNotes();
});

final selectedNoteTagProvider = StateProvider<String?>((ref) => null);

final availableNoteTagsProvider = Provider<List<String>>((ref) {
  final notesAsync = ref.watch(notesStreamProvider);
  return notesAsync.maybeWhen(
    data: (notes) {
      final visibleNotes = notes.where((n) => n.kind != domain.NoteKind.memo);
      final set = <String>{};
      for (final note in visibleNotes) {
        set.addAll(note.tags);
      }
      final tags = set.toList();
      tags.sort((a, b) => a.compareTo(b));
      return tags;
    },
    orElse: () => const [],
  );
});

final filteredNotesProvider = Provider<AsyncValue<List<domain.Note>>>((ref) {
  final notesAsync = ref.watch(notesStreamProvider);
  final selectedTag = ref.watch(selectedNoteTagProvider);
  return notesAsync.whenData((notes) {
    final visibleNotes = notes.where((n) => n.kind != domain.NoteKind.memo);
    if (selectedTag == null) return visibleNotes.toList();
    return visibleNotes.where((n) => n.tags.contains(selectedTag)).toList();
  });
});

final notesByTaskIdProvider = StreamProvider.family<List<domain.Note>, String>((
  ref,
  taskId,
) {
  return ref.watch(noteRepositoryProvider).watchNotesByTaskId(taskId);
});

final noteByIdProvider = StreamProvider.family<domain.Note?, String>((
  ref,
  noteId,
) {
  return ref.watch(noteRepositoryProvider).watchAllNotes().map((notes) {
    for (final note in notes) {
      if (note.id == noteId) return note;
    }
    return null;
  });
});

final weaveLinksByTargetNoteIdProvider =
    StreamProvider.family<List<domain.WeaveLink>, String>((ref, noteId) {
      return ref
          .watch(weaveLinkRepositoryProvider)
          .watchLinksByTargetNoteId(noteId);
    });

final weaveLinksBySourceProvider =
    StreamProvider.family<
      List<domain.WeaveLink>,
      ({domain.WeaveSourceType sourceType, String sourceId})
    >((ref, args) {
      return ref
          .watch(weaveLinkRepositoryProvider)
          .watchLinksBySource(
            sourceType: args.sourceType,
            sourceId: args.sourceId,
          );
    });
