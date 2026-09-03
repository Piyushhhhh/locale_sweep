import 'dart:convert';

import 'sweep_result.dart';

/// Generates Markdown and JSON reports from sweep results.
class ReportGenerator {
  /// Generates a Markdown report with failure table and locale summary.
  ///
  /// [screenshotLinkBuilder] customizes how screenshot paths are rendered.
  /// Defaults to a Markdown image link. Pass a custom builder for CI
  /// environments where local paths are not accessible.
  static String generateMarkdown(
    SweepRunSummary summary, {
    String Function(String path)? screenshotLinkBuilder,
  }) {
    final buf = StringBuffer();

    buf.writeln('# LocaleSweep Report');
    buf.writeln();

    if (summary.failed == 0) {
      buf.writeln(
        '**All ${summary.total} variants passed** across ${summary.byLocale.length} locales and ${summary.byFlow.length} flows.',
      );
      buf.writeln();
      return buf.toString();
    }

    buf.writeln(
      '**${summary.failed}/${summary.total} variants failed** across ${summary.byLocale.length} locales and ${summary.byFlow.length} flows.',
    );
    buf.writeln();

    if (summary.overflowCount > 0) {
      buf.writeln('- ${summary.overflowCount} overflow errors');
    }
    if (summary.arbIssueCount > 0) {
      buf.writeln('- ${summary.arbIssueCount} ARB translation issues');
    }
    buf.writeln();

    buf.writeln('## Failures');
    buf.writeln();

    for (final entry in summary.byFlow.entries) {
      final failures = entry.value.where((r) => r.hasIssues).toList();
      if (failures.isEmpty) continue;

      buf.writeln('### ${entry.key}');
      buf.writeln();
      buf.writeln('| Locale | Scale | Viewport | Issue | Screenshot |');
      buf.writeln('|--------|-------|----------|-------|------------|');

      for (final r in failures) {
        final issues = <String>[];

        for (final o in r.overflows) {
          issues.add(
            'Overflow${o.pixels != null ? " (${o.pixels!.toStringAsFixed(0)}px)" : ""}',
          );
        }
        for (final a in r.arbIssues) {
          issues.add('${a.type.name}: ${a.key ?? a.detail}');
        }
        if (r.errorMessage != null) {
          final msg = r.errorMessage!.length > 80
              ? '${r.errorMessage!.substring(0, 80)}...'
              : r.errorMessage!;
          issues.add('Error: $msg');
        }

        final detail = issues.join('<br>');
        final screenshotLink = r.screenshotPath != null
            ? (screenshotLinkBuilder != null
                  ? screenshotLinkBuilder(r.screenshotPath!)
                  : '![${r.variant.label}](${r.screenshotPath})')
            : '';

        buf.writeln(
          '| ${r.variant.locale} | ${r.variant.textScale}x | ${r.variant.viewport.name} | $detail | $screenshotLink |',
        );
      }
      buf.writeln();
    }

    buf.writeln('## Locale Summary');
    buf.writeln();
    buf.writeln('| Locale | Passed | Failed | Overflows | ARB Issues |');
    buf.writeln('|--------|--------|--------|-----------|------------|');

    for (final entry in summary.byLocale.entries) {
      final results = entry.value;
      final p = results.where((r) => !r.hasIssues).length;
      final f = results.length - p;
      final o = results.fold(0, (sum, r) => sum + r.overflows.length);
      final a = results.fold(0, (sum, r) => sum + r.arbIssues.length);
      buf.writeln('| ${entry.key} | $p | $f | $o | $a |');
    }
    buf.writeln();

    return buf.toString();
  }

  /// Generates a machine-readable JSON report.
  static String generateJson(SweepRunSummary summary) {
    final data = {
      'timestamp': summary.timestamp.toIso8601String(),
      'total': summary.total,
      'passed': summary.passed,
      'failed': summary.failed,
      'overflows': summary.overflowCount,
      'arbIssues': summary.arbIssueCount,
      'results': summary.results.map((r) => r.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
