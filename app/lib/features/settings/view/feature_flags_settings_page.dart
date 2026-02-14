import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/feature_flags/feature_flags_snapshot.dart';
import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_section_card.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';

class FeatureFlagsSettingsPage extends ConsumerWidget {
  const FeatureFlagsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(featureFlagsListProvider);

    return AppPageScaffold(
      title: '功能开关',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: flagsAsync.when(
        loading: () => const Center(child: ShadProgress(minHeight: 8)),
        error: (error, stack) => Center(child: Text('加载失败：$error')),
        data: (flags) => _FeatureFlagsBody(flags: flags),
      ),
    );
  }
}

class _FeatureFlagsBody extends ConsumerWidget {
  const _FeatureFlagsBody({required this.flags});

  final List<domain.FeatureFlag> flags;

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final snapshot = ref.watch(featureFlagsProvider).snapshot();
    final snapshotByKey = {
      for (final entry in snapshot.entries) entry.key: entry,
    };

    return ListView(
      padding: DpInsets.page,
      children: [
        const ShadAlert(
          icon: Icon(Icons.toggle_on_outlined),
          title: Text('本地 Feature Flags'),
          description: Text('用于灰度/回退/诊断；kill-switch 优先级最高，默认安全值应为关闭。'),
        ),
        const SizedBox(height: DpSpacing.md),
        DpSectionCard(
          title: '快照',
          subtitle: '导出当前 feature_flags_snapshot（确定性，content-free）',
          child: ShadButton.outline(
            onPressed: () async {
              final json = ref
                  .read(featureFlagsProvider)
                  .snapshot()
                  .toJsonString();
              await Clipboard.setData(ClipboardData(text: json));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制快照 JSON')));
            },
            leading: const Icon(Icons.copy_all_outlined, size: 18),
            child: const Text('复制 snapshot'),
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        if (flags.isEmpty)
          ShadCard(
            padding: DpInsets.card,
            child: Text(
              '（暂无）',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
        for (final flag in flags) ...[
          DpSectionCard(
            title: flag.key,
            subtitle:
                'owner: ${flag.owner} · expiry: ${_formatDate(flag.expiryAt.toLocal())}',
            child: _FlagControls(
              flag: flag,
              snapshotEntry: snapshotByKey[flag.key],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
        ],
      ],
    );
  }
}

class _FlagControls extends ConsumerWidget {
  const _FlagControls({
    required this.flag,
    required this.snapshotEntry,
  });

  final domain.FeatureFlag flag;
  final FeatureFlagsSnapshotEntry? snapshotEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final enabled = snapshotEntry?.enabled ?? false;
    final reason = snapshotEntry?.forcedReason;
    final now = DateTime.now().toUtc();
    final expired = now.isAfter(flag.expiryAt.toUtc());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                enabled ? '当前：启用' : '当前：关闭',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
            ),
            if (reason != null)
              ShadBadge.outline(child: Text('forced: $reason')),
          ],
        ),
        const SizedBox(height: DpSpacing.sm),
        Text(
          'default：${flag.defaultValue ? '开' : '关'} · override：${_overrideLabel(flag.overrideValue)}',
          style: shadTheme.textTheme.muted.copyWith(
            color: colorScheme.mutedForeground,
          ),
        ),
        if (expired) ...[
          const SizedBox(height: DpSpacing.sm),
          Text(
            '已过期：override 会被清理/忽略，按 default 计算。',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
        const SizedBox(height: DpSpacing.md),
        ShadSelect<_OverrideMode>(
          initialValue: _modeFor(flag.overrideValue),
          selectedOptionBuilder: (context, value) => Text(
            'Override：${_modeLabel(value)}',
            style: shadTheme.textTheme.small.copyWith(
              color: colorScheme.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          options: const [
            ShadOption<_OverrideMode>(
              value: _OverrideMode.useDefault,
              child: Text('默认（跟随 default）'),
            ),
            ShadOption<_OverrideMode>(
              value: _OverrideMode.forceOn,
              child: Text('强制开启'),
            ),
            ShadOption<_OverrideMode>(
              value: _OverrideMode.forceOff,
              child: Text('强制关闭'),
            ),
          ],
          onChanged: (next) async {
            if (next == null) return;
            final nextValue = _overrideFor(next);
            if (nextValue == flag.overrideValue) return;
            await ref
                .read(featureFlagsProvider)
                .setOverride(flag.key, nextValue);
          },
        ),
        const SizedBox(height: DpSpacing.md),
        ShadSwitch(
          value: flag.killSwitch,
          onChanged: (v) async {
            if (v == flag.killSwitch) return;
            await ref.read(featureFlagsProvider).setKillSwitch(flag.key, v);
          },
          label: const Text('Kill-switch'),
          sublabel: const Text('强制关闭，覆盖 override'),
        ),
      ],
    );
  }

  static String _overrideLabel(bool? value) {
    return value == null ? '默认' : (value ? '开' : '关');
  }
}

enum _OverrideMode { useDefault, forceOn, forceOff }

_OverrideMode _modeFor(bool? value) {
  if (value == null) return _OverrideMode.useDefault;
  return value ? _OverrideMode.forceOn : _OverrideMode.forceOff;
}

bool? _overrideFor(_OverrideMode mode) {
  return switch (mode) {
    _OverrideMode.useDefault => null,
    _OverrideMode.forceOn => true,
    _OverrideMode.forceOff => false,
  };
}

String _modeLabel(_OverrideMode mode) {
  return switch (mode) {
    _OverrideMode.useDefault => '默认',
    _OverrideMode.forceOn => '开',
    _OverrideMode.forceOff => '关',
  };
}
