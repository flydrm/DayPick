import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CaptureBarType { task, memo, draft }

@immutable
class CaptureBarDraft {
  const CaptureBarDraft({
    required this.type,
    required this.text,
  });

  const CaptureBarDraft.initial() : this(type: CaptureBarType.memo, text: '');

  final CaptureBarType type;
  final String text;

  CaptureBarDraft copyWith({
    CaptureBarType? type,
    String? text,
  }) {
    return CaptureBarDraft(
      type: type ?? this.type,
      text: text ?? this.text,
    );
  }
}

class CaptureBarDraftNotifier extends Notifier<CaptureBarDraft> {
  @override
  CaptureBarDraft build() => const CaptureBarDraft.initial();

  void setText(String text) {
    if (text == state.text) return;
    state = state.copyWith(text: text);
  }

  void setType(CaptureBarType type) {
    if (type == state.type) return;
    state = state.copyWith(type: type);
  }

  void clear() {
    if (state.text.isEmpty) return;
    state = state.copyWith(text: '');
  }
}

final captureBarDraftProvider =
    NotifierProvider<CaptureBarDraftNotifier, CaptureBarDraft>(
      CaptureBarDraftNotifier.new,
    );
