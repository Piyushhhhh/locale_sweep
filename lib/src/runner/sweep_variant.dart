import 'dart:ui';

import '../config/viewport_preset.dart';

class SweepVariant {
  final String locale;
  final double textScale;
  final ViewportPreset viewport;

  const SweepVariant({
    required this.locale,
    required this.textScale,
    required this.viewport,
  });

  bool get isRtl => locale == 'ar' || locale == 'he' || locale == 'fa';

  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  String get label {
    final parts = <String>[locale];
    if (textScale != 1.0) parts.add('${textScale}x');
    parts.add(viewport.name);
    return parts.join('_');
  }

  String get displayLabel {
    final parts = <String>[locale.toUpperCase()];
    if (isRtl) parts.add('RTL');
    if (textScale != 1.0) parts.add('${textScale}x scale');
    parts.add(viewport.name);
    return parts.join(' · ');
  }

  String screenshotPath(String flowName) =>
      '${flowName}_$label.png'.replaceAll(' ', '_');
}
