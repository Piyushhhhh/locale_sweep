import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

import 'fixtures/clean_localized_app/localized_widgets.dart';

void main() {
  group('parseLocale', () {
    test('simple language code', () {
      final locale = parseLocale('en');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, isNull);
      expect(locale.scriptCode, isNull);
    });

    test('language with country code', () {
      final locale = parseLocale('en_US');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, 'US');
    });

    test('language with country code using hyphen', () {
      final locale = parseLocale('pt-BR');
      expect(locale.languageCode, 'pt');
      expect(locale.countryCode, 'BR');
    });

    test('language with script code', () {
      final locale = parseLocale('zh_Hans');
      expect(locale.languageCode, 'zh');
      expect(locale.scriptCode, 'Hans');
      expect(locale.countryCode, isNull);
    });

    test('language with script and country', () {
      final locale = parseLocale('zh_Hans_CN');
      expect(locale.languageCode, 'zh');
      expect(locale.scriptCode, 'Hans');
      expect(locale.countryCode, 'CN');
    });
  });

  group('sweepTest with localizationsDelegates', () {
    clearSweepResults();

    sweepTest(
      'localized_flow',
      builder: localizedWidget,
      locales: ['en', 'de', 'ar'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
      localizationsDelegates: const [AppStringsDelegate()],
    );

    tearDownAll(() {
      final results = sweepResults
          .where((r) => r.flowName == 'localized_flow')
          .toList();

      expect(results, hasLength(3));

      for (final r in results) {
        expect(
          r.passed,
          isTrue,
          reason:
              'Localized widget should pass with delegates: ${r.variant.displayLabel}',
        );
        expect(r.hasOverflows, isFalse);
      }
    });
  });

  group('sweepTest with localizationsDelegates renders translated text', () {
    sweepTest(
      'localized_text_check',
      builder: localizedWidget,
      locales: ['de'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
      localizationsDelegates: const [AppStringsDelegate()],
      variantBody: (tester, variant) async {
        expect(find.text('Willkommen'), findsOneWidget);
        expect(find.text('Einstellungen'), findsOneWidget);
        expect(find.text('Welcome'), findsNothing);
      },
    );
  });

  group('sweepTest with localizationsDelegates renders Arabic', () {
    sweepTest(
      'localized_ar_check',
      builder: localizedWidget,
      locales: ['ar'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
      localizationsDelegates: const [AppStringsDelegate()],
      variantBody: (tester, variant) async {
        expect(find.text('مرحباً'), findsOneWidget);
        expect(find.text('الإعدادات'), findsOneWidget);
      },
    );
  });

  group('sweepTest without delegates still works (backward compatible)', () {
    clearSweepResults();

    sweepTest(
      'no_delegates_flow',
      builder: () => const Center(child: Text('Hello')),
      locales: ['en', 'de'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
    );

    tearDownAll(() {
      final results = sweepResults
          .where((r) => r.flowName == 'no_delegates_flow')
          .toList();

      expect(results, hasLength(2));
      for (final r in results) {
        expect(r.passed, isTrue);
      }
    });
  });

  group('baseLocale parameter', () {
    clearSweepResults();

    sweepTest(
      'base_locale_flow',
      builder: () => const Center(child: Text('Test')),
      locales: ['en', 'de', 'ar'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
      arbDir: 'test/fixtures/clean_localized_app/l10n',
      baseLocale: 'en',
    );

    tearDownAll(() {
      final results = sweepResults
          .where((r) => r.flowName == 'base_locale_flow')
          .toList();

      expect(results, hasLength(3));

      final enResult = results.firstWhere((r) => r.variant.locale == 'en');
      expect(
        enResult.arbIssues,
        isEmpty,
        reason: 'Base locale should have no ARB issues',
      );
    });
  });
}
