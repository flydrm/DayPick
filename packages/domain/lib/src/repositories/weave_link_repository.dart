import '../entities/weave_link.dart';

abstract interface class WeaveLinkRepository {
  Stream<List<WeaveLink>> watchLinksByTargetNoteId(String targetNoteId);
  Stream<List<WeaveLink>> watchLinksBySource({
    required WeaveSourceType sourceType,
    required String sourceId,
  });

  Future<void> upsertLink(WeaveLink link);
  Future<void> deleteLink(String linkId);
}
