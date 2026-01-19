import 'dart:io';

import 'package:domain/domain.dart' as domain;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

typedef NotificationTapCallback = void Function(String? payload);

class LocalNotificationsService
    implements domain.PomodoroNotificationScheduler {
  LocalNotificationsService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _pomodoroNotificationId = 2001;
  static const String _pomodoroChannelId = 'pomodoro';
  static const String _pomodoroChannelName = '番茄提醒';
  static const String _pomodoroChannelDescription = '番茄到点提醒';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _tzInitialized = false;

  Future<void> initialize({NotificationTapCallback? onTap}) async {
    if (_initialized) return;

    if (!_tzInitialized) {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        onTap?.call(response.payload);
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _pomodoroChannelId,
          _pomodoroChannelName,
          description: _pomodoroChannelDescription,
          importance: Importance.defaultImportance,
        ),
      );
    }

    _initialized = true;
  }

  Future<bool> requestNotificationsPermissionIfNeeded() async {
    if (!Platform.isAndroid) return true;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;

    try {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<String?> getLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> schedulePomodoroEnd({
    required String taskId,
    required String taskTitle,
    required DateTime endAt,
    required bool playSound,
    required bool enableVibration,
  }) async {
    await initialize();

    final title = taskTitle.trim().isEmpty ? '专注结束' : taskTitle.trim();
    final body = '到点提醒';
    final now = DateTime.now();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _pomodoroChannelId,
        _pomodoroChannelName,
        channelDescription: _pomodoroChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.high,
        playSound: playSound,
        enableVibration: enableVibration,
      ),
    );

    final payload = 'pomodoro_end:$taskId';
    if (!endAt.isAfter(now)) {
      await _plugin.show(
        _pomodoroNotificationId,
        title,
        body,
        details,
        payload: payload,
      );
      return;
    }

    final scheduledDate = tz.TZDateTime.from(endAt.toUtc(), tz.UTC);
    await _plugin.zonedSchedule(
      _pomodoroNotificationId,
      title,
      body,
      scheduledDate,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelPomodoroEnd() async {
    await initialize();
    await _plugin.cancel(_pomodoroNotificationId);
  }
}
