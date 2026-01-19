import '../entities/ai_provider_config.dart';

abstract interface class AiConfigRepository {
  Future<AiProviderConfig?> getConfig();
  Future<void> saveConfig(AiProviderConfig config);
  Future<void> clearApiKey();
  Future<void> clear();
}
