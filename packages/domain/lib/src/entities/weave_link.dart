enum WeaveSourceType { task, note, pomodoroSession }

enum WeaveMode { reference, copy }

class WeaveLink {
  const WeaveLink({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.targetNoteId,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final WeaveSourceType sourceType;
  final String sourceId;
  final String targetNoteId;
  final WeaveMode mode;
  final DateTime createdAt;
  final DateTime updatedAt;

  WeaveLink copyWith({WeaveMode? mode, DateTime? updatedAt}) {
    return WeaveLink(
      id: id,
      sourceType: sourceType,
      sourceId: sourceId,
      targetNoteId: targetNoteId,
      mode: mode ?? this.mode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
