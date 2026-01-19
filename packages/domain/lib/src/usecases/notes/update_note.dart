import '../../entities/note.dart';
import '../../entities/triage_status.dart';
import '../../repositories/note_repository.dart';
import '../../value_objects/note_title.dart';

typedef _Now = DateTime Function();

class UpdateNoteUseCase {
  UpdateNoteUseCase({
    required NoteRepository repository,
    _Now now = DateTime.now,
  }) : _repository = repository,
       _now = now;

  final NoteRepository _repository;
  final _Now _now;

  Future<Note> call({
    required Note note,
    required String title,
    required String body,
    required List<String> tags,
    String? taskId,
    NoteKind? kind,
    TriageStatus? triageStatus,
  }) async {
    final updated = Note(
      id: note.id,
      title: NoteTitle(title),
      body: body.trimRight(),
      tags: tags,
      taskId: taskId?.trim().isEmpty == true ? null : taskId?.trim(),
      createdAt: note.createdAt,
      updatedAt: _now(),
      kind: kind ?? note.kind,
      triageStatus: triageStatus ?? note.triageStatus,
    );
    await _repository.upsertNote(updated);
    return updated;
  }
}
