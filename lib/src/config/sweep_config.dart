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

  /// Whether to test both light and dark mode for each variant.
  final bool darkMode;

  /// Maximum allowed pixel-diff percentage (0.0–100.0) for golden comparisons.
  /// Screenshots within this tolerance pass even when pixels differ.
  final double tolerance;

  /// The base locale for ARB analysis (keys in this locale are the reference).
  /// Defaults to `'en'`.
  final String baseLocale;

  const SweepConfig({
    this.locales = const ['en', 'de', 'ar', 'ja'],
    this.textScales = const [1.0, 2.0],
    this.viewports = const [ViewportPreset.phone],
    this.darkMode = false,
    this.tolerance = 0.0,
    this.screenshotDir = '.locale_sweep/screenshots',
    this.reportDir = '.locale_sweep/reports',
    this.arbDir,
    this.baseLocale = 'en',
  });

  static const _knownKeys = {
    'locales',
    'text_scales',
    'viewports',
    'dark_mode',
    'tolerance',
    'screenshot_dir',
    'report_dir',
    'arb_dir',
    'base_locale',
  };

  /// Loads configuration from a YAML file, falling back to defaults.
  ///
  /// Warns on stderr about unrecognized keys (likely typos) and type
  /// mismatches so that silent misconfiguration doesn't waste CI runs.
  static SweepConfig load([String path = 'locale_sweep.yaml']) {
    final file = File(path);
    if (!file.existsSync()) return _applyEnvOverrides(const SweepConfig());

    final content = file.readAsStringSync();
    if (content.trim().isEmpty) return _applyEnvOverrides(const SweepConfig());

    final dynamic parsed;
    try {
      parsed = loadYaml(content);
    } catch (e) {
      stderr.writeln('Warning: Failed to parse $path: $e');
      stderr.writeln('Using default configuration.');
      return _applyEnvOverrides(const SweepConfig());
    }

    if (parsed is! YamlMap) {
      stderr.writeln('Warning: $path is not a YAML map. Using defaults.');
      return _applyEnvOverrides(const SweepConfig());
    }

    final yaml = parsed;

    final unknown = yaml.keys
        .whereType<String>()
        .where((k) => !_knownKeys.contains(k))
        .toList();
    if (unknown.isNotEmpty) {
      stderr.writeln('Warning: Unknown keys in $path: ${unknown.join(', ')}');
      stderr.writeln('Valid keys: ${_knownKeys.join(', ')}');
    }

    _warnIfWrongType(path, yaml, 'locales', 'list');
    _warnIfWrongType(path, yaml, 'text_scales', 'list');
    _warnIfWrongType(path, yaml, 'viewports', 'list');
    _warnIfWrongType(path, yaml, 'dark_mode', 'bool');
    _warnIfWrongType(path, yaml, 'screenshot_dir', 'string');
    _warnIfWrongType(path, yaml, 'report_dir', 'string');
    _warnIfWrongType(path, yaml, 'arb_dir', 'string');
    _warnIfWrongType(path, yaml, 'tolerance', 'num');
    _warnIfWrongType(path, yaml, 'base_locale', 'string');

    return _applyEnvOverrides(
      SweepConfig(
        locales:
            _parseStringList(yaml['locales']) ?? const ['en', 'de', 'ar', 'ja'],
        textScales: _parseDoubleList(yaml['text_scales']) ?? const [1.0, 2.0],
        viewports:
            _parseViewports(yaml['viewports']) ?? const [ViewportPreset.phone],
        darkMode: yaml['dark_mode'] == true,
        tolerance: _parseDouble(yaml['tolerance']) ?? 0.0,
        screenshotDir:
            _parseString(yaml['screenshot_dir']) ?? '.locale_sweep/screenshots',
        reportDir: _parseString(yaml['report_dir']) ?? '.locale_sweep/reports',
        arbDir: _parseString(yaml['arb_dir']),
        baseLocale: _parseString(yaml['base_locale']) ?? 'en',
      ),
    );
  }

  static void _warnIfWrongType(
    String path,
    YamlMap yaml,
    String key,
    String expected,
  ) {
    final value = yaml[key];
    if (value == null) return;
    final ok = switch (expected) {
      'list' => value is YamlList,
      'string' => value is String,
      'bool' => value is bool,
      'num' => value is num,
      _ => true,
    };
    if (!ok) {
      stderr.writeln(
        'Warning: "$key" in $path should be a $expected, got ${value.runtimeType}.',
      );
    }
  }

  static SweepConfig _applyEnvOverrides(SweepConfig base) {
    final env = Platform.environment;
    return SweepConfig(
      locales:
          env['LOCALE_SWEEP_LOCALES']
              ?.split(',')
              .map((s) => s.trim())
              .toList() ??
          base.locales,
      textScales:
          env['LOCALE_SWEEP_TEXT_SCALES']
              ?.split(',')
              .map((s) => double.tryParse(s.trim()))
              .whereType<double>()
              .toList() ??
          base.textScales,
      viewports: base.viewports,
      darkMode: env.containsKey('LOCALE_SWEEP_DARK_MODE')
          ? env['LOCALE_SWEEP_DARK_MODE'] == 'true'
          : base.darkMode,
      tolerance: env.containsKey('LOCALE_SWEEP_TOLERANCE')
          ? (double.tryParse(env['LOCALE_SWEEP_TOLERANCE']!) ?? base.tolerance)
          : base.tolerance,
      screenshotDir: env['LOCALE_SWEEP_SCREENSHOT_DIR'] ?? base.screenshotDir,
      reportDir: env['LOCALE_SWEEP_REPORT_DIR'] ?? base.reportDir,
      arbDir: env['LOCALE_SWEEP_ARB_DIR'] ?? base.arbDir,
      baseLocale: env['LOCALE_SWEEP_BASE_LOCALE'] ?? base.baseLocale,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static String? _parseString(dynamic value) {
    if (value is String) return value;
    return null;
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
