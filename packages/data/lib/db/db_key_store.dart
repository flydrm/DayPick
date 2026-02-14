import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef RandomBytesGenerator = Uint8List Function(int length);

abstract interface class DbKeyStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStorageDbKeyStorage implements DbKeyStorage {
  FlutterSecureStorageDbKeyStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

sealed class DbKeyStoreException implements Exception {
  const DbKeyStoreException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'DbKeyStoreException($message)';
}

class DbKeyStoreReadException extends DbKeyStoreException {
  const DbKeyStoreReadException({Object? cause})
    : super('Failed to read DB key from secure storage.', cause: cause);
}

class DbKeyStoreWriteException extends DbKeyStoreException {
  const DbKeyStoreWriteException({Object? cause})
    : super('Failed to write DB key to secure storage.', cause: cause);
}

class DbKeyStoreCorruptedException extends DbKeyStoreException {
  const DbKeyStoreCorruptedException(this.reason)
    : super('DB key is missing or corrupted.');

  final String reason;
}

class DbKeyStore {
  DbKeyStore({
    DbKeyStorage? storage,
    RandomBytesGenerator? generateRandomBytes,
    String storageKey = defaultStorageKey,
    int keyLengthBytes = defaultKeyLengthBytes,
  }) : _storage = storage ?? FlutterSecureStorageDbKeyStorage(),
       _generateRandomBytes = generateRandomBytes ?? _generateSecureRandomBytes,
       _storageKey = storageKey,
       _keyLengthBytes = keyLengthBytes;

  static const defaultStorageKey = 'db.key.v1';
  static const defaultKeyLengthBytes = 32;

  final DbKeyStorage _storage;
  final RandomBytesGenerator _generateRandomBytes;
  final String _storageKey;
  final int _keyLengthBytes;

  Future<String?> readKeyHexIfExists() async {
    final raw = await _readRaw();
    if (raw == null) return null;
    return _validateHexKey(raw);
  }

  Future<Uint8List?> readKeyBytesIfExists() async {
    final hex = await readKeyHexIfExists();
    if (hex == null) return null;
    return _hexToBytes(hex);
  }

  Future<String> getOrCreateKeyHex() async {
    final existing = await readKeyHexIfExists();
    if (existing != null) return existing;

    final bytes = _generateRandomBytes(_keyLengthBytes);
    if (bytes.length != _keyLengthBytes) {
      throw StateError(
        'Random generator returned ${bytes.length} bytes, expected $_keyLengthBytes.',
      );
    }

    final hex = _bytesToHex(bytes);
    await _writeRaw(hex);
    return hex;
  }

  Future<void> deleteKey() async {
    try {
      await _storage.delete(_storageKey);
    } catch (e) {
      throw DbKeyStoreWriteException(cause: e);
    }
  }

  Future<Uint8List> getOrCreateKeyBytes() async {
    final hex = await getOrCreateKeyHex();
    return _hexToBytes(hex);
  }

  Future<String?> _readRaw() async {
    try {
      return await _storage.read(_storageKey);
    } catch (e) {
      throw DbKeyStoreReadException(cause: e);
    }
  }

  Future<void> _writeRaw(String value) async {
    try {
      await _storage.write(_storageKey, value);
    } catch (e) {
      throw DbKeyStoreWriteException(cause: e);
    }
  }

  String _validateHexKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const DbKeyStoreCorruptedException('secure storage returned empty');
    }

    if (trimmed.length != _keyLengthBytes * 2) {
      throw DbKeyStoreCorruptedException(
        'expected ${_keyLengthBytes * 2} hex chars, got ${trimmed.length}',
      );
    }

    try {
      for (var i = 0; i < trimmed.length; i += 2) {
        int.parse(trimmed.substring(i, i + 2), radix: 16);
      }
      return trimmed.toLowerCase();
    } on FormatException {
      throw const DbKeyStoreCorruptedException(
        'secure storage returned non-hex value',
      );
    }
  }
}

Uint8List _generateSecureRandomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

String _bytesToHex(Uint8List bytes) {
  const digits = '0123456789abcdef';
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer
      ..write(digits[b >> 4])
      ..write(digits[b & 0x0f]);
  }
  return buffer.toString();
}

Uint8List _hexToBytes(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return bytes;
}
