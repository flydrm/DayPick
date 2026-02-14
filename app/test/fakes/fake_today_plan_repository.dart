import 'dart:async';

import 'package:domain/domain.dart' as domain;

class FakeTodayPlanRepository implements domain.TodayPlanRepository {
  final _store = <String, Map<domain.TodayPlanSection, List<String>>>{};
  final _controllers =
      <String, StreamController<List<String>>>{}; // key: dayKey|section

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }

  @override
  Stream<List<String>> watchTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) {
    final dayKey = _dayKey(day);
    final key = _controllerKey(dayKey, section);
    final controller = _controllers.putIfAbsent(
      key,
      () => StreamController<List<String>>.broadcast(),
    );
    return Stream<List<String>>.multi((multi) {
      multi.add(List.unmodifiable(_listFor(dayKey, section)));
      final sub = controller.stream.listen(
        multi.add,
        onError: multi.addError,
        onDone: multi.close,
      );
      multi.onCancel = sub.cancel;
    });
  }

  @override
  Future<List<String>> getTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final dayKey = _dayKey(day);
    return List.unmodifiable(_listFor(dayKey, section));
  }

  @override
  Future<void> addTask({
    required DateTime day,
    required String taskId,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final dayKey = _dayKey(day);
    final normalized = taskId.trim();
    if (normalized.isEmpty) return;

    final today = _listFor(dayKey, domain.TodayPlanSection.today);
    final evening = _listFor(dayKey, domain.TodayPlanSection.evening);
    today.remove(normalized);
    evening.remove(normalized);

    final target = section == domain.TodayPlanSection.today ? today : evening;
    target.add(normalized);

    _emit(dayKey, domain.TodayPlanSection.today);
    _emit(dayKey, domain.TodayPlanSection.evening);
  }

  @override
  Future<void> removeTask({required DateTime day, required String taskId}) async {
    final dayKey = _dayKey(day);
    final normalized = taskId.trim();
    if (normalized.isEmpty) return;

    final today = _listFor(dayKey, domain.TodayPlanSection.today);
    final evening = _listFor(dayKey, domain.TodayPlanSection.evening);
    today.remove(normalized);
    evening.remove(normalized);

    _emit(dayKey, domain.TodayPlanSection.today);
    _emit(dayKey, domain.TodayPlanSection.evening);
  }

  @override
  Future<void> replaceTasks({
    required DateTime day,
    required List<String> taskIds,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final dayKey = _dayKey(day);

    final unique = <String>[];
    for (final id in taskIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      if (!unique.contains(trimmed)) unique.add(trimmed);
    }

    final target = _listFor(dayKey, section);
    target
      ..clear()
      ..addAll(unique);

    final otherSection = section == domain.TodayPlanSection.today
        ? domain.TodayPlanSection.evening
        : domain.TodayPlanSection.today;
    final other = _listFor(dayKey, otherSection);
    other.removeWhere(unique.contains);

    _emit(dayKey, section);
    _emit(dayKey, otherSection);
  }

  @override
  Future<void> clearDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final dayKey = _dayKey(day);
    _listFor(dayKey, section).clear();
    _emit(dayKey, section);
  }

  @override
  Future<void> clearAll({required DateTime day}) async {
    final dayKey = _dayKey(day);
    _listFor(dayKey, domain.TodayPlanSection.today).clear();
    _listFor(dayKey, domain.TodayPlanSection.evening).clear();
    _emit(dayKey, domain.TodayPlanSection.today);
    _emit(dayKey, domain.TodayPlanSection.evening);
  }

  @override
  Future<void> moveTaskToSection({
    required DateTime day,
    required String taskId,
    required domain.TodayPlanSection section,
    int? toIndex,
  }) async {
    final dayKey = _dayKey(day);
    final normalized = taskId.trim();
    if (normalized.isEmpty) return;

    final today = _listFor(dayKey, domain.TodayPlanSection.today);
    final evening = _listFor(dayKey, domain.TodayPlanSection.evening);
    today.remove(normalized);
    evening.remove(normalized);

    final target = section == domain.TodayPlanSection.today ? today : evening;
    final insertIndex = toIndex == null
        ? target.length
        : toIndex.clamp(0, target.length);
    target.insert(insertIndex, normalized);

    _emit(dayKey, domain.TodayPlanSection.today);
    _emit(dayKey, domain.TodayPlanSection.evening);
  }

  List<String> _listFor(String dayKey, domain.TodayPlanSection section) {
    final dayMap = _store.putIfAbsent(dayKey, () {
      return {
        domain.TodayPlanSection.today: <String>[],
        domain.TodayPlanSection.evening: <String>[],
      };
    });
    return dayMap.putIfAbsent(section, () => <String>[]);
  }

  void _emit(String dayKey, domain.TodayPlanSection section) {
    final controller = _controllers[_controllerKey(dayKey, section)];
    controller?.add(List.unmodifiable(_listFor(dayKey, section)));
  }

  String _controllerKey(String dayKey, domain.TodayPlanSection section) {
    return '$dayKey|${section.name}';
  }

  String _dayKey(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
