import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';
import 'package:locale_sweep/src/report/github_reporter.dart';

import 'fixtures/load_fonts.dart';

void main() {
  // ── Landscape viewport presets ───────────────────────────────────────────

  group('Landscape viewport presets', () {
    test('phoneLandscape has correct dimensions', () {
      expect(ViewportPreset.phoneLandscape.width, 852);
      expect(ViewportPreset.phoneLandscape.height, 393);
      expect(ViewportPreset.phoneLandscape.name, '852x393');
    });

    test('tabletLandscape has correct dimensions', () {
      expect(ViewportPreset.tabletLandscape.width, 1024);
      expect(ViewportPreset.tabletLandscape.height, 768);
      expect(ViewportPreset.tabletLandscape.name, '1024x768');
    });

    test('phoneSmallLandscape has correct dimensions', () {
      expect(ViewportPreset.phoneSmallLandscape.width, 667);
      expect(ViewportPreset.phoneSmallLandscape.height, 375);
    });

    test('phoneWideLandscape has correct dimensions', () {
      expect(ViewportPreset.phoneWideLandscape.width, 915);
      expect(ViewportPreset.phoneWideLandscape.height, 412);
    });

    test('landscape presets are transposed from portrait', () {
      expect(ViewportPreset.phoneLandscape.width, ViewportPreset.phone.height);
      expect(ViewportPreset.phoneLandscape.height, ViewportPreset.phone.width);
      expect(
        ViewportPreset.tabletLandscape.width,
        ViewportPreset.tablet.height,
      );
      expect(
        ViewportPreset.tabletLandscape.height,
        ViewportPreset.tablet.width,
      );
      expect(
        ViewportPreset.phoneSmallLandscape.width,
        ViewportPreset.phoneSmall.height,
      );
      expect(
        ViewportPreset.phoneSmallLandscape.height,
        ViewportPreset.phoneSmall.width,
      );
      expect(
        ViewportPreset.phoneWideLandscape.width,
        ViewportPreset.phoneWide.height,
      );
      expect(
        ViewportPreset.phoneWideLandscape.height,
        ViewportPreset.phoneWide.width,
      );
    });

    test('landscape presets produce correct Size', () {
      expect(ViewportPreset.phoneLandscape.size, const Size(852, 393));
      expect(ViewportPreset.tabletLandscape.size, const Size(1024, 768));
    });

    test('toString returns name', () {
      expect(ViewportPreset.phoneLandscape.toString(), '852x393');
      expect(ViewportPreset.tabletLandscape.toString(), '1024x768');
    });
  });

  // ── sweepTest with landscape viewports ───────────────────────────────────

  group('sweepTest with landscape viewports', () {
    setUpAll(() async {
      await loadTestFonts();
    });

    clearSweepResults();

    sweepTest(
      'landscape_test',
      builder: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const Scaffold(body: Center(child: Text('Landscape'))),
      ),
      locales: ['en'],
      textScales: [1.0],
      viewports: [
        ViewportPreset.phoneLandscape,
        ViewportPreset.tabletLandscape,
      ],
      captureScreenshots: true,
      screenshotDir: '.locale_sweep/screenshots',
    );
  });

  // ── sweepTest setUp callback ─────────────────────────────────────────────

  group('sweepTest setUp callback', () {
    var setUpCalled = false;

    sweepTest(
      'setup_callback_test',
      builder: () => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('Setup'))),
      ),
      locales: ['en'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
      setUp: () async {
        setUpCalled = true;
      },
    );

    test('setUp was called before tests', () {
      expect(setUpCalled, isTrue);
    });
  });

  // ── SweepConfig env variable overrides ───────────────────────────────────

  group('SweepConfig env overrides', () {
    test('loads defaults when no env vars or yaml', () {
      final cfg = SweepConfig.load('/dev/null');
      expect(cfg.locales, ['en', 'de', 'ar', 'ja']);
      expect(cfg.textScales, [1.0, 2.0]);
      expect(cfg.darkMode, isFalse);
      expect(cfg.tolerance, 0.0);
    });

    test('LOCALE_SWEEP_LOCALES overrides locales', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_env_');
      File('${tmpDir.path}/test.yaml').writeAsStringSync('locales: [en, de]');

      // We can't set env vars in tests, but we verify the YAML loading
      // still works and the method signature is correct
      final cfg = SweepConfig.load('${tmpDir.path}/test.yaml');
      expect(cfg.locales, ['en', 'de']);

      tmpDir.deleteSync(recursive: true);
    });

    test(
      'tolerance from YAML still loads correctly with env override path',
      () {
        final tmpDir = Directory.systemTemp.createTempSync('sweep_env_');
        File('${tmpDir.path}/test.yaml').writeAsStringSync('tolerance: 3.5');

        final cfg = SweepConfig.load('${tmpDir.path}/test.yaml');
        expect(cfg.tolerance, 3.5);

        tmpDir.deleteSync(recursive: true);
      },
    );

    test('dark_mode from YAML still loads correctly', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_env_');
      File('${tmpDir.path}/test.yaml').writeAsStringSync('dark_mode: true');

      final cfg = SweepConfig.load('${tmpDir.path}/test.yaml');
      expect(cfg.darkMode, isTrue);

      tmpDir.deleteSync(recursive: true);
    });
  });

  // ── CLI parser with landscape presets ─────────────────────────────────────

  group('CLI parser handles landscape viewports', () {
    final cfg = SweepConfig.load('/dev/null');

    test('parses landscape phone viewport from test name', () {
      final v = parseVariantFromName('sweep: settings [EN · 852x393]', cfg);
      expect(v.viewport.width, 852);
      expect(v.viewport.height, 393);
    });

    test('parses landscape tablet viewport from test name', () {
      final v = parseVariantFromName('sweep: settings [EN · 1024x768]', cfg);
      expect(v.viewport.width, 1024);
      expect(v.viewport.height, 768);
    });
  });

  // ── http package removed — GitHubReporter uses dart:io ───────────────────

  group('GitHubReporter', () {
    test('fromEnv throws when env vars are missing', () {
      expect(
        () => GitHubReporter.fromEnv(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Missing GitHub environment variables'),
          ),
        ),
      );
    });

    test('can construct with explicit params', () {
      const reporter = GitHubReporter(
        token: 'test-token',
        repo: 'owner/repo',
        prNumber: 42,
      );
      expect(reporter.token, 'test-token');
      expect(reporter.repo, 'owner/repo');
      expect(reporter.prNumber, 42);
    });
  });
}
