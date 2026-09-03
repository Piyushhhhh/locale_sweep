import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

Widget _testWidget() {
  return Builder(
    builder: (context) {
      final brightness = Theme.of(context).brightness;
      final mq = MediaQuery.of(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            brightness == Brightness.dark ? 'DARK' : 'LIGHT',
            textDirection: TextDirection.ltr,
          ),
          Text(
            'Scale: ${mq.textScaler.scale(1.0).toStringAsFixed(1)}',
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(width: 200, height: 100),
        ],
      );
    },
  );
}

void main() {
  // ── Feature 1: darkMode + Theme wrapping + skip callback ────────────
  group('Full integration: darkMode + skip + variantBody', () {
    clearSweepResults();

    final seenVariants = <SweepVariant>[];

    sweepTest(
      'integration_dark_skip',
      builder: _testWidget,
      locales: ['en', 'de', 'ar'],
      textScales: [1.0, 2.0],
      viewports: [ViewportPreset.phone],
      darkMode: true,
      lightTheme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      captureScreenshots: false,
      skip: (v) => v.locale == 'ar' && v.textScale == 2.0,
      variantBody: (tester, variant) async {
        seenVariants.add(variant);

        final expectedBrightness = variant.isDark ? 'DARK' : 'LIGHT';
        expect(find.text(expectedBrightness), findsOneWidget);

        final mq = MediaQuery.of(tester.element(find.byType(Column)));
        expect(mq.platformBrightness, variant.brightness);
        expect(mq.textScaler.scale(1.0), variant.textScale);

        final theme = Theme.of(tester.element(find.byType(Column)));
        expect(theme.brightness, variant.brightness);
      },
    );

    tearDownAll(() {
      final results = sweepResults
          .where((r) => r.flowName == 'integration_dark_skip')
          .toList();

      // 3 locales × 2 scales × 2 brightness = 12
      // minus 2 skipped (ar + 2.0x → light and dark)
      expect(results, hasLength(10));

      // Verify no ar + 2.0x variants made it through
      final arScaled = results.where(
        (r) => r.variant.locale == 'ar' && r.variant.textScale == 2.0,
      );
      expect(arScaled, isEmpty);

      // Verify dark variants exist and have correct brightness
      final darkResults = results.where((r) => r.variant.isDark).toList();
      expect(darkResults, hasLength(5)); // 5 non-skipped dark
      for (final r in darkResults) {
        expect(r.variant.brightness, Brightness.dark);
        expect(r.variant.displayLabel, contains('Dark'));
      }

      // Verify light variants exist
      final lightResults = results.where((r) => !r.variant.isDark).toList();
      expect(lightResults, hasLength(5));
      for (final r in lightResults) {
        expect(r.variant.displayLabel, isNot(contains('Dark')));
      }

      // All should pass (no overflows in this widget)
      expect(results.every((r) => r.passed), isTrue);

      // Verify variantBody was called for each non-skipped variant
      expect(seenVariants, hasLength(10));
    });
  });

  // ── Feature 2: SweepConfig from YAML with dark_mode ─────────────────
  group('Full integration: SweepConfig.load with dark_mode', () {
    late Directory tmpDir;
    late SweepConfig cfg;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('sweep_full_');
      final cfgFile = File('${tmpDir.path}/locale_sweep.yaml');
      cfgFile.writeAsStringSync('''
locales:
  - en
  - ja
text_scales:
  - 1.0
viewports:
  - name: "phone"
    width: 393
    height: 852
dark_mode: true
screenshot_dir: custom_screenshots
report_dir: custom_reports
arb_dir: test/fixtures/broken_localized_app/l10n
''');
      cfg = SweepConfig.load(cfgFile.path);
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('parses all fields including dark_mode', () {
      expect(cfg.locales, ['en', 'ja']);
      expect(cfg.textScales, [1.0]);
      expect(cfg.darkMode, isTrue);
      expect(cfg.screenshotDir, 'custom_screenshots');
      expect(cfg.reportDir, 'custom_reports');
      expect(cfg.arbDir, 'test/fixtures/broken_localized_app/l10n');
    });
  });

  // ── Feature 3: Report generation (Markdown + JSON + HTML) ───────────
  group('Full integration: reports with all features', () {
    test('generates all report formats from mixed results', () {
      final results = [
        const SweepResult(
          flowName: 'login',
          variant: SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
          screenshotPath: '.locale_sweep/screenshots/login_en_393x852.png',
        ),
        const SweepResult(
          flowName: 'login',
          variant: SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
            brightness: Brightness.dark,
          ),
          passed: true,
          screenshotPath: '.locale_sweep/screenshots/login_en_dark_393x852.png',
        ),
        const SweepResult(
          flowName: 'login',
          variant: SweepVariant(
            locale: 'ar',
            textScale: 2.0,
            viewport: ViewportPreset.tablet,
          ),
          passed: false,
          overflows: [
            OverflowError(
              message: 'A RenderFlex overflowed by 56 pixels on the right.',
              pixels: 56,
            ),
          ],
          screenshotPath:
              '.locale_sweep/screenshots/login_ar_2.0x_768x1024.png',
          errorMessage: 'Overflow in login AR layout',
        ),
        const SweepResult(
          flowName: 'settings',
          variant: SweepVariant(
            locale: 'de',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
          arbIssues: [
            ArbIssue(
              type: ArbIssueType.missingKey,
              locale: 'de',
              key: 'settingsSubtitle',
              detail: 'Key "settingsSubtitle" missing in de',
            ),
          ],
        ),
        const SweepResult(
          flowName: 'settings',
          variant: SweepVariant(
            locale: 'de',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
            brightness: Brightness.dark,
          ),
          passed: true,
        ),
      ];

      final summary = SweepRunSummary(results: results);

      // ── Markdown with screenshotLinkBuilder ──
      final md = ReportGenerator.generateMarkdown(
        summary,
        screenshotLinkBuilder: (path) {
          final filename = path.split('/').last;
          return '[View]($filename)';
        },
      );

      // settings/de has ARB issues → hasIssues=true → counts as failed
      expect(md, contains('2/5 variants failed'));
      expect(md, contains('## Failures'));
      expect(md, contains('### login'));
      expect(md, contains('### settings'));
      expect(md, contains('| ar |'));
      expect(md, contains('Overflow (56px)'));
      expect(md, contains('[View](login_ar_2.0x_768x1024.png)'));
      expect(md, isNot(contains('![')));
      expect(md, contains('## Locale Summary'));
      expect(md, contains('| en | 2 | 0 | 0 | 0 |'));
      expect(md, contains('missingKey'));

      // ── JSON ──
      final jsonStr = ReportGenerator.generateJson(summary);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(data['total'], 5);
      expect(data['passed'], 3); // en light, en dark, settings dark (no issues)
      expect(data['failed'], 2); // ar overflow + de ARB issues
      expect(data['overflows'], 1);
      expect(data['arbIssues'], 1);

      final jsonResults = data['results'] as List;
      final darkResult = jsonResults.firstWhere(
        (r) => r['brightness'] == 'dark' && r['flow'] == 'login',
      );
      expect(darkResult['locale'], 'en');

      final failedResult = jsonResults.firstWhere((r) => r['passed'] == false);
      expect(failedResult['rtl'], isTrue);
      expect((failedResult['overflows'] as List).first['pixels'], 56);

      // ── HTML ──
      final html = ReportGenerator.generateHtml(summary);

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<title>LocaleSweep Report</title>'));
      expect(html, contains('<style>'));
      expect(html, contains('<script>'));

      // Summary cards
      expect(html, contains('summary-pass'));
      expect(html, contains('summary-fail'));
      expect(html, contains('>5<')); // total
      expect(html, contains('>3<')); // passed
      expect(html, contains('>2<')); // failed

      // Flow sections
      expect(html, contains('data-flow="login"'));
      expect(html, contains('data-flow="settings"'));

      // Dark mode badges
      expect(html, contains('badge-dark'));
      expect(html, contains('DARK'));
      expect(html, contains('data-brightness="dark"'));

      // RTL badges
      expect(html, contains('badge-rtl'));
      expect(html, contains('RTL'));

      // Locale filters
      expect(html, contains('data-filter="locale" data-value="ar"'));
      expect(html, contains('data-filter="locale" data-value="de"'));
      expect(html, contains('data-filter="locale" data-value="en"'));

      // Status filters
      expect(html, contains('data-filter="status" data-value="fail"'));
      expect(html, contains('data-filter="status" data-value="pass"'));

      // Screenshot images
      expect(html, contains('<img src='));
      expect(html, contains('login_en_393x852.png'));
      expect(html, contains('login_en_dark_393x852.png'));

      // Overflow details
      expect(html, contains('Overflow (56px)'));

      // Locale summary table
      expect(html, contains('<table>'));
      expect(html, contains('row-fail'));

      // No XSS from error message
      expect(html, isNot(contains('<script>alert')));
    });
  });

  // ── Feature 4: Brightness serialization round-trip ──────────────────
  group('Full integration: brightness serialization', () {
    test('round-trips through toJson/fromJson', () {
      const original = SweepResult(
        flowName: 'checkout',
        variant: SweepVariant(
          locale: 'ar',
          textScale: 2.0,
          viewport: ViewportPreset.tablet,
          brightness: Brightness.dark,
        ),
        passed: false,
        overflows: [
          OverflowError(message: 'overflowed by 20 pixels', pixels: 20),
        ],
        arbIssues: [
          ArbIssue(
            type: ArbIssueType.untranslated,
            locale: 'ar',
            key: 'welcome',
            detail: 'Value identical to en base',
          ),
        ],
        screenshotPath: '.locale_sweep/screenshots/checkout_ar.png',
        errorMessage: 'test error',
      );

      final json = original.toJson();
      final restored = SweepResult.fromJson(json);

      expect(restored.flowName, 'checkout');
      expect(restored.variant.locale, 'ar');
      expect(restored.variant.textScale, 2.0);
      expect(restored.variant.brightness, Brightness.dark);
      expect(restored.variant.isDark, isTrue);
      expect(restored.variant.isRtl, isTrue);
      expect(restored.passed, isFalse);
      expect(restored.overflows, hasLength(1));
      expect(restored.overflows.first.pixels, 20);
      expect(restored.arbIssues, hasLength(1));
      expect(restored.arbIssues.first.type, ArbIssueType.untranslated);
      expect(restored.screenshotPath, contains('checkout_ar.png'));
    });

    test('light brightness round-trips correctly', () {
      const original = SweepResult(
        flowName: 'test',
        variant: SweepVariant(
          locale: 'en',
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        ),
        passed: true,
      );

      final json = original.toJson();
      expect(json['brightness'], 'light');

      final restored = SweepResult.fromJson(json);
      expect(restored.variant.brightness, Brightness.light);
      expect(restored.variant.isDark, isFalse);
    });
  });

  // ── Feature 5: File-based result sink ───────────────────────────────
  group('Full integration: file-based result sink', () {
    clearSweepResults();

    sweepTest(
      'sink_test',
      builder: () => const SizedBox(width: 100, height: 100),
      locales: ['en', 'de'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      darkMode: true,
      captureScreenshots: false,
    );

    tearDownAll(() {
      final file = File('$sweepResultsDir/sink_test.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Result JSON should be written',
      );

      final list = jsonDecode(file.readAsStringSync()) as List;
      expect(list, hasLength(4)); // 2 locales × 2 brightness

      final locales = list.map((e) => e['locale']).toSet();
      expect(locales, {'en', 'de'});

      final brightnesses = list.map((e) => e['brightness']).toSet();
      expect(brightnesses, {'light', 'dark'});

      for (final item in list) {
        expect(item['flow'], 'sink_test');
        expect(item['passed'], isTrue);
      }
    });
  });

  // ── Feature 6: ARB analysis integration with sweep ──────────────────
  group('Full integration: ARB analysis with dark mode', () {
    clearSweepResults();

    sweepTest(
      'arb_dark_flow',
      builder: () => const SizedBox(width: 100, height: 100),
      locales: ['en', 'de'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      darkMode: true,
      arbDir: 'test/fixtures/broken_localized_app/l10n',
      captureScreenshots: false,
    );

    tearDownAll(() {
      final results = sweepResults
          .where((r) => r.flowName == 'arb_dark_flow')
          .toList();

      // 2 locales × 1 scale × 1 viewport × 2 brightness = 4
      expect(results, hasLength(4));

      // Both dark and light de variants should have the same ARB issues
      final deResults = results.where((r) => r.variant.locale == 'de').toList();
      expect(deResults, hasLength(2));
      for (final r in deResults) {
        expect(r.arbIssues, isNotEmpty, reason: 'de should have ARB issues');
        expect(
          r.arbIssues.any((i) => i.type == ArbIssueType.missingKey),
          isTrue,
        );
      }

      // en (base locale) should have no ARB issues in both variants
      final enResults = results.where((r) => r.variant.locale == 'en').toList();
      expect(enResults, hasLength(2));
      for (final r in enResults) {
        expect(r.arbIssues, isEmpty);
      }
    });
  });
}
