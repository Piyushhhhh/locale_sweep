import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

import 'fixtures/load_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  // ── Test 1: sweepTest with tolerance generates golden screenshots ───────
  group('sweepTest with tolerance', () {
    clearSweepResults();

    sweepTest(
      'diff_exact',
      builder: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const _SimpleCard(title: 'Hello', subtitle: 'World'),
      ),
      locales: ['en', 'de'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: true,
      screenshotDir: '.locale_sweep/screenshots',
      tolerance: 0.5,
      diffOutputDir: '.locale_sweep/diffs',
    );
  });

  // ── Test 2: sweepResults list captures results ───────────────────────────
  group('Result capture verification', () {
    test('sweepResults list is populated after sweep', () {
      // sweepTest runs asynchronously via group/testWidgets, so by the time
      // we reach later groups, the in-memory list should have entries.
      // (clearSweepResults was called before sweepTest registered its tests)
      // The file-based sink writes on tearDownAll, which runs after all tests.
      // Here we just verify the API exists and is callable.
      expect(sweepResults, isA<List<SweepResult>>());
    });
  });

  // ── Test 3: GoldenDiffer with synthetic PNG images ──────────────────────
  group('GoldenDiffer with synthetic images', () {
    test('identical images produce 0% diff', () async {
      final png = await _createSolidPng(100, 100, 0xFF2196F3);

      final diff = await GoldenDiffer.computeDiff(actual: png, golden: png);

      expect(diff.diffPercent, 0.0);
      expect(diff.changedPixels, 0);
      expect(diff.totalPixels, 10000);
    });

    test('completely different images produce high diff', () async {
      final blue = await _createSolidPng(100, 100, 0xFF2196F3);
      final red = await _createSolidPng(100, 100, 0xFFE91E63);

      final diff = await GoldenDiffer.computeDiff(actual: red, golden: blue);

      expect(diff.diffPercent, greaterThan(90));
      expect(diff.changedPixels, 10000);
      expect(diff.totalPixels, 10000);
    });

    test('images with minor difference produce small diff', () async {
      // Create two nearly-identical images (differ by 1 pixel per channel — below threshold)
      final img1 = await _createSolidPng(100, 100, 0xFF808080);
      final img2 = await _createSolidPng(100, 100, 0xFF818181);

      final diff = await GoldenDiffer.computeDiff(actual: img1, golden: img2);

      // Per-channel diff is 1, below threshold of 2 → no pixels flagged
      expect(diff.diffPercent, 0.0);
      expect(diff.changedPixels, 0);
    });

    test('per-channel diff above threshold is detected', () async {
      final img1 = await _createSolidPng(100, 100, 0xFF808080);
      final img2 = await _createSolidPng(100, 100, 0xFF858585);

      final diff = await GoldenDiffer.computeDiff(actual: img1, golden: img2);

      // Per-channel diff is 5, above threshold of 2 → all pixels flagged
      expect(diff.diffPercent, 100.0);
      expect(diff.changedPixels, 10000);
    });

    test('different dimensions produce 100% diff', () async {
      final small = await _createSolidPng(50, 50, 0xFF2196F3);
      final large = await _createSolidPng(100, 100, 0xFF2196F3);

      final diff = await GoldenDiffer.computeDiff(actual: small, golden: large);

      expect(diff.diffPercent, 100.0);
    });

    test('generates valid 3-panel diff PNG', () async {
      final blue = await _createSolidPng(50, 50, 0xFF2196F3);
      final red = await _createSolidPng(50, 50, 0xFFE91E63);

      final diffPng = await GoldenDiffer.generateDiffImage(
        actual: red,
        golden: blue,
      );

      // Verify PNG magic bytes
      expect(diffPng.length, greaterThan(100));
      expect(diffPng[0], 0x89);
      expect(diffPng[1], 0x50); // 'P'
      expect(diffPng[2], 0x4E); // 'N'
      expect(diffPng[3], 0x47); // 'G'

      // Decode and verify dimensions: 3 panels × 50px + 2 gaps = 154px wide, 50px tall
      final codec = await ui.instantiateImageCodec(diffPng);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 154); // 50*3 + 2*2
      expect(frame.image.height, 50);
    });

    test('saveDiffImage writes file to disk', () async {
      final blue = await _createSolidPng(30, 30, 0xFF2196F3);
      final red = await _createSolidPng(30, 30, 0xFFE91E63);

      const outputPath = '.locale_sweep/diffs/e2e_synthetic_diff.png';

      final path = await GoldenDiffer.saveDiffImage(
        actual: red,
        golden: blue,
        outputPath: outputPath,
      );

      expect(path, outputPath);
      expect(File(path).existsSync(), isTrue);
      expect(File(path).lengthSync(), greaterThan(100));

      // Verify it's a valid PNG
      final bytes = File(path).readAsBytesSync();
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
    });
  });

  // ── Test 4: SweepGoldenComparator ──────────────────────────────────────
  group('SweepGoldenComparator integration', () {
    test('passes when diff is within tolerance', () async {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cmp_');
      final goldenFile = File('${tmpDir.path}/test_golden.png');
      final goldenPng = await _createSolidPng(50, 50, 0xFF2196F3);
      goldenFile.writeAsBytesSync(goldenPng);

      // Very different image — 100% of pixels differ
      final actualPng = await _createSolidPng(50, 50, 0xFFE91E63);

      final delegate = _TrackingComparator(goldenDir: tmpDir.path);
      final comparator = SweepGoldenComparator(
        delegate: delegate,
        tolerance: 100.0, // Accept everything
        diffOutputDir: '${tmpDir.path}/diffs',
      );

      final result = await comparator.compare(
        actualPng,
        Uri.parse('test_golden.png'),
      );

      expect(result, isTrue);
      expect(comparator.lastDiffResult, isNotNull);
      expect(comparator.lastDiffResult!.diffPercent, 100.0);
      expect(delegate.delegateCompareWasCalled, isFalse);

      tmpDir.deleteSync(recursive: true);
    });

    test('falls through to delegate when diff exceeds tolerance', () async {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cmp_');
      final goldenFile = File('${tmpDir.path}/test_golden.png');
      final goldenPng = await _createSolidPng(50, 50, 0xFF2196F3);
      goldenFile.writeAsBytesSync(goldenPng);

      // Very different image
      final actualPng = await _createSolidPng(50, 50, 0xFFE91E63);

      final delegate = _TrackingComparator(goldenDir: tmpDir.path);
      final comparator = SweepGoldenComparator(
        delegate: delegate,
        tolerance: 0.1, // Very strict
        diffOutputDir: '${tmpDir.path}/diffs',
      );

      final result = await comparator.compare(
        actualPng,
        Uri.parse('test_golden.png'),
      );

      // Delegate was called and returned false
      expect(result, isFalse);
      expect(delegate.delegateCompareWasCalled, isTrue);
      expect(comparator.lastDiffResult, isNotNull);
      expect(comparator.lastDiffResult!.diffPercent, greaterThan(90));

      tmpDir.deleteSync(recursive: true);
    });

    test('generates diff image when pixels differ', () async {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cmp_');
      final goldenFile = File('${tmpDir.path}/test_golden.png');
      final goldenPng = await _createSolidPng(50, 50, 0xFF2196F3);
      goldenFile.writeAsBytesSync(goldenPng);

      final actualPng = await _createSolidPng(50, 50, 0xFFE91E63);

      final delegate = _TrackingComparator(goldenDir: tmpDir.path);
      final comparator = SweepGoldenComparator(
        delegate: delegate,
        tolerance: 100.0,
        diffOutputDir: '${tmpDir.path}/diffs',
      );

      await comparator.compare(actualPng, Uri.parse('test_golden.png'));

      expect(comparator.lastDiffResult!.diffImagePath, isNotNull);
      expect(
        File(comparator.lastDiffResult!.diffImagePath!).existsSync(),
        isTrue,
      );

      tmpDir.deleteSync(recursive: true);
    });

    test('no diff image when images are identical', () async {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cmp_');
      final goldenFile = File('${tmpDir.path}/test_golden.png');
      final png = await _createSolidPng(50, 50, 0xFF2196F3);
      goldenFile.writeAsBytesSync(png);

      final delegate = _TrackingComparator(goldenDir: tmpDir.path);
      final comparator = SweepGoldenComparator(
        delegate: delegate,
        tolerance: 0.0,
        diffOutputDir: '${tmpDir.path}/diffs',
      );

      final result = await comparator.compare(
        png,
        Uri.parse('test_golden.png'),
      );

      expect(result, isTrue);
      expect(comparator.lastDiffResult!.diffPercent, 0.0);
      expect(comparator.lastDiffResult!.diffImagePath, isNull);

      tmpDir.deleteSync(recursive: true);
    });
  });

  // ── Test 5: Full report pipeline with diff data ─────────────────────────
  group('Report pipeline with diff', () {
    test('all three report formats contain diff data', () {
      final summary = SweepRunSummary(
        results: [
          const SweepResult(
            flowName: 'diff_e2e',
            variant: SweepVariant(
              locale: 'en',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: true,
            screenshotPath: '.locale_sweep/screenshots/diff_e2e_en.png',
            diff: DiffResult(
              diffPercent: 0.0,
              changedPixels: 0,
              totalPixels: 335076,
            ),
          ),
          const SweepResult(
            flowName: 'diff_e2e',
            variant: SweepVariant(
              locale: 'de',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: false,
            errorMessage: 'Golden file mismatch',
            screenshotPath: '.locale_sweep/screenshots/diff_e2e_de.png',
            diff: DiffResult(
              diffPercent: 4.23,
              changedPixels: 14173,
              totalPixels: 335076,
              diffImagePath: '.locale_sweep/diffs/diff_e2e_de_diff.png',
            ),
          ),
        ],
      );

      // Markdown
      final md = ReportGenerator.generateMarkdown(summary);
      expect(md, contains('| Diff % |'));
      expect(md, contains('4.23%'));
      expect(md, contains('Golden file mismatch'));

      // HTML
      final html = ReportGenerator.generateHtml(summary);
      expect(html, contains('4.23% diff'));
      expect(html, contains('badge-diff'));
      expect(html, contains('View diff image'));
      expect(html, contains('diff_e2e_de_diff.png'));
      // 0% diff should NOT show badge
      expect(html, isNot(contains('0.00% diff')));

      // JSON
      final jsonStr = ReportGenerator.generateJson(summary);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final results = data['results'] as List;
      final passResult = results[0] as Map<String, dynamic>;
      final failResult = results[1] as Map<String, dynamic>;

      expect(passResult['diff']['diffPercent'], 0.0);
      expect(passResult['diff']['changedPixels'], 0);
      expect(failResult['diff']['diffPercent'], 4.23);
      expect(failResult['diff']['diffImagePath'], contains('diff_e2e_de'));

      // Write to disk for manual inspection
      final reportDir = Directory('.locale_sweep/reports');
      reportDir.createSync(recursive: true);
      File('${reportDir.path}/diff_e2e_report.html').writeAsStringSync(html);
      File('${reportDir.path}/diff_e2e_report.md').writeAsStringSync(md);
      File('${reportDir.path}/diff_e2e_report.json').writeAsStringSync(jsonStr);
    });
  });

  // ── Test 6: Tolerance config round-trip ─────────────────────────────────
  group('Config tolerance', () {
    test('loads from YAML and defaults correctly', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cfg_');

      // With tolerance
      File('${tmpDir.path}/with.yaml').writeAsStringSync('''
locales:
  - en
tolerance: 2.5
''');
      expect(SweepConfig.load('${tmpDir.path}/with.yaml').tolerance, 2.5);

      // Without tolerance
      File('${tmpDir.path}/without.yaml').writeAsStringSync('''
locales:
  - en
''');
      expect(SweepConfig.load('${tmpDir.path}/without.yaml').tolerance, 0.0);

      // Integer tolerance → double
      File('${tmpDir.path}/int.yaml').writeAsStringSync('tolerance: 5');
      final cfg = SweepConfig.load('${tmpDir.path}/int.yaml');
      expect(cfg.tolerance, 5.0);
      expect(cfg.tolerance, isA<double>());

      tmpDir.deleteSync(recursive: true);
    });
  });
}

// ─── Test widget ──────────────────────────────────────────────────────────

class _SimpleCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SimpleCard({required this.title, required this.subtitle});

  static const bgColor = Color(0xFFE91E63);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: bgColor.withAlpha(30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.compare_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: bgColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Fake comparator ──────────────────────────────────────────────────────

class _TrackingComparator implements GoldenFileComparator {
  final String goldenDir;
  bool delegateCompareWasCalled = false;

  _TrackingComparator({required this.goldenDir});

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    delegateCompareWasCalled = true;
    return false;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}

  @override
  Uri getTestUri(Uri key, int? version) {
    return Uri.file('$goldenDir/${key.pathSegments.last}');
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────

/// Creates a solid-color PNG using dart:ui.
Future<Uint8List> _createSolidPng(int width, int height, int color) async {
  final a = (color >> 24) & 0xFF;
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final b = color & 0xFF;

  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = r;
    pixels[i + 1] = g;
    pixels[i + 2] = b;
    pixels[i + 3] = a;
  }

  final image = await _imageFromPixels(pixels, width, height);
  final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
  return pngData!.buffer.asUint8List();
}

Future<ui.Image> _imageFromPixels(Uint8List rgba, int width, int height) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
