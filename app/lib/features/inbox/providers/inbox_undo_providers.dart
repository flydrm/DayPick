import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

typedef InboxUndoCallback = Future<void> Function();

class InboxUndoEntry {
  const InboxUndoEntry({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.undo,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final InboxUndoCallback undo;
}

class InboxUndoStackNotifier extends StateNotifier<List<InboxUndoEntry>> {
  InboxUndoStackNotifier({
    required String Function() generateId,
    this.maxEntries = 10,
  }) : _generateId = generateId,
       super(const []);

  final String Function() _generateId;
  final int maxEntries;

  InboxUndoEntry push({
    required String message,
    required InboxUndoCallback undo,
  }) {
    final entry = InboxUndoEntry(
      id: _generateId(),
      message: message,
      createdAt: DateTime.now(),
      undo: undo,
    );
    state = [entry, ...state].take(maxEntries).toList(growable: false);
    return entry;
  }

  Future<void> undoById(String id) async {
    final entries = state;
    final entryIndex = entries.indexWhere((e) => e.id == id);
    if (entryIndex < 0) return;
    final entry = entries[entryIndex];

    await entry.undo();
    state = [
      for (final e in entries)
        if (e.id != id) e,
    ];
  }

  void remove(String id) {
    state = [
      for (final e in state)
        if (e.id != id) e,
    ];
  }

  void clear() => state = const [];
}

final inboxUndoStackProvider =
    StateNotifierProvider<InboxUndoStackNotifier, List<InboxUndoEntry>>((ref) {
      final uuid = ref.watch(uuidProvider);
      return InboxUndoStackNotifier(generateId: () => uuid.v4());
    });
