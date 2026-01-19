import '../value_objects/note_title.dart';
import 'triage_status.dart';

enum NoteKind { longform, memo, draft }

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.tags,
    this.taskId,
    required this.createdAt,
    required this.updatedAt,
    this.kind = NoteKind.longform,
    this.triageStatus = TriageStatus.scheduledLater,
  });

  final String id;
  final NoteTitle title;
  final String body;
  final List<String> tags;
  final String? taskId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NoteKind kind;
  final TriageStatus triageStatus;

  Note copyWith({
    NoteTitle? title,
    String? body,
    List<String>? tags,
    Object? taskId = _unset,
    DateTime? updatedAt,
    NoteKind? kind,
    TriageStatus? triageStatus,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      taskId: identical(taskId, _unset) ? this.taskId : taskId as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kind: kind ?? this.kind,
      triageStatus: triageStatus ?? this.triageStatus,
    );
  }
}
