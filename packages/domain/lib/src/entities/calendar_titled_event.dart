class CalendarTitledEvent {
  const CalendarTitledEvent({
    required this.start,
    required this.end,
    required this.title,
  });

  final DateTime start;
  final DateTime end;

  /// May be an empty string when the platform does not provide a title.
  final String title;
}
