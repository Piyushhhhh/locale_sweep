import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  // ── mergeResults ──────────────────────────────────────────────────────────

  group('mergeResults', () {
    test('combines results from multiple shards', () {
      final shard1 = [
        const SweepResult(
          flowName: 'onboarding',
          variant: SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
        ),
        const SweepResult(
          flowName: 'onboarding',
          variant: SweepVariant(
            locale: 'de',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
        ),
      ];

      final shard2 = [
        const SweepResult(
          flowName: 'onboarding',
          variant: SweepVariant(
            locale: 'ar',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: false,
          overflows: [OverflowError(message: 'overflowed by 10px')],
        ),
        const SweepResult(
          flowName: 'settings',
          variant: SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
        ),
      ];

      final merged = mergeResults([...shard1, ...shard2]);

      expect(merged.total, 4);
      expect(merged.passed, 3);
      expect(merged.failed, 1);
      expect(merged.summary, contains('1/4 variants failed'));
    });

    test('generates all report formats from merged results', () {
      final results = [
        const SweepResult(
          flowName: 'checkout',
          variant: SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
        ),
      ];

      final report = mergeResults(results);
      expect(report.markdown, isNotEmpty);
      expect(report.html, contains('<!DOCTYPE html>'));
      final json = jsonDecode(report.json) as Map<String, dynamic>;
      expect(json['results'], isList);
    });

    test('handles empty results', () {
      final report = mergeResults([]);
      expect(report.total, 0);
      expect(report.summary, 'All 0 variants passed.');
    });

    test('preserves overflow and arb issue counts', () {
      final results = [
        const SweepResult(
          flowName: 'app',
          variant: SweepVariant(
            locale: 'de',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: false,
          overflows: [
            OverflowError(message: 'overflow 1'),
            OverflowError(message: 'overflow 2'),
          ],
          arbIssues: [
            ArbIssue(
              type: ArbIssueType.missingKey,
              locale: 'de',
              detail: 'missing: title',
            ),
          ],
        ),
        const SweepResult(
          flowName: 'app',
          variant: SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
        ),
      ];

      final report = mergeResults(results);
      expect(report.summary, contains('2 overflow(s)'));
      expect(report.summary, contains('1 ARB issue(s)'));
    });
  });

  // ── discoverPackages ──────────────────────────────────────────────────────

  group('discoverPackages', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('sweep_mono_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('finds packages with test/sweep directory', () {
      final pkg1 = Directory('${tmpDir.path}/apps/auth');
      pkg1.createSync(recursive: true);
      File('${pkg1.path}/pubspec.yaml').writeAsStringSync('name: auth');
      Directory('${pkg1.path}/test/sweep').createSync(recursive: true);

      final pkg2 = Directory('${tmpDir.path}/apps/dashboard');
      pkg2.createSync(recursive: true);
      File('${pkg2.path}/pubspec.yaml').writeAsStringSync('name: dashboard');
      Directory('${pkg2.path}/test/sweep').createSync(recursive: true);

      final noPkg = Directory('${tmpDir.path}/apps/api');
      noPkg.createSync(recursive: true);
      File('${noPkg.path}/pubspec.yaml').writeAsStringSync('name: api');

      final packages = discoverPackages(tmpDir.path);
      expect(packages, hasLength(2));
      expect(packages.any((p) => p.contains('auth')), isTrue);
      expect(packages.any((p) => p.contains('dashboard')), isTrue);
      expect(packages.any((p) => p.contains('api')), isFalse);
    });

    test('returns empty for nonexistent directory', () {
      final packages = discoverPackages('/nonexistent/path');
      expect(packages, isEmpty);
    });

    test('returns empty when no packages have sweep tests', () {
      final pkg = Directory('${tmpDir.path}/myapp');
      pkg.createSync(recursive: true);
      File('${pkg.path}/pubspec.yaml').writeAsStringSync('name: myapp');
      Directory('${pkg.path}/test').createSync(recursive: true);

      final packages = discoverPackages(tmpDir.path);
      expect(packages, isEmpty);
    });

    test('discovers from melos.yaml', () {
      File('${tmpDir.path}/melos.yaml').writeAsStringSync('''
name: my_workspace
packages:
  - apps/*
  - packages/*
''');

      final app = Directory('${tmpDir.path}/apps/mobile');
      app.createSync(recursive: true);
      File('${app.path}/pubspec.yaml').writeAsStringSync('name: mobile');
      Directory('${app.path}/test/sweep').createSync(recursive: true);

      final lib = Directory('${tmpDir.path}/packages/core');
      lib.createSync(recursive: true);
      File('${lib.path}/pubspec.yaml').writeAsStringSync('name: core');

      final packages = discoverPackages(tmpDir.path);
      expect(packages, hasLength(1));
      expect(packages.first, contains('mobile'));
    });

    test('respects custom test-dir', () {
      final pkg = Directory('${tmpDir.path}/myapp');
      pkg.createSync(recursive: true);
      File('${pkg.path}/pubspec.yaml').writeAsStringSync('name: myapp');
      Directory('${pkg.path}/test/locale').createSync(recursive: true);

      var packages = discoverPackages(tmpDir.path);
      expect(packages, isEmpty);

      packages = discoverPackages(tmpDir.path, testDir: 'test/locale');
      expect(packages, hasLength(1));
    });

    test('skips hidden directories and build folders', () {
      final hidden = Directory('${tmpDir.path}/.dart_tool/pkg');
      hidden.createSync(recursive: true);
      File('${hidden.path}/pubspec.yaml').writeAsStringSync('name: tool');
      Directory('${hidden.path}/test/sweep').createSync(recursive: true);

      final build = Directory('${tmpDir.path}/build/pkg');
      build.createSync(recursive: true);
      File('${build.path}/pubspec.yaml').writeAsStringSync('name: build');
      Directory('${build.path}/test/sweep').createSync(recursive: true);

      final packages = discoverPackages(tmpDir.path);
      expect(packages, isEmpty);
    });

    test('does not recurse into child packages', () {
      final parent = Directory('${tmpDir.path}/app');
      parent.createSync(recursive: true);
      File('${parent.path}/pubspec.yaml').writeAsStringSync('name: app');
      Directory('${parent.path}/test/sweep').createSync(recursive: true);

      final child = Directory('${parent.path}/packages/sub');
      child.createSync(recursive: true);
      File('${child.path}/pubspec.yaml').writeAsStringSync('name: sub');
      Directory('${child.path}/test/sweep').createSync(recursive: true);

      final packages = discoverPackages(tmpDir.path);
      expect(packages, hasLength(1));
      expect(packages.first, contains('app'));
    });
  });

  // ── Sharding CLI flags ────────────────────────────────────────────────────

  group('sharding parseVariantFromName', () {
    final cfg = SweepConfig.load('/dev/null');

    test('parsed variants from different shards merge correctly', () {
      final shard1Output = [
        '{"type":"testStart","test":{"id":1,"name":"sweep: login [EN · 393x852]"}}',
        '{"type":"testDone","testID":1,"result":"success","skipped":false}',
      ].join('\n');

      final shard2Output = [
        '{"type":"testStart","test":{"id":1,"name":"sweep: login [DE · 393x852]"}}',
        '{"type":"testDone","testID":1,"result":"success","skipped":false}',
      ].join('\n');

      final report1 = parseMachineOutput(shard1Output, cfg);
      final report2 = parseMachineOutput(shard2Output, cfg);

      final merged = mergeResults([...report1.results, ...report2.results]);
      expect(merged.total, 2);
      expect(merged.passed, 2);
      expect(merged.results.map((r) => r.variant.locale).toSet(), {'en', 'de'});
    });
  });
}
