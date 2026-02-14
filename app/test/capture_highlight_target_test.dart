import 'package:daypick/core/capture/capture_highlight_target.dart';
import 'package:daypick/core/capture/capture_submit_result.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

CaptureSubmitResult _submitResult({
  required String id,
  required CaptureEntryKind kind,
}) {
  return CaptureSubmitResult(
    entryId: id,
    entryKind: kind,
    triageStatus: domain.TriageStatus.inbox,
  );
}

void main() {
  group('CaptureHighlightTarget.fromSubmitResult', () {
    test('maps task to task target', () {
      final target = CaptureHighlightTarget.fromSubmitResult(
        _submitResult(id: 't-1', kind: CaptureEntryKind.task),
      );

      expect(target.kind, CaptureHighlightKind.task);
      expect(target.entryId, 't-1');
      expect(target.serialized, 'task:t-1');
    });

    test('maps memo/draft to note target', () {
      final memoTarget = CaptureHighlightTarget.fromSubmitResult(
        _submitResult(id: 'n-1', kind: CaptureEntryKind.memo),
      );
      final draftTarget = CaptureHighlightTarget.fromSubmitResult(
        _submitResult(id: 'n-2', kind: CaptureEntryKind.draft),
      );

      expect(memoTarget.kind, CaptureHighlightKind.note);
      expect(memoTarget.serialized, 'note:n-1');
      expect(draftTarget.kind, CaptureHighlightKind.note);
      expect(draftTarget.serialized, 'note:n-2');
    });
  });

  group('CaptureHighlightTarget.parse', () {
    test('parses valid task target', () {
      final target = CaptureHighlightTarget.parse('task:t-1');

      expect(target, isNotNull);
      expect(target!.kind, CaptureHighlightKind.task);
      expect(target.entryId, 't-1');
    });

    test('parses valid note target', () {
      final target = CaptureHighlightTarget.parse(' note:n-1 ');

      expect(target, isNotNull);
      expect(target!.kind, CaptureHighlightKind.note);
      expect(target.entryId, 'n-1');
    });

    test('returns null for malformed input', () {
      expect(CaptureHighlightTarget.parse(null), isNull);
      expect(CaptureHighlightTarget.parse(''), isNull);
      expect(CaptureHighlightTarget.parse('task'), isNull);
      expect(CaptureHighlightTarget.parse(':id'), isNull);
      expect(CaptureHighlightTarget.parse('task:'), isNull);
      expect(CaptureHighlightTarget.parse('unknown:x'), isNull);
    });
  });
}
