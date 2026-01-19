import 'package:domain/domain.dart' as domain;

const collectAnchorToken = '[[收集箱]]';
final collectAnchorPattern = RegExp(r'\[\[\s*(收集箱|COLLECT)\s*\]\]');

typedef CollectAnchorSplit = ({bool hasAnchor, String before, String after});

CollectAnchorSplit splitCollectAnchor(String body) {
  final normalized = body.replaceAll('\r\n', '\n');
  final match = collectAnchorPattern.firstMatch(normalized);
  if (match == null) {
    return (hasAnchor: false, before: normalized, after: '');
  }

  final beforeRaw = normalized.substring(0, match.start);
  final afterRaw = normalized.substring(match.end);
  String clean(String s) => s.replaceAll(collectAnchorPattern, '');
  return (hasAnchor: true, before: clean(beforeRaw), after: clean(afterRaw));
}

String ensureCollectAnchor(String body) {
  final normalized = body.replaceAll('\r\n', '\n').trimRight();
  if (collectAnchorPattern.hasMatch(normalized)) return normalized;
  if (normalized.isEmpty) return collectAnchorToken;
  return '$normalized\n\n$collectAnchorToken';
}

String insertAfterCollectAnchor(String body, String insert) {
  final normalized = body.replaceAll('\r\n', '\n');
  final content = insert.replaceAll('\r\n', '\n').trim();
  if (content.isEmpty) return normalized;

  var anchored = normalized;
  if (!collectAnchorPattern.hasMatch(anchored)) {
    anchored = ensureCollectAnchor(anchored);
  }

  final match = collectAnchorPattern.firstMatch(anchored);
  if (match == null) return '$anchored\n\n$content';

  final head = anchored.substring(0, match.end);
  final tail = anchored.substring(match.end);
  final tailWithoutLeadingNewlines = tail.replaceFirst(RegExp(r'^\n*'), '');
  final inserted = '\n\n$content';

  if (tailWithoutLeadingNewlines.trim().isEmpty) {
    return '$head$inserted';
  }
  return '$head$inserted\n\n$tailWithoutLeadingNewlines';
}

String formatWeaveCopyBlockFromNote(domain.Note note) {
  final label = switch (note.kind) {
    domain.NoteKind.memo => '闪念',
    domain.NoteKind.draft => '草稿',
    domain.NoteKind.longform => '笔记',
  };
  final header = '$label：${note.title.value}';
  final body = note.body.trimRight();
  final lines = <String>[
    header,
    if (body.isNotEmpty) ...body.split('\n').map((l) => l.trimRight()),
  ];
  return lines.map((l) => '> $l').join('\n');
}

String formatWeaveCopyBlockFromTask(domain.Task task) {
  final lines = <String>['任务：${task.title.value}'];
  if (task.tags.isNotEmpty) {
    lines.add('标签：${task.tags.join(' · ')}');
  }
  if (task.dueAt != null) {
    final due = task.dueAt!;
    lines.add(
      '截止：${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
    );
  }
  final desc = task.description?.trimRight() ?? '';
  if (desc.trim().isNotEmpty) {
    lines.addAll(desc.split('\n').map((l) => l.trimRight()));
  }
  return lines.map((l) => '> $l').join('\n');
}
