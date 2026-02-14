import 'dart:async';
import 'dart:typed_data';

import 'package:data/data.dart' as data;
import 'package:daypick/core/local_events/local_events_provider.dart';
import 'package:daypick/core/local_events/local_events_service.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/stats/view/kpi_dashboard_tab.dart';
import 'package:daypick/ui/kit/dp_spinner.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _FakeKpiRepository implements domain.KpiRepository {
  _FakeKpiRepository({
    required Future<List<domain.KpiDailyRollup>> Function() load,
  }) : _load = load;

  final Future<List<domain.KpiDailyRollup>> Function() _load;

  @override
  Future<List<domain.KpiDailyRollup>> getByDayKeyRange({
    required String startDayKeyInclusive,
    required String endDayKeyInclusive,
    String? segment,
  }) {
    return _load();
  }

  @override
  Future<void> upsert(domain.KpiDailyRollup rollup) async {}
}

class _RecordedEvent {
  const _RecordedEvent(this.eventName, this.metaJson);

  final String eventName;
  final Map<String, Object?> metaJson;
}

class _FakeLocalEventsService implements LocalEventsService {
  final events = <_RecordedEvent>[];

  @override
  Future<bool> record({
    required String eventName,
    required Map<String, Object?> metaJson,
  }) async {
    events.add(_RecordedEvent(eventName, Map<String, Object?>.from(metaJson)));
    return true;
  }
}

class _FailingKpiMetricsExportService implements data.KpiMetricsExportService {
  @override
  Future<Uint8List> exportJsonBytes() async {
    throw StateError('export failed');
  }
}

ShadThemeData _themeFor(Brightness brightness) {
  final scheme = ShadColorScheme.fromName('blue', brightness: brightness);
  return ShadThemeData(brightness: brightness, colorScheme: scheme);
}

Future<void> _pumpKpiTab(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: ShadApp.custom(
        themeMode: ThemeMode.light,
        theme: _themeFor(Brightness.light),
        darkTheme: _themeFor(Brightness.dark),
        appBuilder: (context) => MaterialApp(
          home: const ShadAppBuilder(child: Scaffold(body: KpiDashboardTab())),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('KPI Dashboard：加载态展示 inline spinner', (tester) async {
    final completer = Completer<List<domain.KpiDailyRollup>>();

    await _pumpKpiTab(
      tester,
      overrides: [
        kpiRepositoryProvider.overrideWithValue(
          _FakeKpiRepository(load: () => completer.future),
        ),
      ],
    );

    expect(find.byType(DpSpinner), findsWidgets);
    expect(find.text('加载失败'), findsNothing);
    expect(find.text('暂无指标数据'), findsNothing);
  });

  testWidgets('KPI Dashboard：错误态展示可恢复提示', (tester) async {
    await _pumpKpiTab(
      tester,
      overrides: [
        kpiRepositoryProvider.overrideWithValue(
          _FakeKpiRepository(load: () async => throw StateError('load failed')),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.textContaining('load failed'), findsOneWidget);
    expect(find.text('补齐最近 30 天'), findsOneWidget);
  });

  testWidgets('KPI Dashboard：空态展示引导文案', (tester) async {
    await _pumpKpiTab(
      tester,
      overrides: [
        kpiRepositoryProvider.overrideWithValue(
          _FakeKpiRepository(load: () async => const []),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无指标数据'), findsOneWidget);
    expect(find.text('先使用应用一段时间，或点击“补齐最近 30 天”。'), findsOneWidget);
  });

  testWidgets('KPI Dashboard：导出失败时展示 inline 错误并记录事件', (tester) async {
    final fakeLocalEvents = _FakeLocalEventsService();

    await _pumpKpiTab(
      tester,
      overrides: [
        kpiRepositoryProvider.overrideWithValue(
          _FakeKpiRepository(load: () async => const []),
        ),
        localEventsServiceProvider.overrideWithValue(fakeLocalEvents),
        kpiMetricsExportServiceProvider.overrideWithValue(
          _FailingKpiMetricsExportService(),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('导出指标（JSON）'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('操作失败'), findsOneWidget);
    expect(find.textContaining('export failed'), findsOneWidget);

    final started = fakeLocalEvents.events
        .where(
          (event) => event.eventName == domain.LocalEventNames.exportStarted,
        )
        .toList();
    expect(started.length, 1);
    expect(started.first.metaJson['format'], 'json');
    expect(started.first.metaJson['result'], 'ok');

    final completed = fakeLocalEvents.events
        .where(
          (event) => event.eventName == domain.LocalEventNames.exportCompleted,
        )
        .toList();
    expect(completed.length, 1);
    expect(completed.first.metaJson['format'], 'json');
    expect(completed.first.metaJson['result'], 'error');
  });
}
