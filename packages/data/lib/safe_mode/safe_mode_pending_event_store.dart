import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SafeModePendingEventStore {
  SafeModePendingEventStore({
    this.fileName = defaultFileName,
    this.nowUtcMs = _defaultNowUtcMs,
    Future<Directory> Function()? getDocumentsDirectory,
  }) : _getDocumentsDirectory =
           getDocumentsDirectory ?? getApplicationDocumentsDirectory;

  static const String defaultFileName = 'daypick_safe_mode_pending.json';

  final String fileName;
  final int Function() nowUtcMs;
  final Future<Directory> Function() _getDocumentsDirectory;

  Future<void> writePending({required String reason}) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode({'reason': reason, 'created_at_utc_ms': nowUtcMs()}),
      flush: true,
    );
  }

  Future<String?> readPendingReason() async {
    final file = await _file();
    if (!await file.exists()) return null;

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final reason = decoded['reason'];
      if (reason is! String) return null;
      final trimmed = reason.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final file = await _file();
    if (!await file.exists()) return;
    await file.delete();
  }

  Future<File> _file() async {
    final dir = await _getDocumentsDirectory();
    return File(p.join(dir.path, fileName));
  }
}

int _defaultNowUtcMs() => DateTime.now().toUtc().millisecondsSinceEpoch;
