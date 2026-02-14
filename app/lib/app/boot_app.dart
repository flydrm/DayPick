import 'dart:async';

import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/local_events/local_events_provider.dart';
import '../core/providers/app_providers.dart';
import '../features/safe_mode/model/safe_mode_reason.dart';
import '../features/safe_mode/view/safe_mode_page.dart';
import '../routing/app_router.dart';
import '../ui/tokens/dp_insets.dart';
import '../ui/tokens/dp_spacing.dart';
import 'daypick_app.dart';

enum _BootStatus { loading, safeMode, ready, fatal }

class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  _BootStatus _status = _BootStatus.loading;
  ProviderContainer? _container;
  Object? _fatalError;
  SafeModeInfo? _safeModeInfo;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _container?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _status = _BootStatus.loading;
      _fatalError = null;
      _safeModeInfo = null;
    });

    final old = _container;
    _container = null;
    old?.dispose();

    final container = ProviderContainer();

    try {
      await container.read(featureFlagsProvider).initialize();

      final notifications = container.read(localNotificationsServiceProvider);
      await notifications.initialize(
        onTap: (payload) {
          final taskId = _taskIdFromPayload(payload);
          final location = taskId == null ? '/focus' : '/focus?taskId=$taskId';
          container.read(goRouterProvider).go(location);
        },
      );

      final launchPayload = await notifications.getLaunchPayload();

      await _rescheduleActivePomodoroNotification(container);

      await _flushPendingSafeModeEvent(container);

      _container = container;
      if (!mounted) return;
      setState(() => _status = _BootStatus.ready);

      final launchTaskId = _taskIdFromPayload(launchPayload);
      if (launchTaskId != null) {
        Future.microtask(
          () => container
              .read(goRouterProvider)
              .go('/focus?taskId=$launchTaskId'),
        );
      }

      Future.microtask(() async {
        try {
          await container
              .read(kpiAggregationServiceProvider)
              .aggregateRecentDays();
        } catch (_) {}
      });
    } catch (e) {
      container.dispose();

      final safeInfo = safeModeInfoFromError(e);
      if (safeInfo != null) {
        await _storePendingSafeModeEvent(reason: safeInfo.reason.code);
        if (!mounted) return;
        setState(() {
          _status = _BootStatus.safeMode;
          _safeModeInfo = safeInfo;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _status = _BootStatus.fatal;
        _fatalError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _BootStatus.ready) {
      return UncontrolledProviderScope(
        container: _container!,
        child: const DayPickApp(),
      );
    }

    final page = switch (_status) {
      _BootStatus.loading => const _BootLoadingPage(),
      _BootStatus.safeMode => SafeModePage(
        info: _safeModeInfo ?? const SafeModeInfo(reason: SafeModeReason.other),
        onRetryBootstrap: _bootstrap,
      ),
      _BootStatus.fatal => _BootFatalPage(
        error: _fatalError,
        onRetry: _bootstrap,
      ),
      _BootStatus.ready => const SizedBox.shrink(),
    };

    return _BootThemedApp(child: page);
  }

  Future<void> _storePendingSafeModeEvent({required String reason}) async {
    try {
      await data.SafeModePendingEventStore().writePending(reason: reason);
    } catch (_) {}
  }

  Future<void> _flushPendingSafeModeEvent(ProviderContainer container) async {
    String? reason;
    try {
      reason = await data.SafeModePendingEventStore().readPendingReason();
    } catch (_) {
      return;
    }
    if (reason == null) return;

    try {
      await container
          .read(localEventsServiceProvider)
          .record(
            eventName: domain.LocalEventNames.safeModeEntered,
            metaJson: {'reason': reason},
          );
    } catch (_) {
      return;
    } finally {
      try {
        await data.SafeModePendingEventStore().clear();
      } catch (_) {}
    }
  }
}

class _BootThemedApp extends StatelessWidget {
  const _BootThemedApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    ShadThemeData themeFor(Brightness brightness) {
      final scheme = ShadColorScheme.fromName('blue', brightness: brightness);
      return ShadThemeData(brightness: brightness, colorScheme: scheme);
    }

    return ShadApp.custom(
      themeMode: ThemeMode.system,
      theme: themeFor(Brightness.light),
      darkTheme: themeFor(Brightness.dark),
      appBuilder: (context) {
        final baseTheme = Theme.of(context);
        final materialTheme = ThemeData.from(
          colorScheme: baseTheme.colorScheme,
          textTheme: baseTheme.textTheme,
          useMaterial3: false,
        );
        return MaterialApp(
          title: 'DayPick · 一页今日',
          debugShowCheckedModeBanner: false,
          theme: materialTheme,
          home: ShadAppBuilder(child: child),
        );
      },
    );
  }
}

class _BootLoadingPage extends StatelessWidget {
  const _BootLoadingPage();

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Center(
          child: Text(
            '启动中…',
            style: shadTheme.textTheme.p.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _BootFatalPage extends StatelessWidget {
  const _BootFatalPage({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: DpInsets.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '启动失败',
                style: shadTheme.textTheme.h2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                '遇到未知错误，建议重启应用或联系开发者。',
                style: shadTheme.textTheme.p.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              Text(
                'error：${error.runtimeType}',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const Spacer(),
              ShadButton(onPressed: onRetry, child: const Text('重试')),
              const SizedBox(height: DpSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

String? _taskIdFromPayload(String? payload) {
  if (payload == null) return null;
  const prefix = 'pomodoro_end:';
  if (!payload.startsWith(prefix)) return null;
  final taskId = payload.substring(prefix.length).trim();
  return taskId.isEmpty ? null : taskId;
}

Future<void> _rescheduleActivePomodoroNotification(
  ProviderContainer container,
) async {
  final config = await container.read(pomodoroConfigRepositoryProvider).get();
  final active = await container.read(activePomodoroRepositoryProvider).get();
  if (active == null) {
    await container.read(cancelPomodoroNotificationUseCaseProvider)();
    return;
  }

  if (active.status != domain.ActivePomodoroStatus.running ||
      active.endAt == null) {
    await container.read(cancelPomodoroNotificationUseCaseProvider)();
    return;
  }

  final endAt = active.endAt!;
  if (!endAt.isAfter(DateTime.now())) return;

  final title = await _notificationTitleForActive(container, active);

  await container.read(schedulePomodoroNotificationUseCaseProvider)(
    taskId: active.taskId,
    taskTitle: title,
    endAt: endAt,
    playSound: config.notificationSound,
    enableVibration: config.notificationVibration,
  );
}

Future<String> _notificationTitleForActive(
  ProviderContainer container,
  domain.ActivePomodoro active,
) async {
  return switch (active.phase) {
    domain.PomodoroPhase.focus => () async {
      final task = await container
          .read(taskRepositoryProvider)
          .getTaskById(active.taskId);
      final taskTitle = task?.title.value.trim() ?? '';
      if (taskTitle.isEmpty) return '专注结束';
      return '专注结束 · $taskTitle';
    }(),
    domain.PomodoroPhase.shortBreak => '短休结束',
    domain.PomodoroPhase.longBreak => '长休结束',
  };
}
