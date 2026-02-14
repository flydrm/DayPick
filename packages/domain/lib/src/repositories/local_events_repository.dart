import '../entities/local_event.dart';

abstract interface class LocalEventsRepository {
  Future<void> insert(LocalEvent event);

  Future<List<LocalEvent>> getAll({int? limit});

  Future<List<LocalEvent>> getBetween({
    required int minOccurredAtUtcMsInclusive,
    required int maxOccurredAtUtcMsExclusive,
    List<String>? eventNames,
    int? limit,
  });

  Future<void> prune({required int minOccurredAtUtcMs, required int maxEvents});
}
