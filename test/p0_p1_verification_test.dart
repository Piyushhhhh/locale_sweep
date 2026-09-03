import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  group('P0: RTL locale expansion', () {
    test('all 10 RTL locales are detected', () {
      final rtlCodes = [
        'ar',
        'he',
        'fa',
        'ur',
        'ku',
        'ps',
        'yi',
        'dv',
        'sd',
        'ug',
      ];
      for (final code in rtlCodes) {
        final v = SweepVariant(
          locale: code,
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        );
        expect(v.isRtl, isTrue, reason: '$code should be RTL');
        expect(v.textDirection, TextDirection.rtl);
        expect(v.displayLabel, contains('RTL'));
      }
    });

    test('subtag locales are detected (ar_EG, fa_IR)', () {
      for (final code in ['ar_EG', 'fa_IR', 'ur_PK', 'he_IL']) {
        final v = SweepVariant(
          locale: code,
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        );
        expect(v.isRtl, isTrue, reason: '$code should be RTL via subtag');
      }
    });

    test('LTR locales are not marked RTL', () {
      for (final code in ['en', 'de', 'ja', 'zh', 'fr', 'es']) {
        final v = SweepVariant(
          locale: code,
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        );
        expect(v.isRtl, isFalse, reason: '$code should be LTR');
        expect(v.displayLabel, isNot(contains('RTL')));
      }
    });
  });

  group('P0: CLI config file', () {
    test('SweepConfig.load reads yaml file', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cfg_');
      final cfgFile = File('${tmpDir.path}/locale_sweep.yaml');
      cfgFile.writeAsStringSync('''
locales:
  - en
  - ar
  - ja
text_scales:
  - 1.0
  - 1.5
report_dir: custom_reports
''');

      final cfg = SweepConfig.load(cfgFile.path);
      expect(cfg.locales, ['en', 'ar', 'ja']);
      expect(cfg.textScales, [1.0, 1.5]);
      expect(cfg.reportDir, 'custom_reports');

      tmpDir.deleteSync(recursive: true);
    });

    test('SweepConfig.load returns defaults when file missing', () {
      final cfg = SweepConfig.load('/nonexistent/locale_sweep.yaml');
      expect(cfg.locales, isNotEmpty);
      expect(cfg.textScales, isNotEmpty);
    });

    test('SweepConfig.load still parses valid keys alongside unknown ones', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cfg_');
      final cfgFile = File('${tmpDir.path}/locale_sweep.yaml');
      cfgFile.writeAsStringSync('''
locale: [en, de]
text_scale: [1.0]
locales: [en, ar]
''');

      final cfg = SweepConfig.load(cfgFile.path);
      expect(cfg.locales, ['en', 'ar']);

      tmpDir.deleteSync(recursive: true);
    });

    test('SweepConfig.load handles empty file', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cfg_');
      final cfgFile = File('${tmpDir.path}/locale_sweep.yaml');
      cfgFile.writeAsStringSync('');

      final cfg = SweepConfig.load(cfgFile.path);
      expect(cfg.locales, ['en', 'de', 'ar', 'ja']);

      tmpDir.deleteSync(recursive: true);
    });

    test('SweepConfig.load handles invalid YAML', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cfg_');
      final cfgFile = File('${tmpDir.path}/locale_sweep.yaml');
      cfgFile.writeAsStringSync(': : : not valid yaml [[[');

      final cfg = SweepConfig.load(cfgFile.path);
      expect(cfg.locales, ['en', 'de', 'ar', 'ja']);

      tmpDir.deleteSync(recursive: true);
    });

    test('SweepConfig.load handles wrong types gracefully', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cfg_');
      final cfgFile = File('${tmpDir.path}/locale_sweep.yaml');
      cfgFile.writeAsStringSync('''
locales: "just a string, not a list"
text_scales: 42
report_dir:
  - should
  - be
  - string
''');

      final cfg = SweepConfig.load(cfgFile.path);
      expect(cfg.locales, ['en', 'de', 'ar', 'ja']);
      expect(cfg.textScales, [1.0, 2.0]);
      expect(cfg.reportDir, '.locale_sweep/reports');

      tmpDir.deleteSync(recursive: true);
    });
  });

  final receivedVariants = <SweepVariant>[];

  sweepTest(
    'variant_body_test',
    builder: () => const SizedBox(width: 100, height: 100),
    locales: ['en', 'ar'],
    textScales: [1.0],
    viewports: [ViewportPreset.phone],
    captureScreenshots: false,
    variantBody: (tester, variant) async {
      receivedVariants.add(variant);
    },
  );

  test('P1: variantBody callback delivered correct variants', () {
    expect(receivedVariants, hasLength(2));
    expect(receivedVariants[0].locale, 'en');
    expect(receivedVariants[0].isRtl, isFalse);
    expect(receivedVariants[1].locale, 'ar');
    expect(receivedVariants[1].isRtl, isTrue);
  });

  group('P1: untranslated string detection', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('sweep_arb_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('detects identical strings as untranslated', () {
      File('${tmpDir.path}/app_en.arb').writeAsStringSync(
        jsonEncode({
          '@@locale': 'en',
          'hello': 'Hello',
          'goodbye': 'Goodbye',
          'ok': 'OK',
        }),
      );
      File('${tmpDir.path}/app_de.arb').writeAsStringSync(
        jsonEncode({
          '@@locale': 'de',
          'hello': 'Hallo',
          'goodbye': 'Goodbye', // not translated!
          'ok': 'OK', // same but intentional short word
        }),
      );

      final report = ArbAnalyzer.analyze(
        arbDir: tmpDir.path,
        locales: ['en', 'de'],
        baseLocale: 'en',
      );

      final untranslated = report.issues
          .where((i) => i.type == ArbIssueType.untranslated)
          .toList();

      expect(untranslated, hasLength(2));
      expect(untranslated.map((i) => i.key), containsAll(['goodbye', 'ok']));
      expect(untranslated.first.locale, 'de');
      expect(untranslated.first.detail, contains('identical'));
    });

    test('does not flag properly translated strings', () {
      File('${tmpDir.path}/app_en.arb').writeAsStringSync(
        jsonEncode({'@@locale': 'en', 'hello': 'Hello', 'goodbye': 'Goodbye'}),
      );
      File('${tmpDir.path}/app_de.arb').writeAsStringSync(
        jsonEncode({'@@locale': 'de', 'hello': 'Hallo', 'goodbye': 'Tschüss'}),
      );

      final report = ArbAnalyzer.analyze(
        arbDir: tmpDir.path,
        locales: ['en', 'de'],
        baseLocale: 'en',
      );

      final untranslated = report.issues
          .where((i) => i.type == ArbIssueType.untranslated)
          .toList();
      expect(untranslated, isEmpty);
    });

    test('does not flag missing keys as untranslated', () {
      File('${tmpDir.path}/app_en.arb').writeAsStringSync(
        jsonEncode({'@@locale': 'en', 'hello': 'Hello', 'goodbye': 'Goodbye'}),
      );
      File(
        '${tmpDir.path}/app_de.arb',
      ).writeAsStringSync(jsonEncode({'@@locale': 'de', 'hello': 'Hallo'}));

      final report = ArbAnalyzer.analyze(
        arbDir: tmpDir.path,
        locales: ['en', 'de'],
        baseLocale: 'en',
      );

      final untranslated = report.issues
          .where((i) => i.type == ArbIssueType.untranslated)
          .toList();
      expect(untranslated, isEmpty);

      final missing = report.issues
          .where((i) => i.type == ArbIssueType.missingKey)
          .toList();
      expect(missing, hasLength(1));
      expect(missing.first.key, 'goodbye');
    });
  });
}
