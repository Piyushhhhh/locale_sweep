import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:locale_sweep/src/cli/cli_parser.dart';
import 'package:locale_sweep/src/config/sweep_config.dart';
import 'package:locale_sweep/src/report/github_reporter.dart';
import 'package:locale_sweep/src/report/sweep_result.dart';

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
  final failOnRaw = args.options.contains('fail-on')
      ? args['fail-on'] as String
      : 'all';
  final failOn = failOnRaw.split(',').map((s) => s.trim()).toSet();

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
}
