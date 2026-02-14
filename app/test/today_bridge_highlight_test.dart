import 'package:daypick/features/today/view/today_bridge_highlight.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

List<domain.Task> _tasks(List<String> ids) {
  final now = DateTime(2026, 1, 1, 9);
  return [
    for (final id in ids)
      domain.Task(
        id: id,
        title: domain.TaskTitle(id),
        status: domain.TaskStatus.todo,
        priority: domain.TaskPriority.medium,
        tags: const [],
        estimatedPomodoros: 1,
        createdAt: now,
        updatedAt: now,
        triageStatus: domain.TriageStatus.scheduledLater,
      ),
  ];
}

void main() {
  test('returns empty state when highlight is missing/invalid', () {
    final missing = resolveTodayBridgeHighlight(
      rawHighlight: null,
      tasks: _tasks(['t-1']),
    );
    final invalid = resolveTodayBridgeHighlight(
      rawHighlight: 'bad-format',
      tasks: _tasks(['t-1']),
    );

    expect(missing.highlightedEntryId, isNull);
    expect(missing.fallbackMessage, isNull);
    expect(invalid.highlightedEntryId, isNull);
    expect(invalid.fallbackMessage, isNull);
  });

  test('highlights task when target exists', () {
    final state = resolveTodayBridgeHighlight(
      rawHighlight: 'task:t-1',
      tasks: _tasks(['t-1', 't-2']),
    );

    expect(state.highlightedEntryId, 't-1');
    expect(state.fallbackMessage, isNull);
  });

  test('returns fallback when target task is missing', () {
    final state = resolveTodayBridgeHighlight(
      rawHighlight: 'task:t-missing',
      tasks: _tasks(['t-1', 't-2']),
    );

    expect(state.highlightedEntryId, isNull);
    expect(state.fallbackMessage, '已加入，但未定位到条目。');
  });

  test('returns note fallback for note target', () {
    final state = resolveTodayBridgeHighlight(
      rawHighlight: 'note:n-1',
      tasks: _tasks(['t-1']),
    );

    expect(state.highlightedEntryId, isNull);
    expect(state.fallbackMessage, '已创建笔记，但 Today 仅支持任务定位。');
  });
}
