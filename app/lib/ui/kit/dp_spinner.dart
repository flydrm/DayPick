import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DpSpinner extends StatelessWidget {
  const DpSpinner({super.key, this.size = 24, this.strokeWidth = 2});

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: colorScheme.primary,
      ),
    );
  }
}
