import 'dart:ui';

import '../config/viewport_preset.dart';

/// A single combination of locale, text scale, and viewport to test.
class SweepVariant {
  /// BCP-47 locale code.
  final String locale;

  /// Text scale factor (1.0 = default, 2.0 = large accessibility).
  final double textScale;

  /// Viewport dimensions.
  final ViewportPreset viewport;

  const SweepVariant({
    required this.locale,
    required this.textScale,
    required this.viewport,
  });

  static const _rtlLocales = {
    'ar',
    'he',
    'fa',
    'ur',
    'ku',
    'ps',
    'yi',
    'dv',
    'sd',
    'ug',
  };

  /// Whether this locale uses right-to-left text direction.
  bool get isRtl => _rtlLocales.contains(locale.split('_').first);

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

  /// Returns the golden file path for this variant and flow.
  String screenshotPath(String flowName) =>
      '${flowName}_$label.png'.replaceAll(' ', '_');
}
