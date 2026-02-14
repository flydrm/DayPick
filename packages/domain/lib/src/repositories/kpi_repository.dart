import '../entities/kpi_daily_rollup.dart';

abstract interface class KpiRepository {
  Future<void> upsert(KpiDailyRollup rollup);

  Future<List<KpiDailyRollup>> getByDayKeyRange({
    required String startDayKeyInclusive,
    required String endDayKeyInclusive,
    String? segment,
  });
}
