import 'dart:typed_data';

import 'package:data/db/db_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDbKeyStorage implements DbKeyStorage {
  String? value;
  Object? readError;
  Object? writeError;
  Object? deleteError;
  var writeCount = 0;
  var deleteCount = 0;

  @override
  Future<String?> read(String key) async {
    final error = readError;
    if (error != null) throw error;
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    final error = writeError;
    if (error != null) throw error;
    writeCount++;
    this.value = value;
  }

  @override
  Future<void> delete(String key) async {
    final error = deleteError;
    if (error != null) throw error;
    deleteCount++;
    value = null;
  }
}

Uint8List _deterministicBytes(int length) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) i & 0xff]);

void main() {
  test('getOrCreateKeyBytes persists and is idempotent', () async {
    final storage = _FakeDbKeyStorage();
    final store = DbKeyStore(
      storage: storage,
      generateRandomBytes: _deterministicBytes,
    );

    final first = await store.getOrCreateKeyBytes();
    expect(first, hasLength(32));
    expect(first, _deterministicBytes(32));
    expect(storage.value, isNotNull);
    expect(storage.value, hasLength(64));
    expect(storage.writeCount, 1);

    final second = await store.getOrCreateKeyBytes();
    expect(second, first);
    expect(storage.writeCount, 1);
  });

  test('readKeyBytesIfExists returns null when missing', () async {
    final storage = _FakeDbKeyStorage();
    final store = DbKeyStore(
      storage: storage,
      generateRandomBytes: _deterministicBytes,
    );

    final bytes = await store.readKeyBytesIfExists();
    expect(bytes, isNull);
  });

  test('readKeyBytesIfExists throws on empty value', () async {
    final storage = _FakeDbKeyStorage()..value = '   ';
    final store = DbKeyStore(
      storage: storage,
      generateRandomBytes: _deterministicBytes,
    );

    await expectLater(
      store.readKeyBytesIfExists(),
      throwsA(isA<DbKeyStoreCorruptedException>()),
    );
  });

  test('getOrCreateKeyBytes throws on write failure', () async {
    final storage = _FakeDbKeyStorage()..writeError = Exception('write-fail');
    final store = DbKeyStore(
      storage: storage,
      generateRandomBytes: _deterministicBytes,
    );

    await expectLater(
      store.getOrCreateKeyBytes(),
      throwsA(isA<DbKeyStoreWriteException>()),
    );
  });

  test('readKeyHexIfExists throws on read failure', () async {
    final storage = _FakeDbKeyStorage()..readError = Exception('read-fail');
    final store = DbKeyStore(
      storage: storage,
      generateRandomBytes: _deterministicBytes,
    );

    await expectLater(
      store.readKeyHexIfExists(),
      throwsA(isA<DbKeyStoreReadException>()),
    );
  });

  test('readKeyHexIfExists validates key length and hex', () async {
    final storage = _FakeDbKeyStorage()
      ..value = '00' * 31; // 31 bytes, should be 32
    final store = DbKeyStore(
      storage: storage,
      generateRandomBytes: _deterministicBytes,
    );

    await expectLater(
      store.readKeyHexIfExists(),
      throwsA(isA<DbKeyStoreCorruptedException>()),
    );

    storage.value = 'not-hex' * 10;
    await expectLater(
      store.readKeyHexIfExists(),
      throwsA(isA<DbKeyStoreCorruptedException>()),
    );
  });
}
