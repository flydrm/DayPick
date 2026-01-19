import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/dp_spacing.dart';

class PinEntryRequest {
  const PinEntryRequest({
    required this.title,
    required this.primaryLabel,
    this.secondaryLabel,
    this.requireConfirmation = false,
    this.hintText = '6 位数字（允许 0 开头）',
  });

  final String title;
  final String primaryLabel;
  final String? secondaryLabel;
  final bool requireConfirmation;
  final String hintText;
}

class PinEntrySheet extends StatefulWidget {
  const PinEntrySheet({super.key, required this.request});

  final PinEntryRequest request;

  @override
  State<PinEntrySheet> createState() => _PinEntrySheetState();
}

class _PinEntrySheetState extends State<PinEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pinController;
  late final TextEditingController _confirmController;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
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
                  title: Text('请务必记住 PIN'),
                  description: Text('PIN 丢失将无法恢复。'),
                ),
              ],
              const SizedBox(height: DpSpacing.md),
              ShadInputFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                textInputAction: request.requireConfirmation
                    ? TextInputAction.next
                    : TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                obscureText: true,
                label: Text(request.primaryLabel),
                validator: (v) => _validatePin(v),
              ),
              if (request.requireConfirmation) ...[
                const SizedBox(height: DpSpacing.md),
                ShadInputFormField(
                  controller: _confirmController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  obscureText: true,
                  label: Text(request.secondaryLabel ?? '再次输入 PIN'),
                  validator: (v) {
                    final base = _validatePin(v);
                    if (base != null) return base;
                    if (_pinController.text != _confirmController.text) {
                      return '两次 PIN 不一致';
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
    Navigator.of(context).pop(_pinController.text);
  }

  String? _validatePin(String? value) {
    final v = (value ?? '').trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(v)) return 'PIN 必须是恰好 6 位数字';
    return null;
  }
}
