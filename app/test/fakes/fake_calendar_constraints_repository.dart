import 'package:domain/domain.dart' as domain;

class FakeCalendarConstraintsRepository implements domain.CalendarConstraintsRepository {
  FakeCalendarConstraintsRepository({
    this.permissionState = domain.CalendarPermissionState.unknown,
    domain.CalendarPermissionState? requestPermissionResult,
    this.summary,
    this.titledEvents = const [],
    this.readError,
  }) : _requestPermissionResult =
           requestPermissionResult ?? domain.CalendarPermissionState.denied;

  domain.CalendarPermissionState permissionState;
  final domain.CalendarPermissionState _requestPermissionResult;
  final domain.CalendarBusyFreeSummary? summary;
  final List<domain.CalendarTitledEvent> titledEvents;
  final Object? readError;

  int getPermissionStateCalls = 0;
  int requestPermissionCalls = 0;
  int openAppSettingsCalls = 0;
  int getBusyFreeSummaryCalls = 0;
  int getTitledEventsCalls = 0;

  @override
  Future<domain.CalendarPermissionState> getPermissionState() async {
    getPermissionStateCalls++;
    return permissionState;
  }

  @override
  Future<domain.CalendarPermissionState> requestPermission() async {
    requestPermissionCalls++;
    permissionState = _requestPermissionResult;
    return permissionState;
  }

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCalls++;
  }

  @override
  Future<domain.CalendarBusyFreeSummary> getBusyFreeSummaryForDay({
    required DateTime dayLocal,
  }) async {
    getBusyFreeSummaryCalls++;
    final error = readError;
    if (error != null) throw error;

    final fixed = summary;
    if (fixed != null) return fixed;

    final day = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return domain.CalendarBusyFreeSummary(
      dayKey: dayKey,
      busyIntervals: const [],
      freeSlotsCount: 1,
    );
  }

  @override
  Future<List<domain.CalendarTitledEvent>> getTitledEventsForDay({
    required DateTime dayLocal,
  }) async {
    getTitledEventsCalls++;
    return titledEvents;
  }

  @override
  Future<domain.CalendarBusyFreeSummary> computeBusyFreeSummary({
    required DateTime dayLocal,
    required List<domain.CalendarDateTimeRange> busyRangesLocal,
  }) async {
    return const domain.CalendarBusyFreeCalculator().summarize(
      day: dayLocal,
      busyRangesLocal: busyRangesLocal,
    );
  }
}
