import 'dart:io';

import 'package:daypick/core/local_events/local_events_guard.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event dictionary matches LocalEventNames + allowlists', () {
    final file = _findEventDictionaryFile();
    expect(
      file,
      isNotNull,
      reason: 'Missing prds/daypick-event-dictionary file',
    );

    final specs = _parseEventDictionary(file!.readAsStringSync());

    final expectedEventNames = specs.keys.toSet();
    expect(
      expectedEventNames,
      equals(domain.LocalEventNames.all),
      reason: 'LocalEventNames and event dictionary are out of sync',
    );

    final guard = LocalEventsGuard();

    for (final entry in specs.entries) {
      final eventName = entry.key;
      final metaSamples = entry.value;

      for (final meta in metaSamples.entries) {
        final result = guard.validate(
          eventName: eventName,
          metaJson: {meta.key: meta.value},
        );
        expect(result.ok, isTrue, reason: '$eventName allows ${meta.key}');
      }

      final rejectUnknownKey = guard.validate(
        eventName: eventName,
        metaJson: const {'__unknown__': 'x'},
      );
      expect(
        rejectUnknownKey.ok,
        isFalse,
        reason: '$eventName rejects unknown keys',
      );
    }
  });

  test('allows known event with allowlisted meta keys', () {
    final guard = LocalEventsGuard();

    final result = guard.validate(
      eventName: domain.LocalEventNames.todayOpened,
      metaJson: {'source': 'tab'},
    );

    expect(result.ok, isTrue);
  });

  test('rejects unknown event name', () {
    final guard = LocalEventsGuard();

    final result = guard.validate(
      eventName: 'unknown_event',
      metaJson: const {},
    );

    expect(result.ok, isFalse);
  });

  test('rejects unknown meta key', () {
    final guard = LocalEventsGuard();

    final result = guard.validate(
      eventName: domain.LocalEventNames.todayOpened,
      metaJson: {'unknown_key': 'x'},
    );

    expect(result.ok, isFalse);
  });

  test('rejects banlisted key', () {
    final guard = LocalEventsGuard();

    final result = guard.validate(
      eventName: domain.LocalEventNames.todayOpened,
      metaJson: {'title': 'secret'},
    );

    expect(result.ok, isFalse);
  });

  test('rejects nested object values', () {
    final guard = LocalEventsGuard();

    final result = guard.validate(
      eventName: domain.LocalEventNames.todayOpened,
      metaJson: {
        'source': {'nested': true},
      },
    );

    expect(result.ok, isFalse);
  });

  test('rejects non-string elements in string[] values', () {
    final guard = LocalEventsGuard();

    final result = guard.validate(
      eventName: domain.LocalEventNames.todayClarityResult,
      metaJson: {
        'failure_flags': ['a', 1],
      },
    );

    expect(result.ok, isFalse);
  });

  test('enforces caps: string length', () {
    final guard = LocalEventsGuard();

    final result = guard.validate(
      eventName: domain.LocalEventNames.todayOpened,
      metaJson: {'source': 'x' * 1000},
    );

    expect(result.ok, isFalse);
  });

  test('enforces caps: string[] length', () {
    final guard = LocalEventsGuard();

    final result = guard.validate(
      eventName: domain.LocalEventNames.todayClarityResult,
      metaJson: {'failure_flags': List<String>.generate(100, (i) => 'f$i')},
    );

    expect(result.ok, isFalse);
  });

  test('enforces caps: total meta_json size', () {
    final guard = LocalEventsGuard();

    final result = guard.validate(
      eventName: domain.LocalEventNames.todayClarityResult,
      metaJson: {'failure_flags': List<String>.filled(20, 'x' * 200)},
    );

    expect(result.ok, isFalse);
  });
}

File? _findEventDictionaryFile() {
  const fileName = 'daypick-event-dictionary-2026-01-24.md';
  final candidates = [
    'prds/$fileName',
    '../prds/$fileName',
    '../../prds/$fileName',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

Map<String, Map<String, Object?>> _parseEventDictionary(String markdown) {
  final specs = <String, Map<String, Object?>>{};
  final backtickToken = RegExp(r'`([a-z0-9_]+)`');
  final allowlistField = RegExp(
    r'^-\s+`([a-z0-9_]+)`\s*[:：]\s*([a-zA-Z0-9_\[\]\?]+)',
  );

  var currentEvents = <String>[];
  var inAllowlist = false;

  for (final rawLine in markdown.split('\n')) {
    final line = rawLine.trimLeft();

    if (line.startsWith('#### ')) {
      currentEvents = [
        for (final m in backtickToken.allMatches(line)) m.group(1)!,
      ];
      inAllowlist = false;
      for (final eventName in currentEvents) {
        specs.putIfAbsent(eventName, () => <String, Object?>{});
      }
      continue;
    }

    if (line.contains('meta_json allowlist')) {
      inAllowlist = true;
      continue;
    }

    if (!inAllowlist) continue;
    if (line.trim().isEmpty) continue;

    if (!line.startsWith('- `')) {
      inAllowlist = false;
      continue;
    }

    final match = allowlistField.firstMatch(line);
    if (match == null) continue;
    final key = match.group(1)!;
    final type = match.group(2)!;
    final sample = _sampleValueForType(type);
    for (final eventName in currentEvents) {
      specs[eventName]![key] = sample;
    }
  }

  return specs;
}

Object _sampleValueForType(String type) {
  switch (type) {
    case 'bool':
      return true;
    case 'int':
      return 1;
    case 'double':
      return 1.0;
    case 'string[]':
      return <String>['x'];
    case 'string':
    default:
      return 'x';
  }
}
