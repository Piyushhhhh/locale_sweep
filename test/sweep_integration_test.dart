import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

import 'fixtures/clean_localized_app/clean_widgets.dart';

void main() {
  group('sweepTest end-to-end with clean fixture', () {
    clearSweepResults();

    sweepTest(
      'clean_flow',
      builder: cleanWidget,
      locales: ['en', 'de', 'ar'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
    );

    tearDownAll(() {
      final results = sweepResults;

      expect(
        results,
        isNotEmpty,
        reason: 'sweepTest should generate test results',
      );

      expect(
        results.length,
        3,
        reason: '3 locales × 1 scale × 1 viewport = 3 variants',
      );

      for (final r in results) {
        expect(r.flowName, 'clean_flow');
        expect(
          r.passed,
          isTrue,
          reason: 'Clean widget should pass: ${r.variant.displayLabel}',
        );
        expect(r.hasOverflows, isFalse);
        expect(r.overflows, isEmpty);
      }

      final locales = results.map((r) => r.variant.locale).toSet();
      expect(locales, containsAll(['en', 'de', 'ar']));

      final rtlResults = results
          .where((r) => r.variant.locale == 'ar')
          .toList();
      expect(rtlResults.first.variant.isRtl, isTrue);
      expect(rtlResults.first.variant.textDirection, TextDirection.rtl);
    });
  });

  group('sweepTest with ARB analysis', () {
    clearSweepResults();

    sweepTest(
      'arb_clean_flow',
      builder: cleanWidget,
      locales: ['en', 'de', 'ar'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      arbDir: 'test/fixtures/clean_localized_app/l10n',
      captureScreenshots: false,
    );

    tearDownAll(() {
      final results = sweepResults
          .where((r) => r.flowName == 'arb_clean_flow')
          .toList();
      expect(results, hasLength(3));
      for (final r in results) {
        expect(
          r.arbIssues,
          isEmpty,
          reason:
              'Clean ARB fixture should have no issues for ${r.variant.locale}',
        );
      }
    });
  });

  group('sweepTest with broken ARB analysis', () {
    clearSweepResults();

    sweepTest(
      'arb_broken_flow',
      builder: cleanWidget,
      locales: ['en', 'de', 'ar'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      arbDir: 'test/fixtures/broken_localized_app/l10n',
      captureScreenshots: false,
    );

    tearDownAll(() {
      final results = sweepResults
          .where((r) => r.flowName == 'arb_broken_flow')
          .toList();
      expect(results, hasLength(3));

      final deResult = results.firstWhere((r) => r.variant.locale == 'de');
      expect(
        deResult.arbIssues,
        isNotEmpty,
        reason: 'German locale should report missing settingsTitle key',
      );
      expect(
        deResult.arbIssues.any(
          (i) => i.type == ArbIssueType.missingKey && i.key == 'settingsTitle',
        ),
        isTrue,
      );

      final arResult = results.firstWhere((r) => r.variant.locale == 'ar');
      expect(
        arResult.arbIssues,
        isNotEmpty,
        reason: 'Arabic locale should report placeholder mismatch',
      );
      expect(
        arResult.arbIssues.any(
          (i) => i.type == ArbIssueType.placeholderMismatch,
        ),
        isTrue,
      );

      final enResult = results.firstWhere((r) => r.variant.locale == 'en');
      expect(
        enResult.arbIssues,
        isEmpty,
        reason: 'Base locale (en) should have no issues',
      );
    });
  });

  group('sweepTest variant matrix', () {
    clearSweepResults();

    sweepTest(
      'matrix_test',
      builder: cleanWidget,
      locales: ['en', 'ar'],
      textScales: [1.0, 2.0],
      viewports: [ViewportPreset.phoneSmall, ViewportPreset.tablet],
      captureScreenshots: false,
    );

    tearDownAll(() {
      final results = sweepResults
          .where((r) => r.flowName == 'matrix_test')
          .toList();
      expect(
        results,
        hasLength(8),
        reason: '2 locales × 2 scales × 2 viewports = 8 variants',
      );

      final labels = results.map((r) => r.variant.label).toSet();
      expect(labels, contains('en_375x667'));
      expect(labels, contains('en_2.0x_375x667'));
      expect(labels, contains('ar_768x1024'));
      expect(labels, contains('ar_2.0x_768x1024'));
    });
  });
}
