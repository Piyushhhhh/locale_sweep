import '../detection/arb_analyzer.dart';
import '../detection/overflow_detector.dart';
import '../runner/sweep_variant.dart';

class SweepResult {
  final String flowName;
  final SweepVariant variant;
  final bool passed;
  final List<OverflowError> overflows;
  final List<ArbIssue> arbIssues;
  final String? screenshotPath;
  final String? errorMessage;
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

  bool get hasOverflows => overflows.isNotEmpty;
  bool get hasArbIssues => arbIssues.isNotEmpty;
  bool get hasIssues => hasOverflows || hasArbIssues || !passed;

  Map<String, dynamic> toJson() => {
    'flow': flowName,
    'variant': variant.label,
    'locale': variant.locale,
    'textScale': variant.textScale,
    'viewport': variant.viewport.name,
    'rtl': variant.isRtl,
    'passed': passed,
    'overflows': overflows.map((e) => e.toString()).toList(),
    'arbIssues': arbIssues.map((e) => e.toString()).toList(),
    'screenshot': screenshotPath,
    'error': errorMessage,
    'durationMs': duration.inMilliseconds,
  };
}

class SweepRunSummary {
  final List<SweepResult> results;
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
