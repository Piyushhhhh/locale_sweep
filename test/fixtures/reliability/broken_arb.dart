import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';
import '../clean_localized_app/clean_widgets.dart';

void main() {
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
}
