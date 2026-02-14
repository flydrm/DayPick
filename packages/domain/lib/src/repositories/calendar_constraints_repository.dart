import '../entities/calendar_busy_free_summary.dart';
import '../entities/calendar_date_time_range.dart';
import '../entities/calendar_permission_state.dart';
import '../entities/calendar_titled_event.dart';

abstract interface class CalendarConstraintsRepository {
  Future<CalendarPermissionState> getPermissionState();
  Future<CalendarPermissionState> requestPermission();
  Future<void> openAppSettings();

  Future<CalendarBusyFreeSummary> getBusyFreeSummaryForDay({
    required DateTime dayLocal,
  });

  Future<List<CalendarTitledEvent>> getTitledEventsForDay({
    required DateTime dayLocal,
  });

  Future<CalendarBusyFreeSummary> computeBusyFreeSummary({
    required DateTime dayLocal,
    required List<CalendarDateTimeRange> busyRangesLocal,
  });
}
