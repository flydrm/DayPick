import 'package:flutter/widgets.dart';

import 'dp_spacing.dart';

class DpInsets {
  const DpInsets._();

  static const EdgeInsets page = EdgeInsets.all(DpSpacing.lg);
  static const EdgeInsets card = EdgeInsets.all(DpSpacing.lg);
  static const EdgeInsets appBar = EdgeInsets.fromLTRB(
    DpSpacing.md,
    DpSpacing.md,
    DpSpacing.md,
    DpSpacing.md,
  );
}
