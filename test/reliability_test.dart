import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';
import 'package:path/path.dart' as p;

void main() {
  final project = Directory.current.path;
  late String flutterRoot;
  late String dart;
  late Directory temporary;

  setUpAll(() {
    final packageConfig =
        jsonDecode(
              File(
                '$project/.dart_tool/package_config.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final flutterPackage = (packageConfig['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((entry) => entry['name'] == 'flutter');
    final flutterPackageRoot = Uri.parse(
      flutterPackage['rootUri'] as String,
    ).toFilePath();
    flutterRoot = p.normalize(p.join(flutterPackageRoot, '../..'));
    dart = p.join(flutterRoot, 'bin/cache/dart-sdk/bin/dart');
  });
  setUp(
    () => temporary = Directory.systemTemp.createTempSync('sweep_reliability_'),
  );
  tearDown(() => temporary.deleteSync(recursive: true));

  const variant = SweepVariant(
    locale: 'de',
    textScale: 1,
    viewport: ViewportPreset.phone,
  );
  const arbResult = SweepResult(
    flowName: 'arb',
    variant: variant,
    passed: true,
    arbIssues: [
      ArbIssue(
        type: ArbIssueType.missingKey,
        locale: 'de',
        key: 'title',
        detail: 'Missing title',
      ),
    ],
  );

  test('ARB-only findings agree in CLI, HTML, Markdown and JSON', () {
    final report = mergeResults([arbResult]);
    expect(report.failed, 1);
    expect(report.passed, 0);
    expect(report.markdown, contains('1/1 variants failed'));
    expect(report.html, contains('badge-fail'));
    final json = jsonDecode(report.json) as Map<String, dynamic>;
    expect(json['failed'], 1);
    expect((json['results'] as List).single['passed'], isFalse);
    expect(shouldFail(report, {'all'}), isTrue);
    expect(shouldFail(report, {'arb'}), isTrue);
    expect(shouldFail(report, {'overflow'}), isFalse);
    expect(shouldFail(report, {'none'}), isFalse);
  });

  test('unexpected and legacy unclassified errors cannot be filtered away', () {
    for (final kind in [null, SweepFailureKind.test]) {
      final report = mergeResults([
        SweepResult(
          flowName: 'test',
          variant: variant,
          passed: false,
          errorMessage: 'callback failed',
          failureKind: kind,
        ),
      ]);
      for (final filter in ['all', 'none', 'overflow', 'arb', 'golden']) {
        expect(shouldFail(report, {filter}), isTrue);
      }
    }
    const golden = SweepResult(
      flowName: 'golden',
      variant: variant,
      passed: false,
      errorMessage: 'mismatch',
      failureKind: SweepFailureKind.golden,
    );
    expect(
      SweepResult.fromJson(golden.toJson()).failureKind,
      SweepFailureKind.golden,
    );
    expect(shouldFail(mergeResults([golden]), {'arb'}), isFalse);
  });

  test('execution errors remain visible even with zero failed variants', () {
    final report = mergeResults([], executionErrors: ['Compilation <failed>']);
    expect(shouldFail(report, {'none'}), isTrue);
    expect(report.summary, isNot(contains('All 0 variants passed')));
    expect(report.markdown, contains('Run incomplete'));
    expect(report.html, contains('Compilation &lt;failed&gt;'));
    expect(jsonDecode(report.json)['executionErrors'], [
      'Compilation <failed>',
    ]);
  });

  Future<void> prepareFakePackage(String directory) async {
    Directory(p.join(directory, 'test/sweep')).createSync(recursive: true);
    File(
      p.join(directory, 'test/sweep/current_test.dart'),
    ).writeAsStringSync('');
    File(p.join(directory, 'test/sweep/other_test.dart')).writeAsStringSync('');
    final bin = Directory(p.join(temporary.path, 'bin'))..createSync();
    final fake = p.join(project, 'test/fixtures/reliability/fake_flutter.dart');
    String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
    File(p.join(bin.path, 'flutter')).writeAsStringSync(
      '#!/bin/sh\nexec ${quote(dart)} ${quote(fake)} "\$@"\n',
    );
    final chmod = await Process.run('chmod', [
      '+x',
      p.join(bin.path, 'flutter'),
    ]);
    expect(chmod.exitCode, 0);
  }

  Future<ProcessResult> cli(
    List<String> args, {
    String mode = 'clean',
    String? cwd,
  }) => Process.run(
    dart,
    [
      '--packages=$project/.dart_tool/package_config.json',
      '$project/bin/locale_sweep.dart',
      ...args,
    ],
    workingDirectory: cwd ?? temporary.path,
    environment: {
      'PATH':
          '${temporary.path}/bin${Platform.pathSeparator == '/' ? ':' : ';'}${Platform.environment['PATH']}',
      'SWEEP_FAKE_MODE': mode,
    },
  );

  Map<String, dynamic> readReport([String? dir]) =>
      jsonDecode(
            File(
              p.join(
                dir ?? temporary.path,
                '.locale_sweep/reports/report.json',
              ),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('CLI process boundary', () {
    test(
      'category filtering and update exit codes use the same findings',
      () async {
        await prepareFakePackage(temporary.path);
        for (final mode in ['arb', 'golden', 'overflow']) {
          for (final filter in ['all', mode, 'none']) {
            final run = await cli(['run', '--fail-on', filter], mode: mode);
            expect(
              run.exitCode,
              filter == 'none' ? 0 : 1,
              reason: '${run.stdout}\n${run.stderr}',
            );
            expect(readReport()['failed'], 1);
          }
          final update = await cli(['update'], mode: mode);
          expect(update.exitCode, 1);
          expect(update.stdout, isNot(contains('Goldens updated.')));
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'current invocation excludes stale results and honors selected files',
      () async {
        await prepareFakePackage(temporary.path);
        final old = File('${temporary.path}/.locale_sweep/results/stale.json');
        old.parent.createSync(recursive: true);
        old.writeAsStringSync(jsonEncode([arbResult.toJson()]));
        File(
          '${temporary.path}/custom.yaml',
        ).writeAsStringSync('locales: [ja]\n');
        final first = await cli([
          'run',
          '--flows',
          'current',
          '--config',
          'custom.yaml',
        ]);
        expect(first.exitCode, 0, reason: '${first.stderr}');
        final invocation = jsonDecode(
          File('${temporary.path}/invocation.json').readAsStringSync(),
        );
        expect(
          invocation['config'],
          File('${temporary.path}/custom.yaml').resolveSymbolicLinksSync(),
        );
        expect(invocation['managed'], 'true');
        expect(
          (invocation['args'] as List).where(
            (e) => e.toString().endsWith('_test.dart'),
          ),
          hasLength(1),
        );
        expect((readReport()['results'] as List).single['flow'], 'current');
        final previousResultsDir = invocation['results'];
        final second = await cli(['run']);
        expect(second.exitCode, 0);
        final next = jsonDecode(
          File('${temporary.path}/invocation.json').readAsStringSync(),
        );
        expect(next['results'], isNot(previousResultsDir));
        expect(old.existsSync(), isTrue);

        final absoluteOutput = '${temporary.path}/absolute-report';
        final absolute = await cli([
          'run',
          '--config',
          File('${temporary.path}/custom.yaml').resolveSymbolicLinksSync(),
          '--output',
          absoluteOutput,
        ]);
        expect(absolute.exitCode, 0);
        expect(File('$absoluteOutput/report.json').existsSync(), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'partial, empty, corrupt and compilation failures never report success',
      () async {
        await prepareFakePackage(temporary.path);
        for (final mode in [
          'compile',
          'partial',
          'empty',
          'corrupt',
          'incomplete',
        ]) {
          final run = await cli(['run', '--fail-on', 'none'], mode: mode);
          expect(
            run.exitCode,
            1,
            reason: '$mode: ${run.stdout}\n${run.stderr}',
          );
          expect(readReport()['executionErrors'], isNotEmpty);
          final update = await cli(['update'], mode: mode);
          expect(update.exitCode, 1, reason: mode);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('invalid filters, shards, config and flow selections fail', () async {
      await prepareFakePackage(temporary.path);
      for (final args in [
        ['run', '--fail-on', 'arbb'],
        ['run', '--fail-on', 'none,arb'],
        ['run', '--shards', '0'],
        ['run', '--shards', '2', '--shard-index', '2'],
        ['run', '--shard-index', '0'],
        ['run', '--config', 'missing.yaml'],
        ['run', '--flows', 'missing'],
      ]) {
        expect((await cli(args)).exitCode, isNot(0), reason: '$args');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test(
      'empty successful shards are allowed but an empty merged run fails',
      () async {
        await prepareFakePackage(temporary.path);
        final shard = await cli([
          'run',
          '--shards',
          '4',
          '--shard-index',
          '3',
        ], mode: 'empty');
        expect(shard.exitCode, 0, reason: '${shard.stderr}');
        expect(readReport()['total'], 0);
        final merge = await cli([
          'merge',
          '-i',
          '.locale_sweep/reports',
          '-o',
          'merged',
          '--fail-on',
          'none',
        ]);
        expect(merge.exitCode, 1);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'monorepo applies flows, config, category filters and missing-package failures',
      () async {
        final a = '${temporary.path}/apps/a';
        final b = '${temporary.path}/apps/b';
        await prepareFakePackage(a);
        await prepareFakePackage(b);
        for (final dir in [a, b]) {
          File('$dir/custom.yaml').writeAsStringSync('locales: [de]\n');
        }
        final run = await cli([
          'run',
          '--packages',
          'apps/a,apps/b',
          '--flows',
          'current',
          '--config',
          'custom.yaml',
          '--fail-on',
          'none',
        ], mode: 'arb');
        expect(run.exitCode, 0, reason: '${run.stderr}');
        expect(readReport()['total'], 2);
        expect(readReport()['failed'], 2);
        for (final dir in [a, b]) {
          final invocation = jsonDecode(
            File('$dir/invocation.json').readAsStringSync(),
          );
          expect(
            invocation['config'],
            File('$dir/custom.yaml').resolveSymbolicLinksSync(),
          );
          expect(
            (invocation['args'] as List).where(
              (e) => e.toString().endsWith('_test.dart'),
            ),
            hasLength(1),
          );
        }
        expect(
          (await cli([
            'run',
            '--packages',
            'apps/a,missing',
            '--fail-on',
            'none',
          ])).exitCode,
          1,
        );
        expect(readReport()['executionErrors'], isNotEmpty);
        expect(Directory('${temporary.path}/missing').existsSync(), isFalse);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'merge preserves execution errors and fails for missing or corrupt inputs',
      () async {
        await prepareFakePackage(temporary.path);
        await cli(['run'], mode: 'partial');
        final merge = await cli([
          'merge',
          '-i',
          '.locale_sweep/reports',
          '-i',
          'missing',
          '-o',
          'merged',
          '--fail-on',
          'none',
        ]);
        expect(merge.exitCode, 1);
        final merged = jsonDecode(
          File('${temporary.path}/merged/report.json').readAsStringSync(),
        );
        expect(merged['total'], 1);
        expect(merged['executionErrors'], hasLength(2));
        File(
          '${temporary.path}/.locale_sweep/reports/report.json',
        ).writeAsStringSync('{');
        expect(
          (await cli(['merge', '-i', '.locale_sweep/reports'])).exitCode,
          1,
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }, skip: Platform.isWindows ? 'Process fixture uses a POSIX shell.' : false);

  group('real Flutter runner', () {
    Future<ProcessResult> runFlutter(
      String mode, {
      bool managed = false,
      String fixture = 'runner_probe.dart',
      Map<String, String> extraEnv = const {},
    }) async {
      final config = File('${temporary.path}/config.yaml');
      if (!config.existsSync()) {
        config.writeAsStringSync(
          'locales: [de]\ntext_scales: [1.0]\n'
          'screenshot_dir: ${temporary.path}/goldens\n',
        );
      }
      return Process.run(
        p.join(flutterRoot, 'bin/flutter'),
        [
          'test',
          '--no-pub',
          '--reporter',
          'expanded',
          '$project/test/fixtures/reliability/$fixture',
        ],
        workingDirectory: project,
        environment: {
          'LOCALE_SWEEP_CONFIG': config.path,
          'LOCALE_SWEEP_MANAGED_RUN': '$managed',
          'LOCALE_SWEEP_RESULTS_DIR': '${temporary.path}/results',
          'SWEEP_PROBE_MODE': mode,
          ...extraEnv,
        },
      );
    }

    ParsedReport? results() => loadResults(
      const SweepConfig(),
      resultsPath: '${temporary.path}/results',
    );

    test(
      'custom YAML, env overrides and explicit API overrides reach the matrix',
      () async {
        File('${temporary.path}/config.yaml').writeAsStringSync('''
locales: [de]
text_scales: [1.0, 2.0]
dark_mode: true
viewports:
  - {name: custom, width: 320, height: 640}
''');
        var run = await runFlutter(
          'clean',
          extraEnv: {
            'LOCALE_SWEEP_LOCALES': 'fr',
            'LOCALE_SWEEP_TEXT_SCALES': '1.25',
          },
        );
        expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
        expect(results()!.total, 2);
        for (final row in results()!.results) {
          expect(row.variant.locale, 'fr');
          expect(row.variant.textScale, 1.25);
          expect(row.variant.viewport.width, 320);
        }
        run = await runFlutter(
          'override',
          extraEnv: {'LOCALE_SWEEP_LOCALES': 'fr'},
        );
        expect(run.exitCode, 0, reason: '${run.stdout}');
        expect(results()!.total, 1);
        expect(results()!.results.single.variant.locale, 'ja');
        expect(results()!.results.single.variant.textScale, 1.5);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'ARB findings fail direct Flutter and are recorded before failure',
      () async {
        final arb = Directory('${temporary.path}/l10n')..createSync();
        File('${arb.path}/app_en.arb').writeAsStringSync('{"title":"Title"}');
        File('${arb.path}/app_de.arb').writeAsStringSync('{}');
        final run = await runFlutter(
          'clean',
          extraEnv: {'LOCALE_SWEEP_ARB_DIR': arb.path},
        );
        expect(run.exitCode, isNot(0));
        expect(results()!.failed, 1);
        expect(results()!.results.single.arbIssues.single.key, 'title');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'callback and setup/teardown failures remain failures in managed runs',
      () async {
        for (final mode in ['callback', 'setup', 'teardown']) {
          final run = await runFlutter(mode, managed: true);
          expect(run.exitCode, isNot(0), reason: '$mode: ${run.stdout}');
          if (mode == 'callback') {
            expect(
              results()!.results.single.failureKind,
              SweepFailureKind.test,
            );
            expect(
              results()!.results.single.errorMessage,
              contains('callback failed'),
            );
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'missing golden uses configured path, fails directly and is filterable in CLI mode',
      () async {
        var run = await runFlutter('golden');
        expect(run.exitCode, isNot(0));
        expect(results()!.results.single.failureKind, SweepFailureKind.golden);
        expect(
          results()!.results.single.screenshotPath,
          startsWith('${temporary.path}/goldens/'),
        );
        run = await runFlutter('golden', managed: true);
        expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
        expect(results()!.failed, greaterThan(0));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'existing broken ARB integration assertions run under managed collection',
      () async {
        for (final fixture in ['broken_arb.dart', 'broken_arb_dark.dart']) {
          final run = await runFlutter(
            'clean',
            managed: true,
            fixture: fixture,
          );
          expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
        }
        expect(
          results()!.results
              .where((r) => r.hasArbIssues)
              .every((r) => !r.passed),
          isTrue,
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'duplicate flow names are preserved in isolated result files',
      () async {
        final run = await runFlutter(
          'clean',
          managed: true,
          fixture: 'duplicate_flow.dart',
        );
        expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
        final report = results()!;
        expect(report.total, 2);
        expect(report.results.map((result) => result.flowName), [
          'same_flow',
          'same_flow',
        ]);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
