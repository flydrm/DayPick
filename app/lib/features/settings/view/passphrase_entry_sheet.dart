import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/dp_spacing.dart';

class PassphraseEntryRequest {
  const PassphraseEntryRequest({
    required this.title,
    required this.primaryLabel,
    this.secondaryLabel,
    this.requireConfirmation = false,
    this.hintText = '至少 6 位字符（建议更长）',
  });

  final String title;
  final String primaryLabel;
  final String? secondaryLabel;
  final bool requireConfirmation;
  final String hintText;
}

class PassphraseEntrySheet extends StatefulWidget {
  const PassphraseEntrySheet({super.key, required this.request});

  final PassphraseEntryRequest request;

  @override
  State<PassphraseEntrySheet> createState() => _PassphraseEntrySheetState();
}

class _PassphraseEntrySheetState extends State<PassphraseEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _passphraseController;
  late final TextEditingController _confirmController;

  @override
  void initState() {
    super.initState();
    _passphraseController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DpSpacing.lg,
          DpSpacing.lg,
          DpSpacing.lg,
          DpSpacing.lg + bottomInset,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.title,
                      style: shadTheme.textTheme.h4.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: '关闭',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop<String?>(null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                request.hintText,
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              if (request.requireConfirmation) ...[
                const SizedBox(height: DpSpacing.md),
                const ShadAlert(
                  icon: Icon(Icons.warning_amber_outlined),
                  title: Text('请务必记住密码'),
                  description: Text('密码丢失将无法恢复。'),
                ),
              ],
              const SizedBox(height: DpSpacing.md),
              ShadInputFormField(
                controller: _passphraseController,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: request.requireConfirmation
                    ? TextInputAction.next
                    : TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                obscureText: true,
                label: Text(request.primaryLabel),
                validator: (v) => _validatePassphrase(v),
              ),
              if (request.requireConfirmation) ...[
                const SizedBox(height: DpSpacing.md),
                ShadInputFormField(
                  controller: _confirmController,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(200)],
                  obscureText: true,
                  label: Text(request.secondaryLabel ?? '再次输入'),
                  validator: (v) {
                    final base = _validatePassphrase(v);
                    if (base != null) return base;
                    if (_passphraseController.text.trim() !=
                        _confirmController.text.trim()) {
                      return '两次输入不一致';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: DpSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () => Navigator.of(context).pop<String?>(null),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  Expanded(
                    child: ShadButton(
                      onPressed: _submit,
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_passphraseController.text.trim());
  }

  String? _validatePassphrase(String? value) {
    final v = (value ?? '').trim();
    if (v.length < 6) return '密码至少 6 位';
    return null;
  }
}
