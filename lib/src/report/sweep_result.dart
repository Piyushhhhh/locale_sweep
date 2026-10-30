import '../config/viewport_preset.dart';
import '../detection/arb_analyzer.dart';
import '../detection/diff_result.dart';
import '../detection/hardcoded_text_issue.dart';
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

  /// Rendered text that matches no ARB message (when detection is enabled).
  final List<HardcodedTextIssue> hardcodedTexts;

  /// Path to the golden screenshot file, if captured.
  final String? screenshotPath;

  /// Path to the image a failing variant actually rendered, if saved.
  ///
  /// Golden comparison never writes what it captured, so this is the only
  /// visual proof for a first run (no baseline yet) or a regression.
  /// `screenshotPath` keeps pointing at the baseline.
  final String? actualScreenshotPath;

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
    this.hardcodedTexts = const [],
    this.screenshotPath,
    this.actualScreenshotPath,
    this.errorMessage,
    this.failureKind,
    this.duration = Duration.zero,
    this.diff,
  });

  /// Creates a copy with optional replacement screenshot paths.
  SweepResult copyWith({
    String? screenshotPath,
    String? actualScreenshotPath,
    DiffResult? diff,
  }) => SweepResult(
    flowName: flowName,
    variant: variant,
    passed: passed,
    overflows: overflows,
    arbIssues: arbIssues,
    truncations: truncations,
    hardcodedTexts: hardcodedTexts,
    screenshotPath: screenshotPath ?? this.screenshotPath,
    actualScreenshotPath: actualScreenshotPath ?? this.actualScreenshotPath,
    errorMessage: errorMessage,
    failureKind: failureKind,
    duration: duration,
    diff: diff ?? this.diff,
  );

  /// Whether any overflow errors were captured.
  bool get hasOverflows => overflows.isNotEmpty;

  /// Whether any ARB issues exist for this variant's locale.
  bool get hasArbIssues => arbIssues.isNotEmpty;

  /// Whether any text was silently truncated.
  bool get hasTruncations => truncations.isNotEmpty;

  /// Whether any rendered text matched no ARB message.
  bool get hasHardcodedText => hardcodedTexts.isNotEmpty;

  /// Whether this variant has advisory findings (truncations, hardcoded text).
  bool get hasAdvisories => hasTruncations || hasHardcodedText;

  /// Whether this variant has any findings, including advisory ones.
  bool get hasIssues =>
      hasOverflows ||
      hasArbIssues ||
      hasAdvisories ||
      !passed ||
      errorMessage != null;

  /// Whether this variant failed a gating check.
  ///
  /// Truncations and hardcoded text are advisory: they are reported (and fail
  /// the run with `--fail-on truncation`, `hardcoded` or `all`) but they never
  /// fail a variant on their own.
  bool get hasGatingIssues =>
      hasOverflows || hasArbIssues || !passed || errorMessage != null;

  /// Unexpected failures cannot be suppressed by a QA category filter.
  bool get hasTestFailure =>
      failureKind == SweepFailureKind.test ||
      (failureKind == null && errorMessage != null) ||
      (!passed &&
          !hasOverflows &&
          !hasArbIssues &&
          !hasAdvisories &&
          failureKind == null);

  /// Serializes this result to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'flow': flowName,
    'variant': variant.label,
    'locale': variant.locale,
    if (variant.renderLocale != variant.locale)
      'renderLocale': variant.renderLocale,
    'textScale': variant.textScale,
    'viewportName': variant.viewport.name,
    'viewportWidth': variant.viewport.width,
    'viewportHeight': variant.viewport.height,
    'brightness': variant.isDark ? 'dark' : 'light',
    'rtl': variant.isRtl,
    'passed': !hasGatingIssues,
    'overflows': overflows.map((e) => e.toJson()).toList(),
    'arbIssues': arbIssues.map((e) => e.toJson()).toList(),
    'truncations': truncations.map((e) => e.toJson()).toList(),
    'hardcodedTexts': hardcodedTexts.map((e) => e.toJson()).toList(),
    'screenshot': screenshotPath,
    if (actualScreenshotPath != null) 'actualScreenshot': actualScreenshotPath,
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
      renderLocale: json['renderLocale'] as String?,
    ),
    passed: json['passed'] as bool,
    // Older result files (and results written by other tools) predate these
    // fields, so treat a missing/corrupt list as "no findings" instead of
    // throwing and discarding the whole result file.
    overflows: _decodeList(
      json['overflows'],
      (e) => OverflowError.fromJson(e as Map<String, dynamic>),
    ),
    arbIssues: _decodeList(
      json['arbIssues'],
      (e) => ArbIssue.fromJson(e as Map<String, dynamic>),
    ),
    truncations:
        (json['truncations'] as List?)
            ?.map((e) => TruncationIssue.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    hardcodedTexts:
        (json['hardcodedTexts'] as List?)
            ?.map((e) => HardcodedTextIssue.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    screenshotPath: json['screenshot'] as String?,
    actualScreenshotPath: json['actualScreenshot'] as String?,
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

/// Decodes an optional JSON list of objects, defaulting to an empty list.
List<T> _decodeList<T>(Object? value, T Function(Object) decode) =>
    switch (value) {
      final List list => [
        for (final item in list)
          if (item is Map<String, dynamic>) decode(item),
      ],
      _ => const [],
    };

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
  int get passed => results.where((r) => !r.hasGatingIssues).length;
  int get failed => total - passed;
  int get overflowCount =>
      results.fold(0, (sum, r) => sum + r.overflows.length);
  int get arbIssueCount =>
      results.fold(0, (sum, r) => sum + r.arbIssues.length);
  int get truncationCount =>
      results.fold(0, (sum, r) => sum + r.truncations.length);
  int get hardcodedTextCount =>
      results.fold(0, (sum, r) => sum + r.hardcodedTexts.length);

  List<SweepResult> get failures =>
      results.where((r) => r.hasGatingIssues).toList();

  /// Results that only carry advisory findings.
  List<SweepResult> get advisories =>
      results.where((r) => !r.hasGatingIssues && r.hasAdvisories).toList();

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
