import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/feature_flags/feature_flag_keys.dart';
import '../core/local_events/today_3s_session_controller.dart';
import '../core/providers/app_providers.dart';
import '../ui/capture/capture_bar.dart';
import '../ui/tokens/dp_motion.dart';
import '../ui/tokens/dp_radius.dart';
import '../ui/tokens/dp_spacing.dart';
import 'home_tab.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({
    super.key,
    required this.navigationShell,
    required this.state,
  });

  final StatefulNavigationShell navigationShell;
  final GoRouterState state;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool _didRecordInitialTodayOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentIndex = widget.navigationShell.currentIndex;
    ref.read(homeTabIndexProvider.notifier).state = currentIndex;

    if (currentIndex == 2 && !_didRecordInitialTodayOpened) {
      _didRecordInitialTodayOpened = true;
      unawaited(
        ref.read(today3sSessionControllerProvider.notifier).recordTodayOpened(
          source: 'redirect',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final captureBarEnabled = ref
        .watch(featureFlagEnabledProvider(FeatureFlagKeys.captureBar))
        .maybeWhen(data: (v) => v, orElse: () => false);

    final path = widget.state.uri.path;
    final tabIndex = widget.navigationShell.currentIndex;
    final captureBarVisible =
        captureBarEnabled && _captureBarVisibleFor(path: path, tabIndex: tabIndex);

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: widget.navigationShell),
          if (captureBarEnabled)
            Offstage(
              offstage: !captureBarVisible,
              child: const DpCaptureBar(),
            ),
        ],
      ),
      bottomNavigationBar: _DpBottomNavBar(
        key: const ValueKey('bottom_navigation'),
        currentIndex: widget.navigationShell.currentIndex,
        onSelect: (index) {
          final currentIndex = widget.navigationShell.currentIndex;
          if (index == currentIndex) {
            widget.navigationShell.goBranch(index, initialLocation: true);
            return;
          }

          ref.read(homeTabIndexProvider.notifier).state = index;

          final fromTab = homeTabName(homeTabForIndex(currentIndex));
          final toTab = homeTabName(homeTabForIndex(index));

          if (currentIndex == 2) {
            unawaited(
              ref
                  .read(today3sSessionControllerProvider.notifier)
                  .recordTabSwitched(fromTab: fromTab, toTab: toTab),
            );
          }

          if (index == 2) {
            unawaited(
              ref
                  .read(today3sSessionControllerProvider.notifier)
                  .recordTodayOpened(source: 'tab'),
            );
          }

          widget.navigationShell.goBranch(index, initialLocation: false);
        },
      ),
    );
  }
}

bool _captureBarVisibleFor({
  required String path,
  required int tabIndex,
}) {
  // Notes / Today / Tasks.
  if (tabIndex != 1 && tabIndex != 2 && tabIndex != 3) return false;

  return path == '/notes' || path == '/today' || path == '/tasks';
}

class _DpBottomNavBar extends StatelessWidget {
  const _DpBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final dividerColor = colorScheme.border;
    final background = colorScheme.background;

    return SafeArea(
      top: false,
      child: Material(
        color: background,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: dividerColor, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(
            DpSpacing.sm,
            DpSpacing.sm,
            DpSpacing.sm,
            DpSpacing.sm,
          ),
          child: Row(
            children: [
              _DpBottomNavItem(
                label: 'AI',
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome,
                index: 0,
                currentIndex: currentIndex,
                onSelect: onSelect,
              ),
              _DpBottomNavItem(
                label: '笔记',
                icon: Icons.notes_outlined,
                selectedIcon: Icons.notes,
                index: 1,
                currentIndex: currentIndex,
                onSelect: onSelect,
              ),
              _DpBottomNavItem(
                label: '今天',
                icon: Icons.today_outlined,
                selectedIcon: Icons.today,
                index: 2,
                currentIndex: currentIndex,
                onSelect: onSelect,
                prominent: true,
              ),
              _DpBottomNavItem(
                label: '任务',
                icon: Icons.checklist_outlined,
                selectedIcon: Icons.checklist,
                index: 3,
                currentIndex: currentIndex,
                onSelect: onSelect,
              ),
              _DpBottomNavItem(
                label: '专注',
                icon: Icons.center_focus_strong_outlined,
                selectedIcon: Icons.center_focus_strong,
                index: 4,
                currentIndex: currentIndex,
                onSelect: onSelect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DpBottomNavItem extends StatelessWidget {
  const _DpBottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.index,
    required this.currentIndex,
    required this.onSelect,
    this.prominent = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final selected = index == currentIndex;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.mutedForeground;
    final background = selected
        ? colorScheme.primary.withAlpha(prominent ? 36 : 28)
        : prominent
        ? colorScheme.mutedForeground.withAlpha(12)
        : Colors.transparent;

    final item = Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(
          prominent ? DpRadius.lg : DpRadius.md,
        ),
        onTap: () => onSelect(index),
        child: AnimatedContainer(
          duration: DpMotion.fast,
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            vertical: prominent ? 10 : 8,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(
              prominent ? DpRadius.lg : DpRadius.md,
            ),
            border: prominent
                ? Border.all(color: colorScheme.border, width: 1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: prominent ? 26 : 22,
                color: foreground,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: shadTheme.textTheme.small.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Expanded(
      child: prominent
          ? Transform.translate(offset: const Offset(0, -1), child: item)
          : item,
    );
  }
}
