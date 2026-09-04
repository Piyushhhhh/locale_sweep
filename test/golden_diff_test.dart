import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  group('DiffResult', () {
    test('toJson round-trips through fromJson', () {
      const original = DiffResult(
        diffPercent: 12.3456,
        changedPixels: 1000,
        totalPixels: 50000,
        diffImagePath: '.locale_sweep/diffs/test_diff.png',
      );

      final json = original.toJson();
      final restored = DiffResult.fromJson(json);

      expect(restored.diffPercent, closeTo(12.3456, 0.001));
      expect(restored.changedPixels, 1000);
      expect(restored.totalPixels, 50000);
      expect(restored.diffImagePath, '.locale_sweep/diffs/test_diff.png');
    });

    test('toJson omits diffImagePath when null', () {
      const result = DiffResult(
        diffPercent: 0.0,
        changedPixels: 0,
        totalPixels: 100,
      );

      final json = result.toJson();
      expect(json.containsKey('diffImagePath'), isFalse);
    });

    test('fromJson handles missing optional fields', () {
      final result = DiffResult.fromJson({'diffPercent': 5.0});
      expect(result.changedPixels, 0);
      expect(result.totalPixels, 0);
      expect(result.diffImagePath, isNull);
    });

    test('withDiffImagePath preserves other fields', () {
      const original = DiffResult(
        diffPercent: 7.5,
        changedPixels: 500,
        totalPixels: 10000,
      );

      final withPath = original.withDiffImagePath('/tmp/diff.png');
      expect(withPath.diffPercent, 7.5);
      expect(withPath.changedPixels, 500);
      expect(withPath.totalPixels, 10000);
      expect(withPath.diffImagePath, '/tmp/diff.png');
    });
  });

  group('SweepResult with diff', () {
    test('toJson includes diff when present', () {
      const result = SweepResult(
        flowName: 'checkout',
        variant: SweepVariant(
          locale: 'en',
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        ),
        passed: true,
        diff: DiffResult(
          diffPercent: 0.5,
          changedPixels: 10,
          totalPixels: 2000,
        ),
      );

      final json = result.toJson();
      expect(json.containsKey('diff'), isTrue);
      expect((json['diff'] as Map)['diffPercent'], closeTo(0.5, 0.001));
    });

    test('toJson omits diff when null', () {
      const result = SweepResult(
        flowName: 'onboarding',
        variant: SweepVariant(
          locale: 'en',
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        ),
        passed: true,
      );

      expect(result.toJson().containsKey('diff'), isFalse);
    });

    test('fromJson restores diff field', () {
      const result = SweepResult(
        flowName: 'settings',
        variant: SweepVariant(
          locale: 'de',
          textScale: 2.0,
          viewport: ViewportPreset.phone,
        ),
        passed: false,
        diff: DiffResult(
          diffPercent: 15.0,
          changedPixels: 3000,
          totalPixels: 20000,
          diffImagePath: 'diffs/settings_diff.png',
        ),
      );

      final json = result.toJson();
      final jsonStr = jsonEncode(json);
      final restored = SweepResult.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );

      expect(restored.diff, isNotNull);
      expect(restored.diff!.diffPercent, 15.0);
      expect(restored.diff!.changedPixels, 3000);
      expect(restored.diff!.diffImagePath, 'diffs/settings_diff.png');
    });
  });

  group('SweepConfig tolerance', () {
    test('defaults to 0.0', () {
      const config = SweepConfig();
      expect(config.tolerance, 0.0);
    });

    test('loads from YAML', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cfg_');
      final configFile = File('${tmpDir.path}/locale_sweep.yaml');
      configFile.writeAsStringSync('''
locales:
  - en
tolerance: 0.5
''');

      final config = SweepConfig.load(configFile.path);
      expect(config.tolerance, 0.5);

      tmpDir.deleteSync(recursive: true);
    });

    test('falls back to 0.0 when missing from YAML', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cfg_');
      final configFile = File('${tmpDir.path}/locale_sweep.yaml');
      configFile.writeAsStringSync('''
locales:
  - en
''');

      final config = SweepConfig.load(configFile.path);
      expect(config.tolerance, 0.0);

      tmpDir.deleteSync(recursive: true);
    });
  });

  group('SweepGoldenComparator', () {
    test('delegates update to original comparator', () async {
      final delegate = _FakeComparator();
      final comparator = SweepGoldenComparator(
        delegate: delegate,
        tolerance: 5.0,
      );

      final bytes = _minimalPng();
      await comparator.update(Uri.parse('test.png'), bytes);
      expect(delegate.updatedUri, Uri.parse('test.png'));
    });

    test('getTestUri delegates to original', () {
      final delegate = _FakeComparator();
      final comparator = SweepGoldenComparator(
        delegate: delegate,
        tolerance: 1.0,
      );

      final uri = comparator.getTestUri(Uri.parse('foo.png'), 1);
      expect(uri, delegate.getTestUri(Uri.parse('foo.png'), 1));
    });

    test('returns delegate result when golden file does not exist', () async {
      final delegate = _FakeComparator(compareResult: true);
      final comparator = SweepGoldenComparator(
        delegate: delegate,
        tolerance: 5.0,
      );

      final result = await comparator.compare(
        _minimalPng(),
        Uri.parse('nonexistent.png'),
      );

      expect(result, isTrue);
      expect(comparator.lastDiffResult, isNull);
    });
  });

  group('Report with diff data', () {
    test('markdown failure table includes Diff % column', () {
      final summary = SweepRunSummary(
        results: [
          const SweepResult(
            flowName: 'login',
            variant: SweepVariant(
              locale: 'de',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: false,
            errorMessage: 'Golden mismatch',
            diff: DiffResult(
              diffPercent: 3.45,
              changedPixels: 1380,
              totalPixels: 40000,
            ),
          ),
        ],
      );

      final md = ReportGenerator.generateMarkdown(summary);
      expect(md, contains('| Diff % |'));
      expect(md, contains('3.45%'));
    });

    test('markdown failure table has empty diff cell when no diff', () {
      final summary = SweepRunSummary(
        results: [
          const SweepResult(
            flowName: 'login',
            variant: SweepVariant(
              locale: 'de',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: false,
            overflows: [OverflowError(message: 'overflowed', pixels: 10)],
          ),
        ],
      );

      final md = ReportGenerator.generateMarkdown(summary);
      expect(md, contains('| Diff % |'));
      // The diff cell should be empty (two consecutive pipes with spaces)
      expect(md, contains('|  |'));
    });

    test('HTML report shows diff badge when diff > 0', () {
      final summary = SweepRunSummary(
        results: [
          const SweepResult(
            flowName: 'login',
            variant: SweepVariant(
              locale: 'en',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: true,
            diff: DiffResult(
              diffPercent: 0.12,
              changedPixels: 48,
              totalPixels: 40000,
            ),
          ),
        ],
      );

      final html = ReportGenerator.generateHtml(summary);
      expect(html, contains('badge-diff'));
      expect(html, contains('0.12% diff'));
    });

    test('HTML report shows diff image link', () {
      final summary = SweepRunSummary(
        results: [
          const SweepResult(
            flowName: 'login',
            variant: SweepVariant(
              locale: 'en',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: false,
            errorMessage: 'mismatch',
            diff: DiffResult(
              diffPercent: 5.0,
              changedPixels: 2000,
              totalPixels: 40000,
              diffImagePath: '.locale_sweep/diffs/login_diff.png',
            ),
          ),
        ],
      );

      final html = ReportGenerator.generateHtml(summary);
      expect(html, contains('View diff image'));
      expect(html, contains('login_diff.png'));
    });

    test('HTML report omits diff badge element when diffPercent is 0', () {
      final summary = SweepRunSummary(
        results: [
          const SweepResult(
            flowName: 'login',
            variant: SweepVariant(
              locale: 'en',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: true,
            diff: DiffResult(
              diffPercent: 0.0,
              changedPixels: 0,
              totalPixels: 40000,
            ),
          ),
        ],
      );

      final html = ReportGenerator.generateHtml(summary);
      expect(html, isNot(contains('0.00% diff')));
    });

    test('JSON report includes diff in results', () {
      final summary = SweepRunSummary(
        results: [
          const SweepResult(
            flowName: 'login',
            variant: SweepVariant(
              locale: 'en',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: true,
            diff: DiffResult(
              diffPercent: 2.5,
              changedPixels: 1000,
              totalPixels: 40000,
            ),
          ),
        ],
      );

      final jsonStr = ReportGenerator.generateJson(summary);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = (data['results'] as List).first as Map<String, dynamic>;
      expect(result.containsKey('diff'), isTrue);
      expect((result['diff'] as Map)['diffPercent'], closeTo(2.5, 0.001));
    });
  });
}

class _FakeComparator implements GoldenFileComparator {
  bool? compareResult;
  Uri? updatedUri;

  _FakeComparator({this.compareResult});

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    return compareResult ?? false;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    updatedUri = golden;
  }

  @override
  Uri getTestUri(Uri key, int? version) {
    return Uri.parse('/tmp/goldens/${key.pathSegments.last}');
  }
}

/// Returns minimal valid PNG bytes (1x1 red pixel).
Uint8List _minimalPng() {
  // A valid 1x1 red PNG
  const base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg==';
  return Uint8List.fromList(base64Decode(base64Png));
}
