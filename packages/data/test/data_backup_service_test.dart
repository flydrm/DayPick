import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

class _FakeExportServiceWithSecrets extends data.DataExportService {
  _FakeExportServiceWithSecrets(super.db);

  @override
  Future<Uint8List> exportJsonBytes() async {
    const jsonText =
        '{"schemaVersion":8,"exportedAt":1,"items":{"ai":{"apiKey":"sk-test"}}}';
    return Uint8List.fromList(utf8.encode(jsonText));
  }
}

class _FakeExportServiceWithInvalidTask extends data.DataExportService {
  _FakeExportServiceWithInvalidTask(super.db);

  @override
  Future<Uint8List> exportJsonBytes() async {
    const jsonText =
        '{"schemaVersion":8,"exportedAt":1,"items":{"tasks":[{"title":"new","status":0,"priority":0,"created_at_utc_ms":1,"updated_at_utc_ms":1}]}}';
    return Uint8List.fromList(utf8.encode(jsonText));
  }
}

class _InMemoryAiConfigRepository implements domain.AiConfigRepository {
  _InMemoryAiConfigRepository([this._config]);

  domain.AiProviderConfig? _config;

  @override
  Future<domain.AiProviderConfig?> getConfig() async => _config;

  @override
  Future<void> saveConfig(domain.AiProviderConfig config) async {
    _config = config;
  }

  @override
  Future<void> clearApiKey() async {
    final existing = _config;
    if (existing == null) return;
    _config = existing.copyWith(
      apiKey: null,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clear() async {
    _config = null;
  }
}

class _ThrowOnceAiConfigRepository implements domain.AiConfigRepository {
  _ThrowOnceAiConfigRepository(this._inner);

  final _InMemoryAiConfigRepository _inner;
  bool _didThrow = false;

  @override
  Future<domain.AiProviderConfig?> getConfig() => _inner.getConfig();

  @override
  Future<void> saveConfig(domain.AiProviderConfig config) async {
    await _inner.saveConfig(config);
    if (!_didThrow) {
      _didThrow = true;
      throw Exception('boom');
    }
  }

  @override
  Future<void> clearApiKey() => _inner.clearApiKey();

  @override
  Future<void> clear() => _inner.clear();
}

Future<Uint8List> _decryptPpbk(Uint8List encryptedBytes, String passphrase) async {
  if (encryptedBytes.length < 8) throw StateError('too short');
  final magic = utf8.decode(encryptedBytes.sublist(0, 4));
  if (magic != 'PPBK') throw StateError('bad magic');

  final headerLen = ByteData.sublistView(
    encryptedBytes,
    4,
    8,
  ).getUint32(0, Endian.big);
  final headerStart = 8;
  final headerEnd = headerStart + headerLen;
  if (headerEnd > encryptedBytes.length) throw StateError('bad header');

  final headerText = utf8.decode(encryptedBytes.sublist(headerStart, headerEnd));
  final header = jsonDecode(headerText);
  if (header is! Map) throw StateError('bad header json');

  final saltB64 = header['salt'];
  final nonceB64 = header['nonce'];
  final kdfVersion = header['kdf_version'] ?? header['kdfVersion'] ?? 1;
  final macLength = header['mac_length'] ?? header['macLength'];
  if (saltB64 is! String || nonceB64 is! String || macLength is! int) {
    throw StateError('missing header fields');
  }

  final salt = base64Decode(saltB64);
  final nonce = base64Decode(nonceB64);

  final payload = encryptedBytes.sublist(headerEnd);
  if (payload.length <= macLength) throw StateError('bad payload');

  final cipherText = payload.sublist(0, payload.length - macLength);
  final macBytes = payload.sublist(payload.length - macLength);

  late final SecretKey key;
  if (kdfVersion == 2) {
    final kdf = header['kdf'];
    if (kdf is! Map) throw StateError('missing kdf params');
    final parallelism = optIntFrom(kdf, 'parallelism');
    final memoryKib = optIntFrom(kdf, 'memory_kib');
    final iterations = optIntFrom(kdf, 'iterations');
    final hashLength = optIntFrom(kdf, 'hash_length');
    final argon2 = DartArgon2id(
      parallelism: parallelism,
      memory: memoryKib,
      iterations: iterations,
      hashLength: hashLength,
    );
    key = await argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  } else {
    final iterations = header['iterations'];
    if (iterations is! int) throw StateError('missing iterations');
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  final cipher = AesGcm.with256bits();
  final plain = await cipher.decrypt(
    SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
    secretKey: key,
  );
  return Uint8List.fromList(plain);
}

Uint8List _withModifiedHeader(
  Uint8List encryptedBytes,
  Map<String, Object?> Function(Map<String, Object?> header) modify,
) {
  if (encryptedBytes.length < 8) throw StateError('too short');
  final magic = utf8.decode(encryptedBytes.sublist(0, 4));
  if (magic != 'PPBK') throw StateError('bad magic');

  final headerLen = ByteData.sublistView(
    encryptedBytes,
    4,
    8,
  ).getUint32(0, Endian.big);
  final headerStart = 8;
  final headerEnd = headerStart + headerLen;
  if (headerEnd > encryptedBytes.length) throw StateError('bad header');

  final headerText = utf8.decode(encryptedBytes.sublist(headerStart, headerEnd));
  final decoded = jsonDecode(headerText);
  if (decoded is! Map) throw StateError('bad header json');
  final header =
      decoded.map((k, v) => MapEntry(k.toString(), v)) as Map<String, Object?>;
  final newHeader = modify(Map<String, Object?>.from(header));
  final newHeaderBytes = utf8.encode(jsonEncode(newHeader));

  final payload = encryptedBytes.sublist(headerEnd);
  final out = BytesBuilder(copy: false);
  out.add(utf8.encode('PPBK'));
  final lenBytes = (ByteData(4)..setUint32(0, newHeaderBytes.length, Endian.big))
      .buffer
      .asUint8List();
  out.add(lenBytes);
  out.add(newHeaderBytes);
  out.add(payload);
  return out.toBytes();
}

int optIntFrom(Map map, String key) {
  final v = map[key];
  if (v is int) return v;
  if (v is double) return v.toInt();
  throw StateError('missing $key');
}

void main() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  test('backup manifest contains includes_secrets=false (snake_case)', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final service = data.DataBackupService(db: db);
    final encrypted = await service.createEncryptedBackup(passphrase: '123456');

    final zipBytes = await _decryptPpbk(encrypted, '123456');
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final manifestFile = archive.findFile('manifest.json');
    expect(manifestFile, isNotNull);
    final manifestText = utf8.decode(manifestFile!.content as List<int>);
    final manifest = jsonDecode(manifestText);
    expect(manifest, isA<Map>());
    final map = manifest as Map;

    expect(map['includes_secrets'], isFalse);
    expect(map.containsKey('schema_version'), isTrue);
    expect(map.containsKey('exported_at_utc_ms'), isTrue);
    expect(map.containsKey('backup_format_version'), isTrue);
  });

  test('passphrase is normalized (trimmed) for create/preview', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final service = data.DataBackupService(db: db);
    final encrypted = await service.createEncryptedBackup(passphrase: '123456 ');

    final preview = await service.readBackupPreview(
      encryptedBytes: encrypted,
      passphrase: '123456',
    );
    expect(preview.includesSecrets, isFalse);
  });

  test('readBackupPreview reads includesSecrets and counts', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final service = data.DataBackupService(db: db);
    final encrypted = await service.createEncryptedBackup(passphrase: '123456');

    final preview = await service.readBackupPreview(
      encryptedBytes: encrypted,
      passphrase: '123456',
    );

    expect(preview.includesSecrets, isFalse);
    expect(preview.schemaVersion, data.DataExportService.exportSchemaVersion);
    expect(preview.exportedAtUtcMillis, isA<int>());
  });

  test('backup manifest contains includes_secrets=true and kdf params', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final aiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
        apiKey: 'sk-test',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
      ),
    );
    final service = data.DataBackupService(db: db, aiConfigRepository: aiRepo);

    final encrypted = await service.createEncryptedBackup(
      passphrase: 'abc123def456',
      includesSecrets: true,
    );

    final zipBytes = await _decryptPpbk(encrypted, 'abc123def456');
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final manifestFile = archive.findFile('manifest.json');
    expect(manifestFile, isNotNull);
    final manifestText = utf8.decode(manifestFile!.content as List<int>);
    final manifest = jsonDecode(manifestText);
    expect(manifest, isA<Map>());
    final map = manifest as Map;

    expect(map['includes_secrets'], isTrue);
    expect(map.containsKey('export_schema_version'), isTrue);
    expect(map.containsKey('exported_at_utc_ms'), isTrue);
    expect(map.containsKey('backup_format_version'), isTrue);
    expect(map['kdf_version'], 2);
    expect(map['kdf'], isA<Map>());

    final kdf = map['kdf'] as Map;
    expect(kdf['algorithm'], 'argon2id');
    expect(kdf.containsKey('parallelism'), isTrue);
    expect(kdf.containsKey('memory_kib'), isTrue);
    expect(kdf.containsKey('iterations'), isTrue);
    expect(kdf.containsKey('hash_length'), isTrue);
    expect(kdf.containsKey('salt_length'), isTrue);
  });

  test('includes_secrets=true backup requires baseUrl/model in ai config', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final aiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: '',
        model: '',
        apiKey: 'sk-test',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
      ),
    );
    final service = data.DataBackupService(db: db, aiConfigRepository: aiRepo);

    expect(
      () => service.createEncryptedBackup(
        passphrase: 'abc123def456',
        includesSecrets: true,
      ),
      throwsA(isA<data.BackupMissingAiConfigException>()),
    );
  });

  test('includes_secrets=true backup stores ai_config.json and keeps apiKey out of manifest/data.json', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final aiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
        apiKey: 'sk-test',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
      ),
    );
    final service = data.DataBackupService(db: db, aiConfigRepository: aiRepo);

    final encrypted = await service.createEncryptedBackup(
      passphrase: 'abc123def456',
      includesSecrets: true,
    );

    final zipBytes = await _decryptPpbk(encrypted, 'abc123def456');
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final manifestText = utf8.decode(
      archive.findFile('manifest.json')!.content as List<int>,
    );
    expect(manifestText.toLowerCase().contains('api_key'), isFalse);
    expect(manifestText.toLowerCase().contains('apikey'), isFalse);

    final dataText = utf8.decode(
      archive.findFile('data/data.json')!.content as List<int>,
    );
    expect(dataText.toLowerCase().contains('api_key'), isFalse);
    expect(dataText.toLowerCase().contains('apikey'), isFalse);

    final aiConfigText = utf8.decode(
      archive.findFile('secrets/ai_config.json')!.content as List<int>,
    );
    expect(aiConfigText.toLowerCase().contains('api_key'), isTrue);
    expect(aiConfigText, contains('sk-test'));
  });

  test('weak PIN blocks includes_secrets=true backup', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final aiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
        apiKey: 'sk-test',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
      ),
    );
    final service = data.DataBackupService(db: db, aiConfigRepository: aiRepo);

    expect(
      () => service.createEncryptedBackup(
        passphrase: '123456',
        includesSecrets: true,
      ),
      throwsA(isA<data.BackupWeakPassphraseException>()),
    );
  });

  test('includes_secrets=true preview rejects argon2 params out of bounds', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final aiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
        apiKey: 'sk-test',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
      ),
    );
    final service = data.DataBackupService(db: db, aiConfigRepository: aiRepo);

    final encrypted = await service.createEncryptedBackup(
      passphrase: 'abc123def456',
      includesSecrets: true,
    );

    final tampered = _withModifiedHeader(encrypted, (header) {
      final kdfRaw = header['kdf'];
      if (kdfRaw is! Map) throw StateError('missing kdf');
      final kdf = kdfRaw.map((k, v) => MapEntry(k.toString(), v));
      kdf['memory_kib'] = 999999;
      header['kdf'] = kdf;
      return header;
    });

    expect(
      () => service.readBackupPreview(
        encryptedBytes: tampered,
        passphrase: 'abc123def456',
      ),
      throwsA(isA<data.BackupUnsupportedException>()),
    );
  });

  test('includes_secrets=true preview/restore blocks weak PIN', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final aiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
        apiKey: 'sk-test',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
      ),
    );
    final service = data.DataBackupService(db: db, aiConfigRepository: aiRepo);

    final encrypted = await service.createEncryptedBackup(
      passphrase: 'abc123def456',
      includesSecrets: true,
    );

    expect(
      () => service.readBackupPreview(
        encryptedBytes: encrypted,
        passphrase: '123456',
      ),
      throwsA(isA<data.BackupWeakPassphraseException>()),
    );

    await expectLater(
      service.restoreFromEncryptedBackup(
        encryptedBytes: encrypted,
        passphrase: '123456',
      ),
      throwsA(isA<data.BackupWeakPassphraseException>()),
    );
  });

  test('restore writes aiConfig when includes_secrets=true', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final creatorAiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
        apiKey: 'sk-test',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
      ),
    );
    final creator = data.DataBackupService(db: db, aiConfigRepository: creatorAiRepo);
    final encrypted = await creator.createEncryptedBackup(
      passphrase: 'abc123def456',
      includesSecrets: true,
    );

    final targetAiRepo = _InMemoryAiConfigRepository();
    final restorer = data.DataBackupService(db: db, aiConfigRepository: targetAiRepo);
    await restorer.restoreFromEncryptedBackup(
      encryptedBytes: encrypted,
      passphrase: 'abc123def456',
    );

    final restored = await targetAiRepo.getConfig();
    expect(restored, isNotNull);
    expect(restored!.apiKey, 'sk-test');
    expect(restored.baseUrl, 'https://api.openai.com');
    expect(restored.model, 'gpt-4o-mini');
  });

  test('restore cancellation does not mutate DB or aiConfig', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    await db.into(db.tasks).insert(
      data.TasksCompanion.insert(
        id: 'old',
        title: 'Old',
        status: 0,
        priority: 0,
        createdAtUtcMillis: 1,
        updatedAtUtcMillis: 1,
      ),
    );

    final creatorAiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
        apiKey: 'sk-test',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
      ),
    );
    final creator = data.DataBackupService(db: db, aiConfigRepository: creatorAiRepo);
    final encrypted = await creator.createEncryptedBackup(
      passphrase: 'abc123def456',
      includesSecrets: true,
    );

    final targetAiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://old',
        model: 'old',
        apiKey: 'old',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2, isUtc: true),
      ),
    );
    final restorer = data.DataBackupService(db: db, aiConfigRepository: targetAiRepo);

    final token = data.BackupCancellationToken()..cancel();
    expect(
      () => restorer.restoreFromEncryptedBackup(
        encryptedBytes: encrypted,
        passphrase: 'abc123def456',
        cancelToken: token,
      ),
      throwsA(isA<data.BackupCancelledException>()),
    );

    final rows = await (db.select(db.tasks)..where((t) => t.id.equals('old')))
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Old');

    final cfg = await targetAiRepo.getConfig();
    expect(cfg, isNotNull);
    expect(cfg!.apiKey, 'old');
  });

  test('restore rollback restores previous aiConfig when saveConfig throws', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    await db.into(db.tasks).insert(
      data.TasksCompanion.insert(
        id: 'old',
        title: 'Old',
        status: 0,
        priority: 0,
        createdAtUtcMillis: 1,
        updatedAtUtcMillis: 1,
      ),
    );

    final creatorAiRepo = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
        apiKey: 'sk-test',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
      ),
    );
    final creator = data.DataBackupService(db: db, aiConfigRepository: creatorAiRepo);
    final encrypted = await creator.createEncryptedBackup(
      passphrase: 'abc123def456',
      includesSecrets: true,
    );

    final inner = _InMemoryAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://old',
        model: 'old',
        apiKey: 'old',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2, isUtc: true),
      ),
    );
    final throwingRepo = _ThrowOnceAiConfigRepository(inner);
    final restorer = data.DataBackupService(db: db, aiConfigRepository: throwingRepo);

    expect(
      () => restorer.restoreFromEncryptedBackup(
        encryptedBytes: encrypted,
        passphrase: 'abc123def456',
      ),
      throwsA(isA<Exception>()),
    );

    final cfg = await inner.getConfig();
    expect(cfg, isNotNull);
    expect(cfg!.apiKey, 'old');

    final rows = await (db.select(db.tasks)..where((t) => t.id.equals('old')))
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Old');
  });

  test('sensitive scan blocks backups that contain apiKey', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final export = _FakeExportServiceWithSecrets(db);
    final service = data.DataBackupService(db: db, exportService: export);

    expect(
      () => service.createEncryptedBackup(passphrase: '123456'),
      throwsA(isA<data.BackupSensitiveContentDetectedException>()),
    );
  });

  test('restore is transactional: failing restore does not wipe existing data', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    await db.into(db.tasks).insert(
      data.TasksCompanion.insert(
        id: 'old',
        title: 'Old',
        status: 0,
        priority: 0,
        createdAtUtcMillis: 1,
        updatedAtUtcMillis: 1,
      ),
    );

    final export = _FakeExportServiceWithInvalidTask(db);
    final service = data.DataBackupService(db: db, exportService: export);
    final encrypted = await service.createEncryptedBackup(passphrase: '123456');

    expect(
      () => service.restoreFromEncryptedBackup(
        encryptedBytes: encrypted,
        passphrase: '123456',
      ),
      throwsA(isA<Exception>()),
    );

    final rows = await (db.select(db.tasks)..where((t) => t.id.equals('old')))
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Old');
  });
}
