import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/capture/capture_submit_result.dart';
import '../capture/capture_submit_feedback.dart';
import '../kit/dp_spinner.dart';
import '../tokens/dp_accessibility.dart';
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
    final container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await _openSheet();
      if (!mounted) return;
      if (result != null) {
        showCaptureSubmitSuccessToast(container: container, result: result);
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/today');
      }
    });
  }

  Future<CaptureSubmitResult?> _openSheet() async {
    return showModalBottomSheet<CaptureSubmitResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: DpAccessibility.bottomSheetAnimationStyle(context),
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
