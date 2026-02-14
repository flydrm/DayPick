import 'dart:async';

import 'package:domain/domain.dart' as domain;

class FakeAppearanceConfigRepository implements domain.AppearanceConfigRepository {
  FakeAppearanceConfigRepository(domain.AppearanceConfig initial) : _config = initial {
    _controller.add(_config);
  }

  final StreamController<domain.AppearanceConfig> _controller =
      StreamController.broadcast(sync: true);

  domain.AppearanceConfig _config;

  Stream<domain.AppearanceConfig> get stream => _controller.stream;

  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Stream<domain.AppearanceConfig> watch() => stream;

  @override
  Future<domain.AppearanceConfig> get() async => _config;

  @override
  Future<void> save(domain.AppearanceConfig config) async {
    _config = config;
    _controller.add(_config);
  }

  @override
  Future<void> clear() async {
    _config = const domain.AppearanceConfig();
    _controller.add(_config);
  }
}

