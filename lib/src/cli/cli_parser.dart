import 'dart:convert';
import 'dart:io';

import '../config/sweep_config.dart';
import '../config/viewport_preset.dart';
import '../report/report_generator.dart';
import '../report/sweep_result.dart';
import '../runner/sweep_variant.dart';

class ParsedReport {
  final String markdown;
  final String json;
  final String html;
  final String summary;
  final int total;
  final int passed;
  final int failed;
  final List<SweepResult> results;

  ParsedReport({
    required this.markdown,
    required this.json,
    required this.html,
    required this.summary,
    required this.total,
    required this.passed,
    required this.failed,
    required this.results,
  });
}

bool shouldFail(ParsedReport report, Set<String> failOn) {
  if (failOn.contains('all')) return report.failed > 0;
  if (failOn.contains('none')) return false;

  for (final r in report.results) {
    if (!r.passed) {
      if (failOn.contains('overflow') && r.overflows.isNotEmpty) return true;
      if (failOn.contains('arb') && r.arbIssues.isNotEmpty) return true;
      if (failOn.contains('golden') && r.errorMessage != null) return true;
    }
  }
  return false;
}

ParsedReport? loadResults(
  SweepConfig cfg, {
  String resultsPath = '.locale_sweep/results',
}) {
  final resultsDir = Directory(resultsPath);
  if (!resultsDir.existsSync()) return null;

  final files = resultsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  if (files.isEmpty) return null;

  final sweepResults = <SweepResult>[];
  for (final file in files) {
    try {
      final list = jsonDecode(file.readAsStringSync()) as List;
      for (final item in list) {
        sweepResults.add(SweepResult.fromJson(item as Map<String, dynamic>));
      }
    } catch (e) {
      stderr.writeln('Warning: Failed to read ${file.path}: $e');
    }
  }

  if (sweepResults.isEmpty) return null;

  return _buildReport(sweepResults);
}

ParsedReport parseMachineOutput(String output, SweepConfig cfg) {
  final events = <Map<String, dynamic>>[];
  for (final line in output.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
    try {
      events.add(jsonDecode(trimmed) as Map<String, dynamic>);
    } catch (_) {}
  }

  final testNames = <int, String>{};
  final testErrors = <int, String>{};
  final testResults = <int, bool>{};

  for (final event in events) {
    final type = event['type'] as String?;
    if (type == 'testStart') {
      final test = event['test'] as Map<String, dynamic>?;
      if (test != null) {
        testNames[test['id'] as int] = test['name'] as String? ?? '';
      }
    } else if (type == 'error') {
      final id = event['testID'] as int?;
      if (id != null) {
        testErrors[id] = event['error'] as String? ?? '';
      }
    } else if (type == 'testDone') {
      final id = event['testID'] as int?;
      final skipped = event['skipped'] as bool? ?? false;
      if (id != null && !skipped) {
        testResults[id] = event['result'] == 'success';
      }
    }
  }

  final sweepResults = <SweepResult>[];
  for (final entry in testResults.entries) {
    final name = testNames[entry.key] ?? '';
    if (!name.contains('[')) continue;

    final variant = parseVariantFromName(name, cfg);
    final flowName = parseFlowFromName(name);

    sweepResults.add(
      SweepResult(
        flowName: flowName,
        variant: variant,
        passed: entry.value,
        overflows: const [],
        arbIssues: const [],
        errorMessage: testErrors[entry.key],
        duration: Duration.zero,
      ),
    );
  }

  return _buildReport(sweepResults);
}

String parseFlowFromName(String testName) {
  final match = RegExp(r'sweep: (\S+)').firstMatch(testName);
  return match?.group(1) ?? testName;
}

SweepVariant parseVariantFromName(String testName, SweepConfig cfg) {
  final bracketMatch = RegExp(r'\[(.+)\]').firstMatch(testName);
  if (bracketMatch == null) {
    return const SweepVariant(
      locale: 'en',
      textScale: 1.0,
      viewport: ViewportPreset.phone,
    );
  }

  final label = bracketMatch.group(1)!;
  final parts = label.split(' · ');

  var locale = 'en';
  var textScale = 1.0;
  var viewport = ViewportPreset.phone;
  var isDark = false;

  for (final part in parts) {
    final lower = part.toLowerCase();
    if (lower == 'rtl') continue;
    if (lower == 'dark') {
      isDark = true;
    } else if (lower.endsWith('x scale')) {
      textScale =
          double.tryParse(lower.replaceAll('x scale', '').trim()) ?? 1.0;
    } else if (part.contains('x')) {
      final dims = part.split('x');
      if (dims.length == 2) {
        final w = double.tryParse(dims[0]);
        final h = double.tryParse(dims[1]);
        if (w != null && h != null) {
          viewport = ViewportPreset(name: part, width: w, height: h);
        }
      }
    } else if (part.length <= 5) {
      locale = part.toLowerCase();
    }
  }

  return SweepVariant(
    locale: locale,
    textScale: textScale,
    viewport: viewport,
    isDark: isDark,
  );
}

ParsedReport _buildReport(List<SweepResult> sweepResults) {
  final runSummary = SweepRunSummary(results: sweepResults);
  final markdown = ReportGenerator.generateMarkdown(runSummary);
  final jsonStr = ReportGenerator.generateJson(runSummary);
  final htmlStr = ReportGenerator.generateHtml(runSummary);

  final total = sweepResults.length;
  final passed = sweepResults.where((r) => r.passed).length;
  final failed = total - passed;

  final overflowCount = sweepResults.fold<int>(
    0,
    (sum, r) => sum + r.overflows.length,
  );
  final arbCount = sweepResults.fold<int>(
    0,
    (sum, r) => sum + r.arbIssues.length,
  );

  final parts = <String>[];
  if (failed > 0) parts.add('$failed/$total variants failed');
  if (overflowCount > 0) parts.add('$overflowCount overflow(s)');
  if (arbCount > 0) parts.add('$arbCount ARB issue(s)');
  final summary = parts.isEmpty
      ? 'All $total variants passed.'
      : parts.join(', ');

  return ParsedReport(
    markdown: markdown,
    json: jsonStr,
    html: htmlStr,
    summary: summary,
    total: total,
    passed: passed,
    failed: failed,
    results: sweepResults,
  );
}
