import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:locale_sweep/src/config/sweep_config.dart';
import 'package:locale_sweep/src/report/github_reporter.dart';
import 'package:locale_sweep/src/report/report_generator.dart';
import 'package:locale_sweep/src/report/sweep_result.dart';
import 'package:locale_sweep/src/runner/sweep_variant.dart';
import 'package:locale_sweep/src/config/viewport_preset.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('run')
    ..addCommand('update')
    ..addFlag('help', abbr: 'h', negatable: false);

  final sharedOptions = <void Function(ArgParser)>[
    (p) => p.addOption(
      'flows',
      abbr: 'f',
      help: 'Comma-separated flow names to run',
    ),
    (p) => p.addOption(
      'test-dir',
      help: 'Test directory',
      defaultsTo: 'test/sweep',
    ),
    (p) => p.addOption('output', abbr: 'o', help: 'Output directory'),
    (p) => p.addOption(
      'config',
      abbr: 'c',
      help: 'Path to locale_sweep.yaml',
      defaultsTo: 'locale_sweep.yaml',
    ),
    (p) => p.addFlag('verbose', abbr: 'v', negatable: false),
  ];

  for (final apply in sharedOptions) {
    apply(parser.commands['run']!);
    apply(parser.commands['update']!);
  }

  parser.commands['run']!.addFlag(
    'github-pr',
    help: 'Post results as a GitHub PR comment',
    negatable: false,
  );

  final parsed = parser.parse(args);

  if (parsed['help'] as bool || parsed.command == null) {
    _printUsage(parser);
    return;
  }

  final commandName = parsed.command!.name!;
  if (commandName == 'run') {
    await _runSweep(parsed.command!, updateGoldens: false);
  } else if (commandName == 'update') {
    await _runSweep(parsed.command!, updateGoldens: true);
  }
}

Future<void> _runSweep(ArgResults args, {required bool updateGoldens}) async {
  final configPath = args['config'] as String;
  final cfg = SweepConfig.load(configPath);

  final testDir = args['test-dir'] as String;
  final outputDir = args['output'] as String? ?? cfg.reportDir;
  final flows = args['flows'] as String?;
  final verbose = args['verbose'] as bool;
  final githubPr =
      args.options.contains('github-pr') && args['github-pr'] as bool;

  if (!Directory(testDir).existsSync()) {
    stderr.writeln('Error: Test directory "$testDir" not found.');
    stderr.writeln('Create sweep tests in $testDir/ using sweepTest().');
    exit(1);
  }

  final testFiles = Directory(testDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'))
      .toList();

  if (testFiles.isEmpty) {
    stderr.writeln('Error: No test files found in "$testDir".');
    exit(1);
  }

  var filesToRun = testFiles;
  if (flows != null) {
    final flowNames = flows.split(',').map((s) => s.trim()).toSet();
    filesToRun = testFiles.where((f) {
      final name = p.basenameWithoutExtension(f.path).replaceAll('_test', '');
      return flowNames.contains(name);
    }).toList();

    if (filesToRun.isEmpty) {
      stderr.writeln(
        'Error: No test files match flows: ${flowNames.join(", ")}',
      );
      stderr.writeln(
        'Available: ${testFiles.map((f) => p.basenameWithoutExtension(f.path).replaceAll("_test", "")).join(", ")}',
      );
      exit(1);
    }
  }

  Directory(outputDir).createSync(recursive: true);
  Directory('$outputDir/screenshots').createSync(recursive: true);

  final mode = updateGoldens ? 'Updating goldens' : 'Running checks';
  stdout.writeln('LocaleSweep — $mode');
  stdout.writeln(
    'Config: ${File(configPath).existsSync() ? configPath : "defaults"}',
  );
  stdout.writeln('${filesToRun.length} flow(s)');
  stdout.writeln();

  final flutterArgs = <String>[
    'test',
    '--machine',
    if (updateGoldens) '--update-goldens',
    ...filesToRun.map((f) => f.path),
  ];

  if (verbose) {
    stdout.writeln('flutter ${flutterArgs.join(" ")}');
    stdout.writeln();
  }

  final process = await Process.start('flutter', flutterArgs);

  final stdoutBuf = StringBuffer();
  final stderrBuf = StringBuffer();

  process.stdout.transform(utf8.decoder).listen((data) {
    stdoutBuf.write(data);
    if (verbose) stdout.write(data);
  });
  process.stderr.transform(utf8.decoder).listen((data) {
    stderrBuf.write(data);
    if (verbose) stderr.write(data);
  });

  await process.exitCode;

  final report = _loadResults(cfg) ?? _parseResults(stdoutBuf.toString(), cfg);
  final reportPath = '$outputDir/report.md';
  final jsonPath = '$outputDir/report.json';

  File(reportPath).writeAsStringSync(report.markdown);
  File(jsonPath).writeAsStringSync(report.json);

  stdout.writeln(report.summary);
  stdout.writeln();
  stdout.writeln('Report: $reportPath');
  stdout.writeln('JSON:   $jsonPath');

  if (updateGoldens) {
    stdout.writeln();
    stdout.writeln(
      'Goldens updated. Commit the screenshots to use as baselines.',
    );
  }

  if (githubPr) {
    await _postToGitHub(report);
  }

  if (!updateGoldens && report.failed > 0) {
    exit(1);
  }
}

class _ParsedReport {
  final String markdown;
  final String json;
  final String summary;
  final int total;
  final int passed;
  final int failed;
  final List<SweepResult> results;

  _ParsedReport({
    required this.markdown,
    required this.json,
    required this.summary,
    required this.total,
    required this.passed,
    required this.failed,
    required this.results,
  });
}

_ParsedReport? _loadResults(SweepConfig cfg) {
  final resultsDir = Directory('.locale_sweep/results');
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

  final runSummary = SweepRunSummary(results: sweepResults);
  final markdown = ReportGenerator.generateMarkdown(runSummary);
  final jsonStr = ReportGenerator.generateJson(runSummary);

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

  return _ParsedReport(
    markdown: markdown,
    json: jsonStr,
    summary: summary,
    total: total,
    passed: passed,
    failed: failed,
    results: sweepResults,
  );
}

_ParsedReport _parseResults(String output, SweepConfig cfg) {
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

    final variant = _parseVariantFromName(name, cfg);
    final flowName = _parseFlowFromName(name);

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

  final runSummary = SweepRunSummary(results: sweepResults);
  final markdown = ReportGenerator.generateMarkdown(runSummary);
  final jsonStr = ReportGenerator.generateJson(runSummary);

  final total = sweepResults.length;
  final passed = sweepResults.where((r) => r.passed).length;
  final failed = total - passed;

  final summary = failed == 0
      ? 'All $total variants passed.'
      : '$failed/$total variants failed.';

  return _ParsedReport(
    markdown: markdown,
    json: jsonStr,
    summary: summary,
    total: total,
    passed: passed,
    failed: failed,
    results: sweepResults,
  );
}

String _parseFlowFromName(String testName) {
  final match = RegExp(r'sweep: (\S+)').firstMatch(testName);
  return match?.group(1) ?? testName;
}

SweepVariant _parseVariantFromName(String testName, SweepConfig cfg) {
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

  for (final part in parts) {
    final lower = part.toLowerCase();
    if (lower == 'rtl') continue;
    if (lower.endsWith('x scale')) {
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

  return SweepVariant(locale: locale, textScale: textScale, viewport: viewport);
}

Future<void> _postToGitHub(_ParsedReport report) async {
  try {
    final reporter = GitHubReporter.fromEnv();
    final summary = SweepRunSummary(results: report.results);
    await reporter.postComment(summary);
    stdout.writeln('Posted report to PR #${reporter.prNumber}');
  } on StateError catch (e) {
    stderr.writeln('Warning: ${e.message}');
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('LocaleSweep — localization release QA for Flutter');
  stdout.writeln();
  stdout.writeln('Usage: locale_sweep <command> [options]');
  stdout.writeln();
  stdout.writeln('Commands:');
  stdout.writeln('  run      Compare golden screenshots, fail broken variants');
  stdout.writeln('  update   Regenerate golden screenshots as new baselines');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(parser.commands['run']!.usage);
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  locale_sweep run');
  stdout.writeln('  locale_sweep run --flows onboarding,checkout,settings');
  stdout.writeln('  locale_sweep run --github-pr');
  stdout.writeln('  locale_sweep update');
  stdout.writeln('  locale_sweep update --flows onboarding');
}
