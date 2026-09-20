import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
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
