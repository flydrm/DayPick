import 'package:domain/domain.dart' as domain;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureAiConfigRepository implements domain.AiConfigRepository {
  SecureAiConfigRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyBaseUrl = 'ai.baseUrl';
  static const _keyModel = 'ai.model';
  static const _keyApiKey = 'ai.apiKey';
  static const _keyUpdatedAt = 'ai.updatedAt';

  final FlutterSecureStorage _storage;

  @override
  Future<domain.AiProviderConfig?> getConfig() async {
    try {
      final baseUrl = (await _storage.read(key: _keyBaseUrl))?.trim();
      final model = (await _storage.read(key: _keyModel))?.trim();
      final apiKey = (await _storage.read(key: _keyApiKey))?.trim();
      final updatedAtRaw = (await _storage.read(key: _keyUpdatedAt))?.trim();

      if (baseUrl == null || baseUrl.isEmpty) return null;
      if (model == null || model.isEmpty) return null;

      final updatedAt = DateTime.tryParse(updatedAtRaw ?? '') ?? DateTime.now();
      return domain.AiProviderConfig(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey?.isEmpty == true ? null : apiKey,
        updatedAt: updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveConfig(domain.AiProviderConfig config) async {
    final baseUrl = config.baseUrl.trim();
    final model = config.model.trim();
    final apiKey = config.apiKey?.trim();

    await _storage.write(key: _keyBaseUrl, value: baseUrl);
    await _storage.write(key: _keyModel, value: model);
    await _storage.write(
      key: _keyUpdatedAt,
      value: (config.updatedAt).toIso8601String(),
    );

    if (apiKey == null || apiKey.isEmpty) {
      await _storage.delete(key: _keyApiKey);
    } else {
      await _storage.write(key: _keyApiKey, value: apiKey);
    }
  }

  @override
  Future<void> clearApiKey() async {
    await _storage.delete(key: _keyApiKey);
    await _storage.write(
      key: _keyUpdatedAt,
      value: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _keyBaseUrl);
    await _storage.delete(key: _keyModel);
    await _storage.delete(key: _keyApiKey);
    await _storage.delete(key: _keyUpdatedAt);
  }
}
