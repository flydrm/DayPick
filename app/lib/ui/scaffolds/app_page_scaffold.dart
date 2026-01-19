import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens/dp_insets.dart';
import '../tokens/dp_spacing.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions = const [],
    this.showSettingsAction = true,
    this.showSearchAction = true,
    this.showCreateAction = true,
    this.createRoute = '/create',
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget> actions;
  final bool showSettingsAction;
  final bool showSearchAction;
  final bool showCreateAction;
  final String createRoute;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: DpInsets.appBar,
              decoration: BoxDecoration(
                color: colorScheme.background,
                border: Border(
                  bottom: BorderSide(color: colorScheme.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (canPop) ...[
                    Tooltip(
                      message: '返回',
                      child: ShadIconButton.ghost(
                        icon: const Icon(Icons.arrow_back, size: 20),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(width: DpSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: shadTheme.textTheme.h3.copyWith(
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: DpSpacing.xs,
                        runSpacing: DpSpacing.xs,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...actions,
                          if (showCreateAction)
                            Tooltip(
                              message: '创建',
                              child: ShadIconButton.ghost(
                                icon: const Icon(Icons.add, size: 20),
                                onPressed: () => context.push(createRoute),
                              ),
                            ),
                          if (showSearchAction)
                            Tooltip(
                              message: '搜索',
                              child: ShadIconButton.ghost(
                                icon: const Icon(Icons.search, size: 20),
                                onPressed: () => context.push('/search'),
                              ),
                            ),
                          if (showSettingsAction)
                            Tooltip(
                              message: '设置',
                              child: ShadIconButton.ghost(
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  size: 20,
                                ),
                                onPressed: () => context.push('/settings'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
