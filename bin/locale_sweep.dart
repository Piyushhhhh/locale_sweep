import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

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
    (p) => p.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory',
      defaultsTo: '.locale_sweep',
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
  final testDir = args['test-dir'] as String;
  final outputDir = args['output'] as String;
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

  final report = _parseResults(stdoutBuf.toString());
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
    await _postToGitHub(report.markdown);
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

  _ParsedReport({
    required this.markdown,
    required this.json,
    required this.summary,
    required this.total,
    required this.passed,
    required this.failed,
  });
}

_ParsedReport _parseResults(String output) {
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

  final sweepTests = <_TestResult>[];
  for (final entry in testResults.entries) {
    final name = testNames[entry.key] ?? '';
    if (!name.contains('[')) continue;
    sweepTests.add(
      _TestResult(
        name: name,
        passed: entry.value,
        error: testErrors[entry.key],
      ),
    );
  }

  final total = sweepTests.length;
  final passed = sweepTests.where((t) => t.passed).length;
  final failed = total - passed;
  final failures = sweepTests.where((t) => !t.passed).toList();

  final mdBuf = StringBuffer();
  mdBuf.writeln('# LocaleSweep Report');
  mdBuf.writeln();

  if (failed == 0) {
    mdBuf.writeln('**All $total variants passed.**');
  } else {
    mdBuf.writeln('**$failed/$total variants failed.**');
    mdBuf.writeln();
    mdBuf.writeln('## Failures');
    mdBuf.writeln();
    mdBuf.writeln('| Test | Error |');
    mdBuf.writeln('|------|-------|');
    for (final f in failures) {
      final error = (f.error ?? 'failed')
          .replaceAll('\n', ' ')
          .replaceAll('|', '\\|');
      final short = error.length > 120
          ? '${error.substring(0, 120)}...'
          : error;
      mdBuf.writeln('| ${f.name} | $short |');
    }
  }
  mdBuf.writeln();

  final jsonData = {
    'total': total,
    'passed': passed,
    'failed': failed,
    'tests': sweepTests
        .map((t) => {'name': t.name, 'passed': t.passed, 'error': t.error})
        .toList(),
  };

  final summary = failed == 0
      ? 'All $total variants passed.'
      : '$failed/$total variants failed.';

  return _ParsedReport(
    markdown: mdBuf.toString(),
    json: const JsonEncoder.withIndent('  ').convert(jsonData),
    summary: summary,
    total: total,
    passed: passed,
    failed: failed,
  );
}

Future<void> _postToGitHub(String markdown) async {
  final token = Platform.environment['GITHUB_TOKEN'];
  final repo = Platform.environment['GITHUB_REPOSITORY'];
  final ref = Platform.environment['GITHUB_REF'];

  if (token == null || repo == null || ref == null) {
    stderr.writeln(
      'Warning: Cannot post to GitHub. Missing GITHUB_TOKEN, GITHUB_REPOSITORY, or GITHUB_REF.',
    );
    return;
  }

  final prMatch = RegExp(r'refs/pull/(\d+)/merge').firstMatch(ref);
  if (prMatch == null) {
    stderr.writeln('Warning: GITHUB_REF is not a PR ref: $ref');
    return;
  }

  final prNumber = prMatch.group(1);
  final uri = Uri.parse(
    'https://api.github.com/repos/$repo/issues/$prNumber/comments',
  );
  final body =
      '<!-- locale_sweep -->\n$markdown\n---\n*Generated by [LocaleSweep](https://github.com/AstrixelHQ/locale_sweep)*';

  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('Accept', 'application/vnd.github.v3+json');
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode({'body': body}));
    final response = await request.close();

    if (response.statusCode == 201) {
      stdout.writeln('Posted report to PR #$prNumber');
    } else {
      stderr.writeln('Failed to post to GitHub: ${response.statusCode}');
    }
  } finally {
    client.close();
  }
}

class _TestResult {
  final String name;
  final bool passed;
  final String? error;

  _TestResult({required this.name, required this.passed, this.error});
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
