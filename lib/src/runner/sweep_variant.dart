import 'dart:ui';

import '../config/viewport_preset.dart';

/// A single combination of locale, text scale, viewport, and brightness to test.
class SweepVariant {
  /// BCP-47 locale code.
  final String locale;

  /// Text scale factor (1.0 = default, 2.0 = large accessibility).
  final double textScale;

  /// Viewport dimensions.
  final ViewportPreset viewport;

  /// Platform brightness (light or dark).
  final Brightness brightness;

  const SweepVariant({
    required this.locale,
    required this.textScale,
    required this.viewport,
    this.brightness = Brightness.light,
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

  bool get isDark => brightness == Brightness.dark;

  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  String get label {
    final parts = <String>[locale];
    if (isDark) parts.add('dark');
    if (textScale != 1.0) parts.add('${textScale}x');
    parts.add(viewport.name);
    return parts.join('_');
  }

  String get displayLabel {
    final parts = <String>[locale.toUpperCase()];
    if (isRtl) parts.add('RTL');
    if (isDark) parts.add('Dark');
    if (textScale != 1.0) parts.add('${textScale}x scale');
    parts.add(viewport.name);
    return parts.join(' · ');
  }

  /// Returns the golden file path for this variant and flow.
  String screenshotPath(String flowName) =>
      '${flowName}_$label.png'.replaceAll(' ', '_');
}
