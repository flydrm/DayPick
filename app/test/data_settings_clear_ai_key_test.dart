import 'package:daypick/app/daypick_app.dart';
import 'package:daypick/core/providers/app_providers.dart';
import 'package:daypick/features/settings/view/data_settings_page.dart';
import 'package:daypick/routing/app_router.dart';
import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAiConfigRepository implements domain.AiConfigRepository {
  _FakeAiConfigRepository(this._config);

  domain.AiProviderConfig? _config;

  domain.AiProviderConfig? get config => _config;

  @override
  Future<domain.AiProviderConfig?> getConfig() async => _config;

  @override
  Future<void> saveConfig(domain.AiProviderConfig config) async {
    _config = config;
  }

  @override
  Future<void> clearApiKey() async {
    final current = _config;
    if (current == null) return;
    _config = domain.AiProviderConfig(
      baseUrl: current.baseUrl,
      model: current.model,
      apiKey: null,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clear() async {
    _config = null;
  }
}

void main() {
  testWidgets('DataSettings can clear only AI apiKey', (tester) async {
    final repo = _FakeAiConfigRepository(
      domain.AiProviderConfig(
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
        apiKey: 'sk-test',
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

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
          aiConfigRepositoryProvider.overrideWithValue(repo),
          appearanceConfigProvider.overrideWith(
            (ref) => Stream.value(const domain.AppearanceConfig()),
          ),
        ],
        child: const DayPickApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('清除 AI apiKey'), 200);
    expect(find.text('清除 AI apiKey'), findsOneWidget);
    await tester.tap(find.text('清除 AI apiKey'));
    await tester.pumpAndSettle();

    expect(find.text('清除 AI apiKey？'), findsOneWidget);
    await tester.tap(find.text('确认清除'));
    await tester.pumpAndSettle();

    expect(find.text('已清除 AI apiKey'), findsOneWidget);
    expect(repo.config, isNotNull);
    expect(repo.config!.baseUrl, 'https://api.openai.com');
    expect(repo.config!.model, 'gpt-4o-mini');
    expect(repo.config!.apiKey, isNull);
  });
}
