import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_section_card.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../ai/providers/ai_providers.dart';

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;

  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _modelController = TextEditingController();
    _apiKeyController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final existing = await ref.read(aiConfigRepositoryProvider).getConfig();
    if (!mounted) return;
    setState(() {
      _baseUrlController.text = existing?.baseUrl ?? 'https://api.openai.com';
      _modelController.text = existing?.model ?? 'gpt-4o-mini';
      _apiKeyController.text = existing?.apiKey ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final busy = _saving || _testing;
    return AppPageScaffold(
      title: 'AI 设置',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: ListView(
        padding: DpInsets.page,
        children: [
          const ShadAlert(
            icon: Icon(Icons.lock_outline),
            title: Text('本地密文存储'),
            description: Text('apiKey 仅本地密文存储，不会被备份导出。'),
          ),
          const SizedBox(height: DpSpacing.md),
          DpSectionCard(
            title: '连接配置',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShadInput(
                  controller: _baseUrlController,
                  enabled: !busy,
                  keyboardType: TextInputType.url,
                  placeholder: Text(
                    'baseUrl（例如：https://api.openai.com 或 https://xxx/v1）',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  leading: const Icon(Icons.link_outlined, size: 18),
                ),
                const SizedBox(height: DpSpacing.md),
                ShadInput(
                  controller: _modelController,
                  enabled: !busy,
                  placeholder: Text(
                    'model（例如：gpt-4o-mini）',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  leading: const Icon(Icons.smart_toy_outlined, size: 18),
                ),
                const SizedBox(height: DpSpacing.md),
                ShadInput(
                  controller: _apiKeyController,
                  enabled: !busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  placeholder: Text(
                    'apiKey（以 sk-... 开头；不会展示）',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  leading: const Icon(Icons.key_outlined, size: 18),
                ),
                const SizedBox(height: DpSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: _testing ? null : _testConnection,
                        leading: _testing
                            ? const DpSpinner(size: 16, strokeWidth: 2)
                            : const Icon(
                                Icons.wifi_tethering_outlined,
                                size: 18,
                              ),
                        child: Text(_testing ? '测试中…' : '测试连接'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShadButton(
                        onPressed: _saving ? null : _save,
                        leading: _saving
                            ? const DpSpinner(size: 16, strokeWidth: 2)
                            : const Icon(Icons.save_outlined, size: 18),
                        child: Text(_saving ? '保存中…' : '保存'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DpSpacing.sm),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: busy ? null : _clear,
                  leading: const Icon(Icons.delete_outline, size: 18),
                  child: const Text('清除配置'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  domain.AiProviderConfig _configFromForm() {
    return domain.AiProviderConfig(
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text,
      updatedAt: DateTime.now(),
    );
  }

  String? _validateMessage() {
    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) return '请输入 baseUrl';
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      return 'baseUrl 需以 http:// 或 https:// 开头';
    }
    final model = _modelController.text.trim();
    if (model.isEmpty) return '请输入 model';
    return null;
  }

  Future<void> _save() async {
    final error = _validateMessage();
    if (error != null) {
      _showSnack(error);
      return;
    }
    setState(() => _saving = true);
    try {
      final config = _configFromForm();
      await ref.read(aiConfigRepositoryProvider).saveConfig(config);
      ref.invalidate(aiConfigProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存 AI 配置')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    final error = _validateMessage();
    if (error != null) {
      _showSnack(error);
      return;
    }
    setState(() => _testing = true);
    try {
      final config = _configFromForm();
      await ref.read(openAiClientProvider).testConnection(config: config);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('连接成功')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('连接失败：$e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    try {
      await ref.read(aiConfigRepositoryProvider).clear();
      ref.invalidate(aiConfigProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已清除 AI 配置')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
