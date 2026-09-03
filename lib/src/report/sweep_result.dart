import 'dart:ui';

import '../config/viewport_preset.dart';
import '../detection/arb_analyzer.dart';
import '../detection/overflow_detector.dart';
import '../runner/sweep_variant.dart';

/// The result of running a single sweep variant.
class SweepResult {
  /// The name of the flow that was tested.
  final String flowName;

  /// The locale/scale/viewport combination that was tested.
  final SweepVariant variant;

  /// Whether this variant passed all checks.
  final bool passed;

  /// Any RenderFlex overflow errors captured during the test.
  final List<OverflowError> overflows;

  /// Any ARB translation issues for this variant's locale.
  final List<ArbIssue> arbIssues;

  /// Path to the golden screenshot file, if captured.
  final String? screenshotPath;

  /// Error message if the test threw an exception.
  final String? errorMessage;

  /// Wall-clock time for this variant's test.
  final Duration duration;

  const SweepResult({
    required this.flowName,
    required this.variant,
    required this.passed,
    this.overflows = const [],
    this.arbIssues = const [],
    this.screenshotPath,
    this.errorMessage,
    this.duration = Duration.zero,
  });

  /// Whether any overflow errors were captured.
  bool get hasOverflows => overflows.isNotEmpty;

  /// Whether any ARB issues exist for this variant's locale.
  bool get hasArbIssues => arbIssues.isNotEmpty;

  /// Whether this variant has any issues at all.
  bool get hasIssues => hasOverflows || hasArbIssues || !passed;

  /// Serializes this result to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'flow': flowName,
    'variant': variant.label,
    'locale': variant.locale,
    'textScale': variant.textScale,
    'viewportName': variant.viewport.name,
    'viewportWidth': variant.viewport.width,
    'viewportHeight': variant.viewport.height,
    'brightness': variant.brightness.name,
    'rtl': variant.isRtl,
    'passed': passed,
    'overflows': overflows.map((e) => e.toJson()).toList(),
    'arbIssues': arbIssues.map((e) => e.toJson()).toList(),
    'screenshot': screenshotPath,
    'error': errorMessage,
    'durationMs': duration.inMilliseconds,
  };

  /// Deserializes a result from a JSON map (written by the test isolate).
  factory SweepResult.fromJson(Map<String, dynamic> json) => SweepResult(
    flowName: json['flow'] as String,
    variant: SweepVariant(
      locale: json['locale'] as String,
      textScale: (json['textScale'] as num).toDouble(),
      viewport: ViewportPreset(
        name: json['viewportName'] as String,
        width: (json['viewportWidth'] as num).toDouble(),
        height: (json['viewportHeight'] as num).toDouble(),
      ),
      brightness: json['brightness'] == 'dark'
          ? Brightness.dark
          : Brightness.light,
    ),
    passed: json['passed'] as bool,
    overflows: (json['overflows'] as List)
        .map((e) => OverflowError.fromJson(e as Map<String, dynamic>))
        .toList(),
    arbIssues: (json['arbIssues'] as List)
        .map((e) => ArbIssue.fromJson(e as Map<String, dynamic>))
        .toList(),
    screenshotPath: json['screenshot'] as String?,
    errorMessage: json['error'] as String?,
    duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
  );
}

/// Aggregates [SweepResult]s with summary statistics.
class SweepRunSummary {
  /// All results in this run.
  final List<SweepResult> results;

  /// When this summary was created.
  final DateTime timestamp;

  SweepRunSummary({required this.results}) : timestamp = DateTime.now();

  int get total => results.length;
  int get passed => results.where((r) => r.passed && !r.hasIssues).length;
  int get failed => total - passed;
  int get overflowCount =>
      results.fold(0, (sum, r) => sum + r.overflows.length);
  int get arbIssueCount =>
      results.fold(0, (sum, r) => sum + r.arbIssues.length);

  List<SweepResult> get failures => results.where((r) => r.hasIssues).toList();

  Map<String, List<SweepResult>> get byFlow {
    final map = <String, List<SweepResult>>{};
    for (final r in results) {
      map.putIfAbsent(r.flowName, () => []).add(r);
    }
    return map;
  }

  Map<String, List<SweepResult>> get byLocale {
    final map = <String, List<SweepResult>>{};
    for (final r in results) {
      map.putIfAbsent(r.variant.locale, () => []).add(r);
    }
    return map;
  }
}
