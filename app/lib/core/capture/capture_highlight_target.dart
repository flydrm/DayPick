import 'capture_submit_result.dart';

enum CaptureHighlightKind { task, note }

class CaptureHighlightTarget {
  const CaptureHighlightTarget({
    required this.kind,
    required this.entryId,
  });

  final CaptureHighlightKind kind;
  final String entryId;

  String get serialized {
    return '${_kindToToken(kind)}:$entryId';
  }

  static CaptureHighlightTarget fromSubmitResult(CaptureSubmitResult result) {
    return CaptureHighlightTarget(
      kind: _kindFromEntryKind(result.entryKind),
      entryId: result.entryId,
    );
  }

  static CaptureHighlightTarget? parse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    final separatorIndex = value.indexOf(':');
    if (separatorIndex <= 0 || separatorIndex == value.length - 1) {
      return null;
    }

    final kindToken = value.substring(0, separatorIndex).trim();
    final entryId = value.substring(separatorIndex + 1).trim();
    if (entryId.isEmpty) return null;

    final kind = _kindFromToken(kindToken);
    if (kind == null) return null;

    return CaptureHighlightTarget(kind: kind, entryId: entryId);
  }

  static CaptureHighlightKind _kindFromEntryKind(CaptureEntryKind entryKind) {
    return switch (entryKind) {
      CaptureEntryKind.task => CaptureHighlightKind.task,
      CaptureEntryKind.memo || CaptureEntryKind.draft =>
        CaptureHighlightKind.note,
    };
  }

  static String _kindToToken(CaptureHighlightKind kind) {
    return switch (kind) {
      CaptureHighlightKind.task => 'task',
      CaptureHighlightKind.note => 'note',
    };
  }

  static CaptureHighlightKind? _kindFromToken(String token) {
    return switch (token) {
      'task' => CaptureHighlightKind.task,
      'note' => CaptureHighlightKind.note,
      _ => null,
    };
  }
}
