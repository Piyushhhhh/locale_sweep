import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:locale_sweep/src/cli/cli_parser.dart';
import 'package:locale_sweep/src/cli/flow_filter.dart';
import 'package:locale_sweep/src/cli/machine_output.dart';
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
    (p) => p.addOption(
      'timeout',
      help:
          'Abort the flutter test run after this many seconds. Optional: when '
          'omitted the run is unbounded and the CI job timeout applies.',
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
          'Categories: overflow, arb, golden, truncation, hardcoded, all '
          '(default: all)',
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

/// How many `.locale_sweep/runs/*` directories are kept.
const _keptRuns = 10;

Set<String> _failureCategories(ArgResults args) {
  final categories =
      (args.options.contains('fail-on') ? args['fail-on'] as String : 'all')
          .split(',')
          .map((s) => s.trim())
          .toSet();
  const valid = {
    'all',
    'none',
    'overflow',
    'arb',
    'golden',
    'truncation',
    'hardcoded',
  };
  if (categories.any((c) => !valid.contains(c)) ||
      (categories.length > 1 &&
          (categories.contains('all') || categories.contains('none')))) {
    throw const FormatException(
      'Use --fail-on all, none, or a comma-separated '
      'list of overflow, arb, golden, truncation, hardcoded.',
    );
  }
  return categories;
}

Future<void> _runSweep(ArgResults args, {required bool updateGoldens}) async {
  final failOn = _failureCategories(args);
  final timeout = _runTimeout(args);
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
      timeout: timeout,
    );
    singleReport = report;
    // Results carry screenshot paths relative to their package directory.
    // Rebase them to the CLI working directory so the merged report can link
    // to files from every package.
    allResults.addAll(
      report.results.map(
        (result) => _rebaseScreenshotPath(result, absoluteDir),
      ),
    );
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
  required Duration? timeout,
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
    String? namePattern;
    if (flows != null) {
      final names = flows
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      final selection = selectFlows({
        for (final f in files) f.path: f.readAsStringSync(),
      }, names);
      if (selection.files.isEmpty) {
        final available = selection.declaredFlows.toList()..sort();
        throw StateError(
          'No sweep flows match "$flows" in ${testDir.path}.'
          '${available.isEmpty ? '' : ' Available flows: ${available.join(', ')}.'}',
        );
      }
      files = selection.files.map(File.new).toList();
      namePattern = selection.namePattern;
      if (selection.matchedByFileNameOnly) {
        stderr.writeln(
          'Warning: --flows matched file name(s) only; every sweep flow '
          'declared in ${selection.files.join(', ')} will run.',
        );
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      throw StateError('No sweep test files found in ${testDir.path}.');
    }
    final runs = Directory(p.join(dir, '.locale_sweep', 'runs'))
      ..createSync(recursive: true);
    final runDir = runs.createTempSync('run_');
    _pruneRuns(runs);
    final resultsDir = p.join(runDir.path, 'results');
    final flutterArgs = <String>[
      'test',
      '--machine',
      if (updateGoldens) '--update-goldens',
      if (args['shards'] != null) '--total-shards=${args['shards']}',
      if (args['shards'] != null) '--shard-index=${args['shard-index'] ?? '0'}',
      if (namePattern != null) '--name=$namePattern',
      ...files.map((f) => f.path),
    ];
    final verbose = args['verbose'] as bool;
    stdout.writeln(
      'LocaleSweep — ${updateGoldens ? 'Updating goldens' : 'Running checks'}',
    );
    stdout.writeln('Config: $configPath');
    stdout.writeln('${files.length} test file(s)');
    if (verbose) stdout.writeln('flutter ${flutterArgs.join(' ')}');
    final process = await _startFlutter(flutterArgs, dir, {
      'LOCALE_SWEEP_CONFIG': configPath,
      'LOCALE_SWEEP_RESULTS_DIR': resultsDir,
      'LOCALE_SWEEP_MANAGED_RUN': 'true',
    });
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
          // Plain startup text and the JSON array line that
          // `flutter test --machine` prints first both used to abort the run
          // with an unhandled TypeError.
          for (final event in parseMachineLine(line)) {
            if (event['type'] == 'done') completed = true;
            if (event['type'] == 'testDone' &&
                event['hidden'] != true &&
                event['skipped'] != true) {
              finished++;
              if (!verbose) stdout.write('\r  $finished test(s) completed');
            }
          }
        });
    final stderrDone = process.stderr.transform(utf8.decoder).forEach((data) {
      stderrBuf.write(data);
      if (verbose) stderr.write(data);
    });
    // A hung golden wait or font download used to block the CLI forever.
    final exit = await _waitForExit(process, timeout);
    final code = exit.code;
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
    if (exit.timedOut) {
      executionErrors.add(
        'flutter test was killed after ${timeout!.inSeconds}s. '
        'Raise the limit with --timeout <seconds>.',
      );
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
  if (Directory(dir).existsSync()) {
    _writeReport(report, output, packageDir: dir);
  }
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

/// Starts `flutter test`.
///
/// On Windows the SDK entry point is `flutter.bat`, which [Process.start]
/// does not resolve from `PATH` (it does not apply `PATHEXT`), so the run
/// failed with "The system cannot find the file specified" before any test
/// executed.
Future<Process> _startFlutter(
  List<String> args,
  String workingDirectory,
  Map<String, String> environment,
) async {
  try {
    return await Process.start(
      'flutter',
      args,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  } on ProcessException {
    return Process.start(
      'flutter.bat',
      args,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }
}

/// Reads `--timeout`.
///
/// The timeout is opt-in: when omitted the run is unbounded, so sweeps that
/// currently pass (large matrices, monorepos) keep working and the CI job
/// timeout is the only backstop. An invalid value is surfaced as a usage error
/// rather than silently falling back to a default.
Duration? _runTimeout(ArgResults args) {
  final raw = args['timeout'] as String?;
  if (raw == null || raw.isEmpty) return null;
  final seconds = int.tryParse(raw);
  if (seconds == null || seconds <= 0) {
    throw FormatException(
      '--timeout must be a positive number of seconds (got "$raw").',
    );
  }
  return Duration(seconds: seconds);
}

/// Waits for [process], terminating it when [timeout] elapses.
///
/// [timeout] may be null for an unbounded wait. When the bound is hit the
/// process is killed; if it survives that, it is escalated to SIGKILL so a hung
/// golden wait or font download cannot keep the CLI open forever.
Future<({int code, bool timedOut})> _waitForExit(
  Process process,
  Duration? timeout,
) async {
  if (timeout == null) {
    return (code: await process.exitCode, timedOut: false);
  }
  try {
    return (code: await process.exitCode.timeout(timeout), timedOut: false);
  } on TimeoutException {
    stderr.writeln(
      'Error: flutter test exceeded ${timeout.inSeconds}s; terminating it.',
    );
    process.kill();
    const killGrace = Duration(seconds: 10);
    final code = await process.exitCode.timeout(
      killGrace,
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    return (code: code, timedOut: true);
  }
}

/// Deletes the oldest run directories, keeping the [_keptRuns] most recent.
///
/// Every run writes a transcript plus its result files here, so an unpruned
/// directory grows without bound on CI.
void _pruneRuns(Directory runs) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final directories = runs.listSync().whereType<Directory>().toList();
  final modified = <Directory, DateTime>{};
  for (final directory in directories) {
    try {
      modified[directory] = directory.statSync().modified;
    } catch (_) {
      modified[directory] = epoch;
    }
  }
  directories.sort(
    (a, b) => (modified[b] ?? epoch).compareTo(modified[a] ?? epoch),
  );
  for (final directory in directories.skip(_keptRuns)) {
    try {
      directory.deleteSync(recursive: true);
    } catch (_) {
      // A locked or already-removed directory is not worth failing over.
    }
  }
}

void _writeReport(ParsedReport report, String output, {String? packageDir}) {
  Directory(output).createSync(recursive: true);
  // Screenshot paths in results are relative to the package directory, but
  // the report is written to (often nested) `output`. Rewrite them so the
  // HTML/Markdown image links resolve from the report's own location.
  final base = p.relative(
    p.absolute(packageDir ?? '.'),
    from: p.absolute(output),
  );
  var html = report.html;
  var markdown = report.markdown;
  for (final result in report.results) {
    for (final path in {
      result.screenshotPath,
      result.actualScreenshotPath,
      result.diff?.diffImagePath,
    }) {
      if (path == null || path.isEmpty) continue;
      final rewritten = p.posix.joinAll(
        p.split(p.normalize(p.join(base, path))),
      );
      html = html.replaceAll('src="$path"', 'src="$rewritten"');
      html = html.replaceAll('href="$path"', 'href="$rewritten"');
      markdown = markdown.replaceAll(']($path)', ']($rewritten)');
    }
  }
  File(p.join(output, 'report.md')).writeAsStringSync(markdown);
  File(p.join(output, 'report.json')).writeAsStringSync(report.json);
  File(p.join(output, 'report.html')).writeAsStringSync(html);
  stdout.writeln('Report: ${p.join(output, 'report.html')}');
}

/// Rewrites package-relative screenshot paths to ones relative to the CLI
/// working directory.
SweepResult _rebaseScreenshotPath(SweepResult result, String packageDir) {
  String? rebase(String? path) {
    if (path == null || path.isEmpty || p.isAbsolute(path)) return path;
    final absolute = p.normalize(p.join(packageDir, path));
    return p.posix.joinAll(
      p.split(p.relative(absolute, from: p.absolute('.'))),
    );
  }

  var diff = result.diff;
  final diffImage = diff?.diffImagePath;
  if (diff != null && diffImage != null && diffImage.isNotEmpty) {
    diff = diff.withDiffImagePath(rebase(diffImage)!);
  }

  return result.copyWith(
    screenshotPath: rebase(result.screenshotPath),
    actualScreenshotPath: rebase(result.actualScreenshotPath),
    diff: diff,
  );
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
