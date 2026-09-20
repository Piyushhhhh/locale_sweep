import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:locale_sweep/src/cli/cli_parser.dart';
import 'package:locale_sweep/src/cli/package_discovery.dart';
import 'package:locale_sweep/src/config/sweep_config.dart';
import 'package:locale_sweep/src/report/github_reporter.dart';
import 'package:locale_sweep/src/report/sweep_result.dart';

Future<void> main(List<String> args) async {
  try {
    await _main(args);
  } catch (error) {
    stderr.writeln('Error: $error');
    exitCode = 2;
  }
}

Future<void> _main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('run')
    ..addCommand('update')
    ..addCommand('merge')
    ..addCommand('scan')
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
    (p) => p.addOption(
      'shards',
      help: 'Total number of parallel shards (for CI matrix)',
    ),
    (p) => p.addOption('shard-index', help: 'Index of this shard (0-based)'),
    (p) => p.addOption(
      'packages',
      help: 'Comma-separated package directories (monorepo)',
    ),
  ];

  for (final apply in sharedOptions) {
    apply(parser.commands['run']!);
    apply(parser.commands['update']!);
  }

  parser.commands['run']!
    ..addFlag(
      'github-pr',
      help: 'Post results as a GitHub PR comment',
      negatable: false,
    )
    ..addOption(
      'fail-on',
      help:
          'Comma-separated failure categories that cause a non-zero exit.\n'
          'Categories: overflow, arb, golden, all (default: all)',
      defaultsTo: 'all',
    );

  parser.commands['merge']!
    ..addMultiOption(
      'input',
      abbr: 'i',
      help: 'Shard output directories to merge',
    )
    ..addOption('output', abbr: 'o', help: 'Merged output directory')
    ..addFlag(
      'github-pr',
      help: 'Post merged results as a GitHub PR comment',
      negatable: false,
    )
    ..addOption(
      'fail-on',
      help: 'Failure categories for exit code',
      defaultsTo: 'all',
    );

  parser.commands['scan']!
    ..addOption(
      'root',
      help: 'Root directory to scan for packages',
      defaultsTo: '.',
    )
    ..addOption(
      'test-dir',
      help: 'Test subdirectory name to look for',
      defaultsTo: 'test/sweep',
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
  } else if (commandName == 'merge') {
    await _mergeShards(parsed.command!);
  } else if (commandName == 'scan') {
    _scanPackages(parsed.command!);
  }
}

Set<String> _failureCategories(ArgResults args) {
  final categories =
      (args.options.contains('fail-on') ? args['fail-on'] as String : 'all')
          .split(',')
          .map((s) => s.trim())
          .toSet();
  const valid = {'all', 'none', 'overflow', 'arb', 'golden'};
  if (categories.any((c) => !valid.contains(c)) ||
      (categories.length > 1 &&
          (categories.contains('all') || categories.contains('none')))) {
    throw const FormatException(
      'Use --fail-on all, none, or a comma-separated '
      'list of overflow, arb, golden.',
    );
  }
  return categories;
}

Future<void> _runSweep(ArgResults args, {required bool updateGoldens}) async {
  final failOn = _failureCategories(args);
  final shards = int.tryParse(args['shards'] as String? ?? '1');
  final shardIndex = int.tryParse(args['shard-index'] as String? ?? '0');
  if (shards == null ||
      shards < 1 ||
      shardIndex == null ||
      shardIndex < 0 ||
      shardIndex >= shards ||
      (args['shard-index'] != null && args['shards'] == null)) {
    throw const FormatException(
      'Use --shards N (N > 0) and --shard-index I (0 <= I < N).',
    );
  }
  final packages = args['packages'] as String?;
  final dirs = packages?.split(',').map((s) => s.trim()).toList() ?? ['.'];
  if (dirs.any((d) => d.isEmpty)) {
    throw const FormatException('--packages must contain package directories.');
  }
  final allResults = <SweepResult>[];
  final errors = <String>[];
  ParsedReport? singleReport;
  for (final dir in dirs) {
    final absoluteDir = p.normalize(p.absolute(dir));
    if (packages != null) stdout.writeln('━━━ Package: $dir ━━━');
    final report = await _runInDirectory(
      absoluteDir,
      args,
      updateGoldens: updateGoldens,
    );
    singleReport = report;
    allResults.addAll(report.results);
    errors.addAll(report.executionErrors.map((e) => '$dir: $e'));
  }
  final report = packages == null
      ? singleReport!
      : mergeResults(allResults, executionErrors: errors);
  if (packages != null) {
    final output = args['output'] as String? ?? '.locale_sweep/reports';
    _writeReport(report, output);
    stdout.writeln('━━━ Merged Report ━━━');
    stdout.writeln(report.summary);
  }
  if (args.options.contains('github-pr') && args['github-pr'] as bool) {
    await _postToGitHub(report);
  }
  if (shouldFail(report, failOn)) exitCode = 1;
}

Future<ParsedReport> _runInDirectory(
  String dir,
  ArgResults args, {
  required bool updateGoldens,
}) async {
  final configArgument = args['config'] as String;
  final configPath = p.normalize(
    p.isAbsolute(configArgument) ? configArgument : p.join(dir, configArgument),
  );
  final outputArgument = args['output'] as String?;
  var output = p.normalize(
    outputArgument != null && p.isAbsolute(outputArgument)
        ? outputArgument
        : p.join(dir, outputArgument ?? '.locale_sweep/reports'),
  );
  var report = mergeResults([]);
  try {
    if (!Directory(dir).existsSync()) {
      throw FileSystemException('Package directory not found', dir);
    }
    if (args.wasParsed('config') && !File(configPath).existsSync()) {
      throw FileSystemException('Configuration file not found', configPath);
    }
    final cfg = SweepConfig.load(configPath);
    output = p.normalize(
      outputArgument != null && p.isAbsolute(outputArgument)
          ? outputArgument
          : p.join(dir, outputArgument ?? cfg.reportDir),
    );
    final testArgument = args['test-dir'] as String;
    final testDir = Directory(
      p.normalize(
        p.isAbsolute(testArgument) ? testArgument : p.join(dir, testArgument),
      ),
    );
    if (!testDir.existsSync()) {
      throw FileSystemException('Test directory not found', testDir.path);
    }
    var files = testDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .toList();
    final flows = args['flows'] as String?;
    if (flows != null) {
      final names = flows.split(',').map((s) => s.trim()).toSet();
      files = files
          .where(
            (f) => names.contains(
              p.basename(f.path).replaceFirst(RegExp(r'_test\.dart$'), ''),
            ),
          )
          .toList();
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      throw StateError(
        'No sweep test files match in ${testDir.path}'
        '${flows == null ? '' : ' (flows: $flows)'}.',
      );
    }
    final runs = Directory(p.join(dir, '.locale_sweep', 'runs'))
      ..createSync(recursive: true);
    final runDir = runs.createTempSync('run_');
    final resultsDir = p.join(runDir.path, 'results');
    final flutterArgs = <String>[
      'test',
      '--machine',
      if (updateGoldens) '--update-goldens',
      if (args['shards'] != null) '--total-shards=${args['shards']}',
      if (args['shards'] != null) '--shard-index=${args['shard-index'] ?? '0'}',
      ...files.map((f) => f.path),
    ];
    final verbose = args['verbose'] as bool;
    stdout.writeln(
      'LocaleSweep — ${updateGoldens ? 'Updating goldens' : 'Running checks'}',
    );
    stdout.writeln('Config: $configPath');
    stdout.writeln('${files.length} test file(s)');
    if (verbose) stdout.writeln('flutter ${flutterArgs.join(' ')}');
    final process = await Process.start(
      'flutter',
      flutterArgs,
      workingDirectory: dir,
      environment: {
        'LOCALE_SWEEP_CONFIG': configPath,
        'LOCALE_SWEEP_RESULTS_DIR': resultsDir,
        'LOCALE_SWEEP_MANAGED_RUN': 'true',
      },
    );
    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    var completed = false;
    var finished = 0;
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          stdoutBuf.writeln(line);
          if (verbose) stdout.writeln(line);
          try {
            final event = jsonDecode(line) as Map<String, dynamic>;
            if (event['type'] == 'done') completed = true;
            if (event['type'] == 'testDone' &&
                event['hidden'] != true &&
                event['skipped'] != true) {
              finished++;
              if (!verbose) stdout.write('\r  $finished test(s) completed');
            }
          } on FormatException {
            // Flutter can emit non-JSON startup messages.
          }
        });
    final stderrDone = process.stderr.transform(utf8.decoder).forEach((data) {
      stderrBuf.write(data);
      if (verbose) stderr.write(data);
    });
    final code = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    if (!verbose && finished > 0) stdout.writeln();
    // Keep the process transcript next to the isolated results for diagnosis.
    File(
      p.join(runDir.path, 'flutter.jsonl'),
    ).writeAsStringSync(stdoutBuf.toString());
    File(
      p.join(runDir.path, 'stderr.log'),
    ).writeAsStringSync(stderrBuf.toString());
    final loaded = loadResults(cfg, resultsPath: resultsDir);
    final executionErrors = <String>[...?loaded?.executionErrors];
    if (code != 0) {
      executionErrors.add(
        'flutter test exited with code $code. '
        'See ${p.join(runDir.path, 'flutter.jsonl')} and stderr.log.',
      );
      if (!verbose && stderrBuf.isNotEmpty) stderr.write(stderrBuf);
    }
    if (!completed) {
      executionErrors.add('Flutter did not complete its test run.');
    }
    if ((loaded == null || loaded.total == 0) && args['shards'] == null) {
      executionErrors.add('No sweep variants completed in this run.');
    }
    report = mergeResults(
      loaded?.results ?? [],
      executionErrors: executionErrors,
    );
  } catch (e) {
    report = mergeResults(
      report.results,
      executionErrors: [...report.executionErrors, e.toString()],
    );
  }
  // Do not create a nonexistent input package just to write its error report.
  if (Directory(dir).existsSync()) _writeReport(report, output);
  stdout.writeln(report.summary);
  for (final error in report.executionErrors) {
    stderr.writeln('Error: $error');
  }
  if (updateGoldens && !shouldFail(report, {'all'})) {
    stdout.writeln(
      'Goldens updated. Commit the screenshots to use as baselines.',
    );
  }
  return report;
}

void _writeReport(ParsedReport report, String output) {
  Directory(output).createSync(recursive: true);
  File(p.join(output, 'report.md')).writeAsStringSync(report.markdown);
  File(p.join(output, 'report.json')).writeAsStringSync(report.json);
  File(p.join(output, 'report.html')).writeAsStringSync(report.html);
  stdout.writeln('Report: ${p.join(output, 'report.html')}');
}

Future<void> _mergeShards(ArgResults args) async {
  final failOn = _failureCategories(args);
  final inputs = args['input'] as List<String>;
  if (inputs.isEmpty) {
    throw const FormatException('--input is required.');
  }
  final results = <SweepResult>[];
  final errors = <String>[];
  for (final dir in inputs) {
    final file = File(p.join(dir, 'report.json'));
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final shardResults = (data['results'] as List)
          .map((e) => SweepResult.fromJson(e as Map<String, dynamic>))
          .toList();
      final shardErrors = (data['executionErrors'] as List? ?? [])
          .cast<String>();
      results.addAll(shardResults);
      errors.addAll(shardErrors.map((e) => '$dir: $e'));
    } catch (e) {
      errors.add('Failed to read ${file.path}: $e');
    }
  }
  if (results.isEmpty) errors.add('No sweep variants in the merged reports.');
  final report = mergeResults(results, executionErrors: errors);
  _writeReport(report, args['output'] as String? ?? '.locale_sweep/reports');
  stdout.writeln(report.summary);
  if (args['github-pr'] as bool) await _postToGitHub(report);
  if (shouldFail(report, failOn)) exitCode = 1;
}

void _scanPackages(ArgResults args) {
  final root = args['root'] as String;
  final testDir = args['test-dir'] as String;
  final packages = discoverPackages(root, testDir: testDir);

  if (packages.isEmpty) {
    stdout.writeln('No packages with sweep tests found in "$root".');
    stdout.writeln('Looking for packages containing a $testDir/ directory.');
    return;
  }

  stdout.writeln('Found ${packages.length} package(s) with sweep tests:');
  for (final pkg in packages) {
    stdout.writeln('  $pkg');
  }
  stdout.writeln();
  stdout.writeln('Run with: locale_sweep run --packages ${packages.join(",")}');
}

Future<void> _postToGitHub(ParsedReport report) async {
  try {
    final reporter = GitHubReporter.fromEnv();
    final summary = SweepRunSummary(
      results: report.results,
      executionErrors: report.executionErrors,
    );
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
  stdout.writeln('  merge    Combine reports from parallel shards');
  stdout.writeln('  scan     Discover packages with sweep tests (monorepo)');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(parser.commands['run']!.usage);
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  locale_sweep run');
  stdout.writeln('  locale_sweep run --flows onboarding,checkout,settings');
  stdout.writeln('  locale_sweep run --github-pr');
  stdout.writeln('  locale_sweep run --fail-on overflow,golden');
  stdout.writeln('  locale_sweep run --fail-on none');
  stdout.writeln('  locale_sweep update');
  stdout.writeln('  locale_sweep update --flows onboarding');
  stdout.writeln();
  stdout.writeln('Parallel sharding:');
  stdout.writeln('  locale_sweep run --shards 3 --shard-index 0');
  stdout.writeln('  locale_sweep run --shards 3 --shard-index 1');
  stdout.writeln('  locale_sweep run --shards 3 --shard-index 2');
  stdout.writeln('  locale_sweep merge -i shard_0 -i shard_1 -i shard_2');
  stdout.writeln();
  stdout.writeln('Monorepo:');
  stdout.writeln('  locale_sweep scan');
  stdout.writeln('  locale_sweep run --packages apps/auth,apps/dashboard');
}
