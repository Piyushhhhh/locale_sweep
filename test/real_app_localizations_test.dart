import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

import 'fixtures/clean_localized_app/localized_widgets.dart';

void main() {
  // Scenario 1: Real app pattern — individual screen with delegates
  // This is how a team would test a single screen WITHOUT wrapping in MaterialApp
  group('Individual screen with localizationsDelegates', () {
    sweepTest(
      'screen_with_delegates',
      builder: () => Scaffold(
        appBar: AppBar(
          title: Builder(
            builder: (context) => Text(AppStrings.of(context).settingsTitle),
          ),
        ),
        body: Builder(
          builder: (context) {
            final strings = AppStrings.of(context);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.welcomeTitle,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(strings.settingsTitle),
                ],
              ),
            );
          },
        ),
      ),
      locales: ['en', 'de', 'ar', 'ja'],
      textScales: [1.0, 2.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
      localizationsDelegates: const [AppStringsDelegate()],
      variantBody: (tester, variant) async {
        // Verify the correct locale's text is rendered
        switch (variant.locale) {
          case 'en':
            expect(find.text('Welcome'), findsOneWidget);
            expect(find.text('Settings'), findsWidgets);
          case 'de':
            expect(find.text('Willkommen'), findsOneWidget);
            expect(find.text('Einstellungen'), findsWidgets);
          case 'ar':
            expect(find.text('مرحباً'), findsOneWidget);
            expect(find.text('الإعدادات'), findsWidgets);
          case 'ja':
            expect(find.text('ようこそ'), findsOneWidget);
            expect(find.text('設定'), findsWidgets);
        }
      },
    );
  });

  // Scenario 2: Full MaterialApp with delegates — the "wrap everything" pattern
  // Verifies delegates work alongside MaterialApp's own Localizations
  group('Full MaterialApp with delegates', () {
    sweepTest(
      'full_app_with_delegates',
      builder: () => MaterialApp(
        localizationsDelegates: const [AppStringsDelegate()],
        supportedLocales: const [Locale('en'), Locale('de'), Locale('ar')],
        home: Builder(
          builder: (context) {
            final strings = AppStrings.of(context);
            return Scaffold(
              appBar: AppBar(title: Text(strings.settingsTitle)),
              body: Center(child: Text(strings.welcomeTitle)),
            );
          },
        ),
      ),
      locales: ['en', 'de', 'ar'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
    );
  });

  // Scenario 3: Individual screen WITHOUT delegates — should still work
  // (backward compatibility)
  group('Screen without delegates (backward compat)', () {
    sweepTest(
      'no_delegates_plain',
      builder: () => const Scaffold(
        body: Center(child: Text('This widget has no localization')),
      ),
      locales: ['en', 'de'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
      variantBody: (tester, variant) async {
        expect(find.text('This widget has no localization'), findsOneWidget);
      },
    );
  });

  // Scenario 4: Locale parsing with real subtags (zh_Hans, pt_BR)
  group('Locale subtag handling', () {
    sweepTest(
      'subtag_locales',
      builder: localizedWidget,
      locales: ['en', 'fr'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
      localizationsDelegates: const [AppStringsDelegate()],
      variantBody: (tester, variant) async {
        if (variant.locale == 'fr') {
          expect(find.text('Bienvenue'), findsOneWidget);
          expect(find.text('Paramètres'), findsOneWidget);
        }
      },
    );
  });

  // Scenario 5: Dark mode + delegates combo
  group('Dark mode with delegates', () {
    sweepTest(
      'dark_mode_delegates',
      builder: () => Builder(
        builder: (context) {
          final strings = AppStrings.of(context);
          final brightness = Theme.of(context).brightness;
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.welcomeTitle),
                  Text('Mode: ${brightness.name}'),
                ],
              ),
            ),
          );
        },
      ),
      locales: ['en', 'de'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      darkMode: true,
      captureScreenshots: false,
      localizationsDelegates: const [AppStringsDelegate()],
      variantBody: (tester, variant) async {
        if (variant.locale == 'de') {
          expect(find.text('Willkommen'), findsOneWidget);
        }
        if (variant.isDark) {
          expect(find.text('Mode: dark'), findsOneWidget);
        } else {
          expect(find.text('Mode: light'), findsOneWidget);
        }
      },
    );
  });

  // Scenario 6: baseLocale with non-English base
  group('Non-English base locale for ARB analysis', () {
    clearSweepResults();

    sweepTest(
      'de_base_locale',
      builder: () => const Center(child: Text('Test')),
      locales: ['en', 'de', 'ar'],
      textScales: [1.0],
      viewports: [ViewportPreset.phone],
      captureScreenshots: false,
      arbDir: 'test/fixtures/clean_localized_app/l10n',
      baseLocale: 'de',
    );

    tearDownAll(() {
      final results = sweepResults
          .where((r) => r.flowName == 'de_base_locale')
          .toList();

      expect(results, hasLength(3));

      final deResult = results.firstWhere((r) => r.variant.locale == 'de');
      expect(
        deResult.arbIssues,
        isEmpty,
        reason: 'Base locale (de) should have no ARB issues',
      );
    });
  });
}
