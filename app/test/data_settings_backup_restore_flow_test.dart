import 'dart:typed_data';

import 'package:data/data.dart' as data;
import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/local_events/local_events_guard.dart';
import 'package:daypick/core/local_events/local_events_provider.dart';
import 'package:daypick/core/local_events/local_events_service.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/settings/providers/data_providers.dart';
import 'package:daypick/features/settings/view/data_settings_page.dart';
import 'package:daypick/features/settings/view/passphrase_entry_sheet.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:domain/domain.dart' as domain;
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _FakeBackupService extends data.DataBackupService {
  _FakeBackupService({required super.db});

  Uint8List createBytes = Uint8List.fromList([1, 2, 3]);
  bool lastCreateIncludesSecrets = false;
  data.BackupPreview preview = const data.BackupPreview(
    backupFormatVersion: 1,
    schemaVersion: 8,
    exportedAtUtcMillis: 123,
    includesSecrets: false,
    taskCount: 1,
    noteCount: 2,
    weaveLinkCount: 3,
    sessionCount: 4,
    checklistCount: 5,
  );
  bool restoreWaitForCancel = false;

  @override
  Future<Uint8List> createEncryptedBackup({
    required String passphrase,
    bool includesSecrets = false,
  }) async {
    lastCreateIncludesSecrets = includesSecrets;
    return createBytes;
  }

  @override
  Future<data.BackupPreview> readBackupPreview({
    required Uint8List encryptedBytes,
    required String passphrase,
  }) async {
    return preview;
  }

  @override
  Future<data.RestoreResult> restoreFromEncryptedBackup({
    required Uint8List encryptedBytes,
    required String passphrase,
    data.BackupCancellationToken? cancelToken,
  }) async {
    if (restoreWaitForCancel) {
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        cancelToken?.throwIfCancelled();
      }
    }
    return const data.RestoreResult(
      taskCount: 1,
      checklistCount: 1,
      noteCount: 1,
      weaveLinkCount: 1,
      sessionCount: 1,
    );
  }
}

class _FakeBackupFileStore extends data.BackupFileStore {
  const _FakeBackupFileStore();

  @override
  Future<String> saveToAppDocuments({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return '/tmp/$fileName';
  }
}

class _CapturingLocalEventsRepository implements domain.LocalEventsRepository {
  final events = <domain.LocalEvent>[];

  @override
  Future<void> insert(domain.LocalEvent event) async {
    events.add(event);
  }

  @override
  Future<List<domain.LocalEvent>> getAll({int? limit}) async => events;

  @override
  Future<List<domain.LocalEvent>> getBetween({
    required int minOccurredAtUtcMsInclusive,
    required int maxOccurredAtUtcMsExclusive,
    List<String>? eventNames,
    int? limit,
  }) async => events;

  @override
  Future<void> prune({
    required int minOccurredAtUtcMs,
    required int maxEvents,
  }) async {}
}

class _FakeFileSelectorPlatform extends FileSelectorPlatform {
  _FakeFileSelectorPlatform(this.file);

  final XFile file;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    return file;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required data.DataBackupService backupService,
  required data.BackupFileStore fileStore,
  required LocalEventsService localEvents,
}) async {
  final router = GoRouter(
    initialLocation: '/settings/data',
    routes: [
      GoRoute(
        path: '/settings/data',
        builder: (context, state) => const DataSettingsPage(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        goRouterProvider.overrideWithValue(router),
        appearanceConfigProvider.overrideWith(
          (ref) => Stream.value(const domain.AppearanceConfig()),
        ),
        dataBackupServiceProvider.overrideWithValue(backupService),
        backupFileStoreProvider.overrideWithValue(fileStore),
        localEventsServiceProvider.overrideWithValue(localEvents),
      ],
      child: const DayPickApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration step = const Duration(milliseconds: 50),
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (condition()) return;
  }
  throw TestFailure('Timed out waiting for condition');
}

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder to disappear');
}

Finder _sheetFields(Finder sheet) {
  return find.descendant(of: sheet, matching: find.byType(EditableText));
}

Future<void> _scrollSheetUntilHitTestable(
  WidgetTester tester, {
  required Finder sheet,
  required Finder target,
  Offset step = const Offset(0, -200),
  int maxDrags = 20,
}) async {
  final surface = const Size(800, 1000);
  for (var i = 0; i < maxDrags; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final rect = tester.getRect(sheet);
    final visibleBottom = rect.bottom < surface.height ? rect.bottom : surface.height;
    final start = Offset(rect.center.dx, (visibleBottom - 100).clamp(1, surface.height - 1));
    await tester.dragFrom(start, step);
    await tester.pump(const Duration(milliseconds: 50));
  }
  throw TestFailure('Timed out scrolling sheet to $target');
}

void main() {
  testWidgets('Flow C: can create includes_secrets=false backup and records event', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final backupService = _FakeBackupService(db: db);
    final fileStore = const _FakeBackupFileStore();
    final repo = _CapturingLocalEventsRepository();
    final localEvents = LocalEventsService(
      repository: repo,
      guard: LocalEventsGuard(),
      generateId: () => 'id',
      nowUtcMs: () => 1,
      appVersion: () => '1.0.0+1',
      featureFlagsSnapshot: () => 'flags',
    );

    await _pump(
      tester,
      backupService: backupService,
      fileStore: fileStore,
      localEvents: localEvents,
    );

    await tester.scrollUntilVisible(find.text('加密备份（不含密钥）'), 200);
    await tester.tap(find.text('加密备份（不含密钥）'));
    final sheet = find.byType(PassphraseEntrySheet);
    await _pumpUntilFound(tester, sheet);

    final fields = _sheetFields(sheet);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), '123456');
    await tester.pump();
    final confirm = find.descendant(of: sheet, matching: find.text('确定'));
    await _scrollSheetUntilHitTestable(tester, sheet: sheet, target: confirm);
    await tester.tap(confirm.hitTestable());
    await _pumpUntil(
      tester,
      () => repo.events.any(
        (e) => e.eventName == domain.LocalEventNames.backupCreated,
      ),
      maxPumps: 40,
    );

    expect(repo.events.any((e) => e.eventName == domain.LocalEventNames.backupCreated), isTrue);
    final evt =
        repo.events.firstWhere((e) => e.eventName == domain.LocalEventNames.backupCreated);
    expect(evt.metaJson['includes_secrets'], isFalse);
    expect(evt.metaJson['result'], 'ok');
  });

  testWidgets('Flow E: shows preview summary and can cancel before restore starts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final backupService = _FakeBackupService(db: db);
    final fileStore = const _FakeBackupFileStore();
    final repo = _CapturingLocalEventsRepository();
    final localEvents = LocalEventsService(
      repository: repo,
      guard: LocalEventsGuard(),
      generateId: () => 'id',
      nowUtcMs: () => 1,
      appVersion: () => '1.0.0+1',
      featureFlagsSnapshot: () => 'flags',
    );

    final selectedFile = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'a.ppbk',
      mimeType: 'application/octet-stream',
    );

    final oldInstance = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = _FakeFileSelectorPlatform(selectedFile);
    addTearDown(() => FileSelectorPlatform.instance = oldInstance);
    await _pump(
      tester,
      backupService: backupService,
      fileStore: fileStore,
      localEvents: localEvents,
    );

    await tester.scrollUntilVisible(find.text('恢复备份'), 200);
    await tester.tap(find.text('恢复备份'));
    final sheet = find.byType(PassphraseEntrySheet);
    await _pumpUntilFound(tester, sheet);

    final field = _sheetFields(sheet);
    expect(field, findsOneWidget);
    await tester.enterText(field, '123456');
    await tester.pump();
    final confirm = find.descendant(of: sheet, matching: find.text('确定'));
    await _scrollSheetUntilHitTestable(tester, sheet: sheet, target: confirm);
    await tester.tap(confirm.hitTestable());
    await _pumpUntilFound(tester, find.textContaining('includes_secrets：false'));

    expect(find.textContaining('includes_secrets：false'), findsOneWidget);

    await tester.tap(find.text('取消').hitTestable());
    await _pumpUntilGone(tester, find.text('确认恢复？'));

    final started = repo.events
        .where((e) => e.eventName == domain.LocalEventNames.restoreStarted)
        .toList();
    final completed = repo.events
        .where((e) => e.eventName == domain.LocalEventNames.restoreCompleted)
        .toList();

    expect(started, isEmpty);
    expect(completed, isEmpty);
  });

  testWidgets('Flow D: can create includes_secrets=true export and records event', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final backupService = _FakeBackupService(db: db);
    final fileStore = const _FakeBackupFileStore();
    final repo = _CapturingLocalEventsRepository();
    final localEvents = LocalEventsService(
      repository: repo,
      guard: LocalEventsGuard(),
      generateId: () => 'id',
      nowUtcMs: () => 1,
      appVersion: () => '1.0.0+1',
      featureFlagsSnapshot: () => 'flags',
    );

    await _pump(
      tester,
      backupService: backupService,
      fileStore: fileStore,
      localEvents: localEvents,
    );

    await tester.scrollUntilVisible(find.text('安全导出（含密钥）'), 200);
    await tester.tap(find.text('安全导出（含密钥）'));
    await tester.pumpAndSettle();

    final checkbox = find.widgetWithText(
      ShadCheckbox,
      '我理解此导出包含密钥，丢失可能导致风险。',
    );
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pump();

    await tester.tap(find.text('继续').hitTestable());
    await tester.pumpAndSettle();

    final sheet = find.byType(PassphraseEntrySheet);
    await _pumpUntilFound(tester, sheet);

    final fields = _sheetFields(sheet);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'abc123def456');
    await tester.enterText(fields.at(1), 'abc123def456');
    await tester.pump();
    final confirm = find.descendant(of: sheet, matching: find.text('确定'));
    await _scrollSheetUntilHitTestable(tester, sheet: sheet, target: confirm);
    await tester.tap(confirm.hitTestable());
    await tester.pumpAndSettle();

    await _pumpUntilFound(tester, find.text('确认创建“含密钥”加密包？'));
    await tester.tap(find.text('确认创建').hitTestable());

    await _pumpUntil(
      tester,
      () => repo.events.any((e) => e.eventName == domain.LocalEventNames.backupCreated),
      maxPumps: 80,
    );

    final evt =
        repo.events.firstWhere((e) => e.eventName == domain.LocalEventNames.backupCreated);
    expect(evt.metaJson['includes_secrets'], isTrue);
    expect(evt.metaJson['result'], 'ok');
  });

  testWidgets('Flow E: can cancel restore during execution (records cancelled)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final backupService = _FakeBackupService(db: db)
      ..preview = const data.BackupPreview(
        backupFormatVersion: 1,
        schemaVersion: 8,
        exportedAtUtcMillis: 123,
        includesSecrets: true,
        taskCount: 1,
        noteCount: 2,
        weaveLinkCount: 3,
        sessionCount: 4,
        checklistCount: 5,
      )
      ..restoreWaitForCancel = true;
    final fileStore = const _FakeBackupFileStore();
    final repo = _CapturingLocalEventsRepository();
    final localEvents = LocalEventsService(
      repository: repo,
      guard: LocalEventsGuard(),
      generateId: () => 'id',
      nowUtcMs: () => 1,
      appVersion: () => '1.0.0+1',
      featureFlagsSnapshot: () => 'flags',
    );

    final selectedFile = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'a.ppbk',
      mimeType: 'application/octet-stream',
    );

    final oldInstance = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = _FakeFileSelectorPlatform(selectedFile);
    addTearDown(() => FileSelectorPlatform.instance = oldInstance);
    await _pump(
      tester,
      backupService: backupService,
      fileStore: fileStore,
      localEvents: localEvents,
    );

    await tester.scrollUntilVisible(find.text('恢复备份'), 200);
    await tester.tap(find.text('恢复备份'));
    final sheet = find.byType(PassphraseEntrySheet);
    await _pumpUntilFound(tester, sheet);

    final field = _sheetFields(sheet);
    expect(field, findsOneWidget);
    await tester.enterText(field, 'abc123def456');
    await tester.pump();
    final confirm = find.descendant(of: sheet, matching: find.text('确定'));
    await _scrollSheetUntilHitTestable(tester, sheet: sheet, target: confirm);
    await tester.tap(confirm.hitTestable());

    await _pumpUntilFound(tester, find.text('确认恢复？'));
    await tester.tap(find.text('继续恢复').hitTestable());

    await _pumpUntilFound(tester, find.text('取消'));
    await tester.tap(find.text('取消').hitTestable());

    await _pumpUntil(
      tester,
      () => repo.events.any(
        (e) =>
            e.eventName == domain.LocalEventNames.restoreCompleted &&
            e.metaJson['result'] == 'cancelled' &&
            e.metaJson['includes_secrets'] == true,
      ),
      maxPumps: 200,
    );
  });
}
