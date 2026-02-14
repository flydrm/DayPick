import 'package:domain/domain.dart' as domain;
import 'package:flutter/foundation.dart';

enum CaptureEntryKind { task, memo, draft }

@immutable
class CaptureSubmitResult {
  const CaptureSubmitResult({
    required this.entryId,
    required this.entryKind,
    required this.triageStatus,
  });

  final String entryId;
  final CaptureEntryKind entryKind;
  final domain.TriageStatus triageStatus;
}
