import 'package:domain/domain.dart' as domain;

import '../../../core/capture/capture_highlight_target.dart';

class TodayBridgeHighlightState {
  const TodayBridgeHighlightState({
    this.highlightedEntryId,
    this.fallbackMessage,
  });

  final String? highlightedEntryId;
  final String? fallbackMessage;
}

TodayBridgeHighlightState resolveTodayBridgeHighlight({
  required String? rawHighlight,
  required List<domain.Task> tasks,
}) {
  final target = CaptureHighlightTarget.parse(rawHighlight);
  if (target == null) return const TodayBridgeHighlightState();

  if (target.kind == CaptureHighlightKind.note) {
    return const TodayBridgeHighlightState(
      highlightedEntryId: null,
      fallbackMessage: '已创建笔记，但 Today 仅支持任务定位。',
    );
  }

  final exists = tasks.any((task) => task.id == target.entryId);
  if (!exists) {
    return const TodayBridgeHighlightState(
      highlightedEntryId: null,
      fallbackMessage: '已加入，但未定位到条目。',
    );
  }

  return TodayBridgeHighlightState(
    highlightedEntryId: target.entryId,
    fallbackMessage: null,
  );
}
