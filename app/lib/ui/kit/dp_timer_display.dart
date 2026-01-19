import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DpTimerDisplay extends StatelessWidget {
  const DpTimerDisplay(this.text, {super.key, this.fontSize = 48});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: colorScheme.foreground,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
