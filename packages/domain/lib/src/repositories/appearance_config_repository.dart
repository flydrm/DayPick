import '../entities/appearance_config.dart';

abstract interface class AppearanceConfigRepository {
  Stream<AppearanceConfig> watch();
  Future<AppearanceConfig> get();
  Future<void> save(AppearanceConfig config);
  Future<void> clear();
}
