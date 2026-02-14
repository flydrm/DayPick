import 'dart:io';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/services.dart';

class PlatformCalendarConstraintsRepository
    implements domain.CalendarConstraintsRepository {
  PlatformCalendarConstraintsRepository({
    MethodChannel? channel,
    domain.CalendarBusyFreeCalculator? calculator,
    bool Function()? isSupported,
    bool Function()? isTitleReadEnabled,
  }) : _channel = channel ?? _defaultChannel,
       _calculator = calculator ?? const domain.CalendarBusyFreeCalculator(),
       _isSupported = isSupported ?? _defaultIsSupported,
       _isTitleReadEnabled = isTitleReadEnabled ?? _defaultIsTitleReadEnabled;

  static const _defaultChannel = MethodChannel('daypick/calendar_constraints');

  static bool _defaultIsSupported() {
    final isTest = Platform.environment['FLUTTER_TEST'] == 'true';
    return Platform.isAndroid || isTest;
  }

  static bool _defaultIsTitleReadEnabled() => false;

  final MethodChannel _channel;
  final domain.CalendarBusyFreeCalculator _calculator;
  final bool Function() _isSupported;
  final bool Function() _isTitleReadEnabled;

  @override
  Future<domain.CalendarPermissionState> getPermissionState() async {
    if (!_isSupported()) return domain.CalendarPermissionState.notSupported;
    try {
      final raw = await _channel.invokeMethod<String>('getPermissionState');
      return _parsePermissionState(raw);
    } on MissingPluginException {
      return domain.CalendarPermissionState.notSupported;
    } on PlatformException {
      return domain.CalendarPermissionState.unknown;
    }
  }

  @override
  Future<domain.CalendarPermissionState> requestPermission() async {
    if (!_isSupported()) return domain.CalendarPermissionState.notSupported;
    try {
      final raw = await _channel.invokeMethod<String>('requestPermission');
      return _parsePermissionState(raw);
    } on MissingPluginException {
      return domain.CalendarPermissionState.notSupported;
    } on PlatformException {
      return domain.CalendarPermissionState.unknown;
    }
  }

  @override
  Future<void> openAppSettings() async {
    if (!_isSupported()) return;
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  @override
  Future<domain.CalendarBusyFreeSummary> getBusyFreeSummaryForDay({
    required DateTime dayLocal,
  }) async {
    if (!_isSupported()) {
      return _calculator.summarize(day: dayLocal, busyRangesLocal: const []);
    }

    final dayStartLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final dayEndLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day + 1);
    final raw = await _channel.invokeMethod<List>(
      'getBusyIntervals',
      {
        'start_ms': dayStartLocal.millisecondsSinceEpoch,
        'end_ms': dayEndLocal.millisecondsSinceEpoch,
      },
    );

    final busyRanges = <domain.CalendarDateTimeRange>[];
    if (raw != null) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final startMs = entry['start_ms'];
        final endMs = entry['end_ms'];
        if (startMs is! int || endMs is! int) continue;
        final start = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
        final end = DateTime.fromMillisecondsSinceEpoch(endMs).toLocal();
        busyRanges.add(domain.CalendarDateTimeRange(start: start, end: end));
      }
    }

    return _calculator.summarize(day: dayLocal, busyRangesLocal: busyRanges);
  }

  @override
  Future<List<domain.CalendarTitledEvent>> getTitledEventsForDay({
    required DateTime dayLocal,
  }) async {
    if (!_isSupported()) return const [];
    if (!_isTitleReadEnabled()) return const [];

    final permissionState = await getPermissionState();
    if (permissionState != domain.CalendarPermissionState.granted) return const [];

    final dayStartLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final dayEndLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day + 1);

    try {
      final raw = await _channel.invokeMethod<List>(
        'getTitledEvents',
        {
          'start_ms': dayStartLocal.millisecondsSinceEpoch,
          'end_ms': dayEndLocal.millisecondsSinceEpoch,
        },
      );

      final events = <domain.CalendarTitledEvent>[];
      if (raw != null) {
        for (final entry in raw) {
          if (entry is! Map) continue;
          final startMs = entry['start_ms'];
          final endMs = entry['end_ms'];
          if (startMs is! int || endMs is! int) continue;
          if (endMs <= startMs) continue;

          final titleRaw = entry['title'];
          final title = titleRaw is String ? titleRaw : '';

          final start = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
          final end = DateTime.fromMillisecondsSinceEpoch(endMs).toLocal();
          events.add(domain.CalendarTitledEvent(start: start, end: end, title: title));
        }
      }

      return events;
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<domain.CalendarBusyFreeSummary> computeBusyFreeSummary({
    required DateTime dayLocal,
    required List<domain.CalendarDateTimeRange> busyRangesLocal,
  }) async {
    return _calculator.summarize(day: dayLocal, busyRangesLocal: busyRangesLocal);
  }

  domain.CalendarPermissionState _parsePermissionState(String? raw) {
    switch (raw) {
      case 'granted':
        return domain.CalendarPermissionState.granted;
      case 'denied':
        return domain.CalendarPermissionState.denied;
      case 'restricted':
        return domain.CalendarPermissionState.restricted;
      case 'not_supported':
        return domain.CalendarPermissionState.notSupported;
      case 'unknown':
      default:
        return domain.CalendarPermissionState.unknown;
    }
  }
}
