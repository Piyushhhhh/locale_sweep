// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

/// Example: add this to your test/ directory and run `flutter test`.
void main() {
  // Basic sweep — tests 4 locales × 2 scales × 2 viewports × 2 brightness
  // = 32 variants from one call.
  sweepTest(
    'onboarding',
    builder: () => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Welcome')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get started with our app',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'This description might overflow in German '
                'or at 2.0x text scale.',
              ),
            ],
          ),
        ),
      ),
    ),
    locales: ['en', 'de', 'ar', 'ja'],
    textScales: [1.0, 2.0],
    viewports: [ViewportPreset.phone, ViewportPreset.tablet],
    darkMode: true,
    arbDir: 'lib/l10n',
    skip: (variant) {
      // Skip Japanese at 2x scale on tablet — known issue
      return variant.locale == 'ja' &&
          variant.textScale == 2.0 &&
          variant.viewport == ViewportPreset.tablet;
    },
    variantBody: (tester, variant) async {
      expect(find.text('Welcome'), findsOneWidget);

      // Verify dark mode is wired up correctly
      if (variant.isDark) {
        final theme = Theme.of(tester.element(find.byType(Scaffold)));
        expect(theme.brightness, Brightness.dark);
      }
    },
  );
}
