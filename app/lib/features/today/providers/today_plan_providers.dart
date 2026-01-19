import 'dart:async';
import 'dart:io';

import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

bool get _isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

DateTime _normalizeDay(DateTime day) => DateTime(day.year, day.month, day.day);

final todayDayProvider = StreamProvider<DateTime>((ref) {
  if (_isFlutterTest) {
    return Stream.value(_normalizeDay(DateTime.now()));
  }

  final controller = StreamController<DateTime>();
  Timer? timer;

  void emitNow() {
    controller.add(_normalizeDay(DateTime.now()));
  }

  void scheduleNextTick() {
    timer?.cancel();
    final now = DateTime.now();
    final tomorrow = _normalizeDay(now).add(const Duration(days: 1));
    final delay = tomorrow.difference(now) + const Duration(milliseconds: 250);
    timer = Timer(delay, () {
      emitNow();
      scheduleNextTick();
    });
  }

  emitNow();
  scheduleNextTick();

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream.distinct();
});

final todayPlanTaskIdsProvider = StreamProvider<List<String>>((ref) {
  final day =
      ref.watch(todayDayProvider).valueOrNull ?? _normalizeDay(DateTime.now());
  return ref
      .watch(todayPlanRepositoryProvider)
      .watchTaskIdsForDay(day: day, section: domain.TodayPlanSection.today);
});

final todayEveningPlanTaskIdsProvider = StreamProvider<List<String>>((ref) {
  final day =
      ref.watch(todayDayProvider).valueOrNull ?? _normalizeDay(DateTime.now());
  return ref
      .watch(todayPlanRepositoryProvider)
      .watchTaskIdsForDay(day: day, section: domain.TodayPlanSection.evening);
});

final todayPlanTaskIdsForDayProvider =
    StreamProvider.family<List<String>, DateTime>((ref, day) {
      final normalized = DateTime(day.year, day.month, day.day);
      return ref
          .watch(todayPlanRepositoryProvider)
          .watchTaskIdsForDay(
            day: normalized,
            section: domain.TodayPlanSection.today,
          );
    });

final todayEveningPlanTaskIdsForDayProvider =
    StreamProvider.family<List<String>, DateTime>((ref, day) {
      final normalized = DateTime(day.year, day.month, day.day);
      return ref
          .watch(todayPlanRepositoryProvider)
          .watchTaskIdsForDay(
            day: normalized,
            section: domain.TodayPlanSection.evening,
          );
    });
