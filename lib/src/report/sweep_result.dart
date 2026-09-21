import '../config/viewport_preset.dart';
import '../detection/arb_analyzer.dart';
import '../detection/diff_result.dart';
import '../detection/overflow_error.dart';
import '../detection/truncation_issue.dart';
import '../runner/sweep_variant.dart';

/// Distinguishes golden assertions from failures executing a test.
enum SweepFailureKind { golden, test }

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

  /// Any silently truncated text elements detected after layout.
  final List<TruncationIssue> truncations;

  /// Path to the golden screenshot file, if captured.
  final String? screenshotPath;

  /// Error message if the test threw an exception.
  final String? errorMessage;

  /// Category of a caught exception. Absent in reports from older versions.
  final SweepFailureKind? failureKind;

  /// Wall-clock time for this variant's test.
  final Duration duration;

  /// Pixel-diff result when screenshot diffing is enabled.
  final DiffResult? diff;

  const SweepResult({
    required this.flowName,
    required this.variant,
    required this.passed,
    this.overflows = const [],
    this.arbIssues = const [],
    this.truncations = const [],
    this.screenshotPath,
    this.errorMessage,
    this.failureKind,
    this.duration = Duration.zero,
    this.diff,
  });

  /// Whether any overflow errors were captured.
  bool get hasOverflows => overflows.isNotEmpty;

  /// Whether any ARB issues exist for this variant's locale.
  bool get hasArbIssues => arbIssues.isNotEmpty;

  /// Whether any text was silently truncated.
  bool get hasTruncations => truncations.isNotEmpty;

  /// Whether this variant has any issues at all.
  bool get hasIssues =>
      hasOverflows ||
      hasArbIssues ||
      hasTruncations ||
      !passed ||
      errorMessage != null;

  /// Unexpected failures cannot be suppressed by a QA category filter.
  bool get hasTestFailure =>
      failureKind == SweepFailureKind.test ||
      (failureKind == null && errorMessage != null) ||
      (!passed &&
          !hasOverflows &&
          !hasArbIssues &&
          !hasTruncations &&
          failureKind == null);

  /// Serializes this result to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'flow': flowName,
    'variant': variant.label,
    'locale': variant.locale,
    'textScale': variant.textScale,
    'viewportName': variant.viewport.name,
    'viewportWidth': variant.viewport.width,
    'viewportHeight': variant.viewport.height,
    'brightness': variant.isDark ? 'dark' : 'light',
    'rtl': variant.isRtl,
    'passed': !hasIssues,
    'overflows': overflows.map((e) => e.toJson()).toList(),
    'arbIssues': arbIssues.map((e) => e.toJson()).toList(),
    'truncations': truncations.map((e) => e.toJson()).toList(),
    'screenshot': screenshotPath,
    'error': errorMessage,
    if (failureKind != null) 'failureKind': failureKind!.name,
    'durationMs': duration.inMilliseconds,
    if (diff != null) 'diff': diff!.toJson(),
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
      isDark: json['brightness'] == 'dark',
    ),
    passed: json['passed'] as bool,
    overflows: (json['overflows'] as List)
        .map((e) => OverflowError.fromJson(e as Map<String, dynamic>))
        .toList(),
    arbIssues: (json['arbIssues'] as List)
        .map((e) => ArbIssue.fromJson(e as Map<String, dynamic>))
        .toList(),
    truncations:
        (json['truncations'] as List?)
            ?.map((e) => TruncationIssue.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    screenshotPath: json['screenshot'] as String?,
    errorMessage: json['error'] as String?,
    failureKind: switch (json['failureKind']) {
      'golden' => SweepFailureKind.golden,
      'test' => SweepFailureKind.test,
      _ => null,
    },
    duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    diff: json['diff'] != null
        ? DiffResult.fromJson(json['diff'] as Map<String, dynamic>)
        : null,
  );
}

/// Aggregates [SweepResult]s with summary statistics.
class SweepRunSummary {
  /// All results in this run.
  final List<SweepResult> results;

  /// When this summary was created.
  final DateTime timestamp;

  /// Errors that prevented a complete run (compilation, setup, result IO).
  final List<String> executionErrors;

  SweepRunSummary({required this.results, this.executionErrors = const []})
    : timestamp = DateTime.now();

  int get total => results.length;
  int get passed => results.where((r) => r.passed && !r.hasIssues).length;
  int get failed => total - passed;
  int get overflowCount =>
      results.fold(0, (sum, r) => sum + r.overflows.length);
  int get arbIssueCount =>
      results.fold(0, (sum, r) => sum + r.arbIssues.length);
  int get truncationCount =>
      results.fold(0, (sum, r) => sum + r.truncations.length);

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
