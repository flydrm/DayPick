class CalendarBusyInterval {
  const CalendarBusyInterval({required this.startMinute, required this.endMinute})
    : assert(startMinute >= 0),
      assert(endMinute >= 0),
      assert(startMinute <= 1440),
      assert(endMinute <= 1440),
      assert(endMinute >= startMinute);

  final int startMinute;
  final int endMinute;
}

class CalendarBusyFreeSummary {
  const CalendarBusyFreeSummary({
    required this.dayKey,
    required this.busyIntervals,
    required this.freeSlotsCount,
  });

  final String dayKey; // YYYY-MM-DD (local day)
  final List<CalendarBusyInterval> busyIntervals;
  final int freeSlotsCount;
}

