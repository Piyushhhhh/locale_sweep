import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:locale_sweep/src/cli/cli_parser.dart';
import 'package:locale_sweep/src/cli/package_discovery.dart';
import 'package:locale_sweep/src/config/sweep_config.dart';
import 'package:locale_sweep/src/report/github_reporter.dart';
import 'package:locale_sweep/src/report/sweep_result.dart';

void main(List<String> args) async {
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

Future<void> _runSweep(ArgResults args, {required bool updateGoldens}) async {
  final packages = args['packages'] as String?;

  if (packages != null) {
    final pkgDirs = packages.split(',').map((s) => s.trim()).toList();
    await _runMultiPackage(pkgDirs, args, updateGoldens: updateGoldens);
    return;
  }

  await _runSinglePackage(args, updateGoldens: updateGoldens);
}

Future<void> _runMultiPackage(
  List<String> pkgDirs,
  ArgResults args, {
  required bool updateGoldens,
}) async {
  final allResults = <SweepResult>[];
  var anyFailed = false;

  for (final pkgDir in pkgDirs) {
    final absDir = p.isAbsolute(pkgDir)
        ? pkgDir
        : p.join(Directory.current.path, pkgDir);
    if (!Directory(absDir).existsSync()) {
      stderr.writeln(
        'Warning: Package directory "$pkgDir" not found, skipping.',
      );
      continue;
    }

    final pkgName = p.basename(absDir);
    stdout.writeln('━━━ Package: $pkgName ━━━');

    final exitCode = await _runInDirectory(
      absDir,
      args,
      updateGoldens: updateGoldens,
    );
    if (exitCode != 0) anyFailed = true;

    final cfg = SweepConfig.load(p.join(absDir, args['config'] as String));
    final outputDir = args['output'] as String? ?? cfg.reportDir;
    final jsonPath = p.join(absDir, outputDir, 'report.json');
    if (File(jsonPath).existsSync()) {
      final data =
          jsonDecode(File(jsonPath).readAsStringSync()) as Map<String, dynamic>;
      final results = (data['results'] as List)
          .map((e) => SweepResult.fromJson(e as Map<String, dynamic>))
          .toList();
      allResults.addAll(results);
    }
    stdout.writeln();
  }

  if (allResults.isNotEmpty) {
    final mergedReport = mergeResults(allResults);
    final outputDir = args['output'] as String? ?? '.locale_sweep/reports';
    Directory(outputDir).createSync(recursive: true);
    File('$outputDir/report.md').writeAsStringSync(mergedReport.markdown);
    File('$outputDir/report.json').writeAsStringSync(mergedReport.json);
    File('$outputDir/report.html').writeAsStringSync(mergedReport.html);

    stdout.writeln('━━━ Merged Report ━━━');
    stdout.writeln(mergedReport.summary);
    stdout.writeln('Report: $outputDir/report.html');
  }

  if (anyFailed && !updateGoldens) exit(1);
}

Future<int> _runInDirectory(
  String dir,
  ArgResults args, {
  required bool updateGoldens,
}) async {
  final testDir = args['test-dir'] as String;
  final configPath = args['config'] as String;
  final verbose = args['verbose'] as bool;
  final shards = args['shards'] as String?;
  final shardIndex = args['shard-index'] as String?;

  final flutterArgs = <String>[
    'test',
    '--machine',
    if (updateGoldens) '--update-goldens',
    if (shards != null) '--total-shards=$shards',
    if (shardIndex != null) '--shard-index=$shardIndex',
    testDir,
  ];

  final process = await Process.start(
    'flutter',
    flutterArgs,
    workingDirectory: dir,
  );
  final buf = StringBuffer();
  process.stdout.transform(utf8.decoder).listen((d) => buf.write(d));
  process.stderr.transform(utf8.decoder).listen((d) {
    if (verbose) stderr.write(d);
  });
  final code = await process.exitCode;

  final cfg = SweepConfig.load(p.join(dir, configPath));
  final outputDir = args['output'] as String? ?? cfg.reportDir;
  final fullOutputDir = p.join(dir, outputDir);
  Directory(fullOutputDir).createSync(recursive: true);

  final report =
      loadResults(cfg, resultsPath: p.join(dir, '.locale_sweep/results')) ??
      parseMachineOutput(buf.toString(), cfg);
  File('$fullOutputDir/report.md').writeAsStringSync(report.markdown);
  File('$fullOutputDir/report.json').writeAsStringSync(report.json);
  File('$fullOutputDir/report.html').writeAsStringSync(report.html);
  stdout.writeln('  ${report.summary}');

  return code;
}

Future<void> _runSinglePackage(
  ArgResults args, {
  required bool updateGoldens,
}) async {
  final configPath = args['config'] as String;
  final cfg = SweepConfig.load(configPath);

  final testDir = args['test-dir'] as String;
  final outputDir = args['output'] as String? ?? cfg.reportDir;
  final flows = args['flows'] as String?;
  final verbose = args['verbose'] as bool;
  final githubPr =
      args.options.contains('github-pr') && args['github-pr'] as bool;
  final failOnRaw = args.options.contains('fail-on')
      ? args['fail-on'] as String
      : 'all';
  final failOn = failOnRaw.split(',').map((s) => s.trim()).toSet();
  final shards = args['shards'] as String?;
  final shardIndex = args['shard-index'] as String?;

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
  if (shards != null) {
    stdout.writeln('Shard ${shardIndex ?? 0} of $shards');
  }
  stdout.writeln('${filesToRun.length} flow(s)');
  stdout.writeln();

  final flutterArgs = <String>[
    'test',
    '--machine',
    if (updateGoldens) '--update-goldens',
    if (shards != null) '--total-shards=$shards',
    if (shardIndex != null) '--shard-index=$shardIndex',
    ...filesToRun.map((f) => f.path),
  ];

  if (verbose) {
    stdout.writeln('flutter ${flutterArgs.join(" ")}');
    stdout.writeln();
  }

  final process = await Process.start('flutter', flutterArgs);

  final stdoutBuf = StringBuffer();
  final stderrBuf = StringBuffer();
  var passCount = 0;
  var failCount = 0;
  var lineBuf = StringBuffer();

  process.stdout.transform(utf8.decoder).listen((data) {
    stdoutBuf.write(data);
    if (verbose) {
      stdout.write(data);
    } else {
      lineBuf.write(data);
      final lines = lineBuf.toString().split('\n');
      lineBuf = StringBuffer(lines.last);
      for (var i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || !line.startsWith('{')) continue;
        try {
          final event = jsonDecode(line) as Map<String, dynamic>;
          if (event['type'] == 'testDone' && event['skipped'] != true) {
            if (event['result'] == 'success') {
              passCount++;
            } else {
              failCount++;
            }
            final total = passCount + failCount;
            final status = failCount > 0
                ? '$passCount passed, $failCount failed'
                : '$passCount passed';
            stdout.write('\r  $total variant(s) tested — $status');
          }
        } catch (_) {}
      }
    }
  });
  process.stderr.transform(utf8.decoder).listen((data) {
    stderrBuf.write(data);
    if (verbose) stderr.write(data);
  });

  await process.exitCode;
  if (!verbose && (passCount + failCount) > 0) stdout.writeln();

  final report =
      loadResults(cfg) ?? parseMachineOutput(stdoutBuf.toString(), cfg);
  final reportPath = '$outputDir/report.md';
  final jsonPath = '$outputDir/report.json';
  final htmlPath = '$outputDir/report.html';

  File(reportPath).writeAsStringSync(report.markdown);
  File(jsonPath).writeAsStringSync(report.json);
  File(htmlPath).writeAsStringSync(report.html);

  stdout.writeln(report.summary);
  stdout.writeln();
  stdout.writeln('Report: $htmlPath');
  stdout.writeln('        $reportPath');
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

  if (!updateGoldens) {
    final fail = shouldFail(report, failOn);
    if (fail) exit(1);
  }
}

Future<void> _mergeShards(ArgResults args) async {
  final inputDirs = args['input'] as List<String>;
  final outputDir = args['output'] as String? ?? '.locale_sweep/reports';
  final githubPr = args['github-pr'] as bool;
  final failOnRaw = args['fail-on'] as String;
  final failOn = failOnRaw.split(',').map((s) => s.trim()).toSet();

  if (inputDirs.isEmpty) {
    stderr.writeln(
      'Error: --input is required. Provide shard output directories.',
    );
    stderr.writeln(
      'Example: locale_sweep merge -i shard_0 -i shard_1 -i shard_2',
    );
    exit(1);
  }

  final allResults = <SweepResult>[];
  for (final dir in inputDirs) {
    final jsonPath = '$dir/report.json';
    if (!File(jsonPath).existsSync()) {
      stderr.writeln('Warning: No report.json in "$dir", skipping.');
      continue;
    }
    try {
      final data =
          jsonDecode(File(jsonPath).readAsStringSync()) as Map<String, dynamic>;
      final results = (data['results'] as List)
          .map((e) => SweepResult.fromJson(e as Map<String, dynamic>))
          .toList();
      allResults.addAll(results);
      stdout.writeln('  Loaded ${results.length} result(s) from $dir');
    } catch (e) {
      stderr.writeln('Warning: Failed to read $jsonPath: $e');
    }
  }

  if (allResults.isEmpty) {
    stderr.writeln('Error: No results found in any input directory.');
    exit(1);
  }

  final report = mergeResults(allResults);
  Directory(outputDir).createSync(recursive: true);
  File('$outputDir/report.md').writeAsStringSync(report.markdown);
  File('$outputDir/report.json').writeAsStringSync(report.json);
  File('$outputDir/report.html').writeAsStringSync(report.html);

  stdout.writeln();
  stdout.writeln(
    'Merged ${allResults.length} results from ${inputDirs.length} shard(s)',
  );
  stdout.writeln(report.summary);
  stdout.writeln();
  stdout.writeln('Report: $outputDir/report.html');
  stdout.writeln('        $outputDir/report.md');
  stdout.writeln('JSON:   $outputDir/report.json');

  if (githubPr) {
    await _postToGitHub(report);
  }

  final fail = shouldFail(report, failOn);
  if (fail) exit(1);
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
