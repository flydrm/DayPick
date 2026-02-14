import 'package:daypick/core/capture/capture_submit_result.dart';
import 'package:daypick/core/feedback/action_toast_service.dart';
import 'package:daypick/core/local_events/local_events_provider.dart';
import 'package:daypick/core/local_events/local_events_service.dart';
import 'package:daypick/core/local_events/today_3s_session_controller.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/ui/capture/capture_submit_feedback.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets(
    'Capture submit success records primary_action_invoked(capture_submit)',
    (tester) async {
      final fakeLocalEvents = _FakeLocalEventsService();
      final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

      final container = ProviderContainer(
        overrides: [
          localEventsServiceProvider.overrideWithValue(fakeLocalEvents),
          actionToastServiceProvider.overrideWithValue(
            ActionToastService(scaffoldMessengerKey: scaffoldMessengerKey),
          ),
        ],
      );

      await container
          .read(today3sSessionControllerProvider.notifier)
          .startSession(segment: 'returning');

      showCaptureSubmitSuccessToast(
        container: container,
        result: const CaptureSubmitResult(
          entryId: 't-1',
          entryKind: CaptureEntryKind.task,
          triageStatus: domain.TriageStatus.inbox,
        ),
      );
      await tester.pump();

      final primaryActionEvents = fakeLocalEvents.events.where(
        (event) =>
            event.eventName == domain.LocalEventNames.primaryActionInvoked,
      );
      expect(primaryActionEvents.length, 1);
      expect(primaryActionEvents.first.metaJson['action'], 'capture_submit');

      container.dispose();
      await tester.pump();
    },
  );
}
