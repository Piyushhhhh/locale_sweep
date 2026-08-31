import 'dart:io';

import 'package:yaml/yaml.dart';

import 'viewport_preset.dart';

/// Configuration for a sweep run, loadable from `locale_sweep.yaml`.
class SweepConfig {
  /// BCP-47 locale codes to test (e.g. `['en', 'de', 'ar']`).
  final List<String> locales;

  /// Text scale factors to test (e.g. `[1.0, 2.0]`).
  final List<double> textScales;

  /// Viewport sizes to render at.
  final List<ViewportPreset> viewports;

  /// Directory for golden screenshots.
  final String screenshotDir;

  /// Directory for generated reports.
  final String reportDir;

  /// Path to ARB files for static translation analysis.
  final String? arbDir;

  const SweepConfig({
    this.locales = const ['en', 'de', 'ar', 'ja'],
    this.textScales = const [1.0, 2.0],
    this.viewports = const [ViewportPreset.phone],
    this.screenshotDir = '.locale_sweep/screenshots',
    this.reportDir = '.locale_sweep/reports',
    this.arbDir,
  });

  /// Loads configuration from a YAML file, falling back to defaults.
  static SweepConfig load([String path = 'locale_sweep.yaml']) {
    final file = File(path);
    if (!file.existsSync()) return const SweepConfig();

    final yaml = loadYaml(file.readAsStringSync()) as YamlMap;

    return SweepConfig(
      locales:
          _parseStringList(yaml['locales']) ?? const ['en', 'de', 'ar', 'ja'],
      textScales: _parseDoubleList(yaml['text_scales']) ?? const [1.0, 2.0],
      viewports:
          _parseViewports(yaml['viewports']) ?? const [ViewportPreset.phone],
      screenshotDir:
          yaml['screenshot_dir'] as String? ?? '.locale_sweep/screenshots',
      reportDir: yaml['report_dir'] as String? ?? '.locale_sweep/reports',
      arbDir: yaml['arb_dir'] as String?,
    );
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value is! YamlList) return null;
    return value.cast<String>().toList();
  }

  static List<double>? _parseDoubleList(dynamic value) {
    if (value is! YamlList) return null;
    return value.map((e) => (e as num).toDouble()).toList();
  }

  static List<ViewportPreset>? _parseViewports(dynamic value) {
    if (value is! YamlList) return null;
    return value.map((e) {
      final map = e as YamlMap;
      return ViewportPreset(
        name: map['name'] as String,
        width: (map['width'] as num).toDouble(),
        height: (map['height'] as num).toDouble(),
      );
    }).toList();
  }
}
