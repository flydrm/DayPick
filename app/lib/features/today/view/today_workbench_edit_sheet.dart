import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/tokens/dp_spacing.dart';

class TodayWorkbenchEditSheet extends ConsumerStatefulWidget {
  const TodayWorkbenchEditSheet({super.key, required this.config});

  final domain.AppearanceConfig config;

  @override
  ConsumerState<TodayWorkbenchEditSheet> createState() =>
      _TodayWorkbenchEditSheetState();
}

class _TodayWorkbenchEditSheetState
    extends ConsumerState<TodayWorkbenchEditSheet> {
  late bool _statsEnabled;
  late List<domain.TodayWorkbenchModule> _modules;

  static const _presetModulesDefault =
      domain.AppearanceConfig.defaultTodayModules;
  static const _presetModulesFocus = <domain.TodayWorkbenchModule>[
    domain.TodayWorkbenchModule.nextStep,
    domain.TodayWorkbenchModule.todayPlan,
    domain.TodayWorkbenchModule.capture,
    domain.TodayWorkbenchModule.budget,
    domain.TodayWorkbenchModule.focus,
    domain.TodayWorkbenchModule.shortcuts,
    domain.TodayWorkbenchModule.yesterdayReview,
  ];
  static const _presetModulesWeave = <domain.TodayWorkbenchModule>[
    domain.TodayWorkbenchModule.weave,
    domain.TodayWorkbenchModule.nextStep,
    domain.TodayWorkbenchModule.todayPlan,
    domain.TodayWorkbenchModule.capture,
    domain.TodayWorkbenchModule.shortcuts,
    domain.TodayWorkbenchModule.yesterdayReview,
  ];

  @override
  void initState() {
    super.initState();
    _statsEnabled = widget.config.statsEnabled;
    _modules = List<domain.TodayWorkbenchModule>.from(
      widget.config.todayModules,
    );
    _sanitize();
  }

  void _sanitize() {
    final seen = <domain.TodayWorkbenchModule>{};
    _modules = _modules.where((m) => seen.add(m)).toList();
    _modules.remove(domain.TodayWorkbenchModule.quickAdd);
    if (!_statsEnabled) {
      _modules.remove(domain.TodayWorkbenchModule.stats);
    }
  }

  List<domain.TodayWorkbenchModule> get _disabledModules {
    final enabled = _modules.toSet();
    final all = domain.TodayWorkbenchModule.values;
    return [
      for (final m in all)
        if (m != domain.TodayWorkbenchModule.quickAdd)
          if (!enabled.contains(m) &&
              (_statsEnabled || m != domain.TodayWorkbenchModule.stats))
            m,
    ];
  }

  String _label(domain.TodayWorkbenchModule module) {
    return switch (module) {
      domain.TodayWorkbenchModule.quickAdd => '（已移除）',
      domain.TodayWorkbenchModule.capture => '捕捉/创建',
      domain.TodayWorkbenchModule.weave => '待编织闪念',
      domain.TodayWorkbenchModule.shortcuts => '快捷入口',
      domain.TodayWorkbenchModule.budget => '今日预算',
      domain.TodayWorkbenchModule.focus => '今日专注',
      domain.TodayWorkbenchModule.nextStep => '下一步',
      domain.TodayWorkbenchModule.todayPlan => '今天计划',
      domain.TodayWorkbenchModule.timeboxing => '时间轴（Timeboxing）',
      domain.TodayWorkbenchModule.yesterdayReview => '昨天回顾',
      domain.TodayWorkbenchModule.stats => '统计/热力图',
    };
  }

  String _hint(domain.TodayWorkbenchModule module) {
    return switch (module) {
      domain.TodayWorkbenchModule.quickAdd => '该模块已移除',
      domain.TodayWorkbenchModule.capture => '任务/闪念/长文：快速创建，低摩擦捕捉',
      domain.TodayWorkbenchModule.weave => '闪念/草稿：转任务或编织进长文',
      domain.TodayWorkbenchModule.shortcuts => 'AI 拆任务 / 任务列表等',
      domain.TodayWorkbenchModule.budget => '预算 vs 已计划（过载提醒）',
      domain.TodayWorkbenchModule.focus => '今日番茄与最专注任务',
      domain.TodayWorkbenchModule.nextStep => '主 CTA：开始专注',
      domain.TodayWorkbenchModule.todayPlan => '手动排序 + 建议填充',
      domain.TodayWorkbenchModule.timeboxing => '用预计番茄投影一个可执行时间线（默认关闭）',
      domain.TodayWorkbenchModule.yesterdayReview => '折叠的昨日回顾',
      domain.TodayWorkbenchModule.stats => '近 12 周热力图',
    };
  }

  void _toggleStats(bool enabled) {
    setState(() {
      _statsEnabled = enabled;
      if (!enabled) {
        _modules.remove(domain.TodayWorkbenchModule.stats);
      } else if (!_modules.contains(domain.TodayWorkbenchModule.stats)) {
        _modules.add(domain.TodayWorkbenchModule.stats);
      }
      _sanitize();
    });
  }

  void _removeModule(domain.TodayWorkbenchModule module) {
    setState(() {
      _modules.remove(module);
    });
  }

  void _addModule(domain.TodayWorkbenchModule module) {
    setState(() {
      if (_modules.contains(module)) return;
      _modules.add(module);
    });
  }

  Future<void> _save() async {
    final repo = ref.read(appearanceConfigRepositoryProvider);
    final next = widget.config.copyWith(
      statsEnabled: _statsEnabled,
      todayModules: List.unmodifiable(_modules),
    );
    await repo.save(next);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已更新 Today 工作台')));
  }

  void _restoreDefaults() {
    setState(() {
      _statsEnabled = false;
      _modules = List<domain.TodayWorkbenchModule>.from(
        domain.AppearanceConfig.defaultTodayModules,
      );
      _sanitize();
    });
  }

  void _applyPreset({
    required bool statsEnabled,
    required List<domain.TodayWorkbenchModule> modules,
  }) {
    setState(() {
      _statsEnabled = statsEnabled;
      _modules = List<domain.TodayWorkbenchModule>.from(modules);
      _sanitize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.lg,
          bottom: DpSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '编辑 Today 工作台',
                      style: shadTheme.textTheme.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  ShadButton.ghost(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                '开关模块、拖拽重排。默认不做强限制，但建议保留「下一步」与「今天计划」作为闭环骨架。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              ShadCard(
                padding: const EdgeInsets.all(DpSpacing.md),
                title: Text(
                  '预设布局',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () => _applyPreset(
                        statsEnabled: false,
                        modules: _presetModulesDefault,
                      ),
                      child: const Text('默认'),
                    ),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () => _applyPreset(
                        statsEnabled: false,
                        modules: _presetModulesFocus,
                      ),
                      child: const Text('专注优先'),
                    ),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () => _applyPreset(
                        statsEnabled: false,
                        modules: _presetModulesWeave,
                      ),
                      child: const Text('编织优先'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              ShadCard(
                padding: const EdgeInsets.all(DpSpacing.md),
                child: ShadSwitch(
                  value: _statsEnabled,
                  onChanged: _toggleStats,
                  label: const Text('启用统计/热力图'),
                  sublabel: const Text('默认关闭；开启后可在 Today 添加统计模块'),
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              Expanded(
                child: ShadCard(
                  padding: EdgeInsets.zero,
                  title: Text(
                    '已启用（拖拽重排）',
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: _modules.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _modules.removeAt(oldIndex);
                        _modules.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final m = _modules[index];
                      return ListTile(
                        key: ValueKey(m.name),
                        title: Text(_label(m)),
                        subtitle: Text(_hint(m)),
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        trailing: Tooltip(
                          message: '隐藏',
                          child: ShadIconButton.ghost(
                            icon: const Icon(
                              Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => _removeModule(m),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              if (_disabledModules.isNotEmpty)
                ShadCard(
                  padding: const EdgeInsets.all(DpSpacing.md),
                  title: Text(
                    '可添加',
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _disabledModules)
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          onPressed: () => _addModule(m),
                          child: Text('＋ ${_label(m)}'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: DpSpacing.md),
              Row(
                children: [
                  ShadButton.outline(
                    onPressed: _restoreDefaults,
                    child: const Text('恢复默认'),
                  ),
                  const Spacer(),
                  ShadButton(onPressed: _save, child: const Text('保存')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
