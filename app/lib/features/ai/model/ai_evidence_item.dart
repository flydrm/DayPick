enum AiEvidenceType { note, task, pomodoro }

class AiEvidenceItem {
  const AiEvidenceItem({
    required this.key,
    required this.type,
    required this.title,
    required this.snippet,
    required this.route,
    required this.at,
    this.tags = const [],
  });

  final String key;
  final AiEvidenceType type;
  final String title;
  final String snippet;
  final String route;
  final DateTime at;
  final List<String> tags;

  String get typeLabel => switch (type) {
    AiEvidenceType.note => '笔记',
    AiEvidenceType.task => '任务',
    AiEvidenceType.pomodoro => '专注',
  };
}
