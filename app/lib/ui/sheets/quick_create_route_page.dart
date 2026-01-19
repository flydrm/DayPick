import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../kit/dp_spinner.dart';
import 'quick_create_sheet.dart';

class QuickCreateRoutePage extends StatefulWidget {
  const QuickCreateRoutePage({
    super.key,
    required this.initialType,
    required this.initialTaskAddToToday,
    this.initialText,
  });

  final QuickCreateType initialType;
  final bool initialTaskAddToToday;
  final String? initialText;

  @override
  State<QuickCreateRoutePage> createState() => _QuickCreateRoutePageState();
}

class _QuickCreateRoutePageState extends State<QuickCreateRoutePage> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _openSheet();
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/today');
      }
    });
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => QuickCreateSheet(
        initialType: widget.initialType,
        initialTaskAddToToday: widget.initialTaskAddToToday,
        initialText: widget.initialText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: DpSpinner()));
  }
}
