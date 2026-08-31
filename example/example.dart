// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

/// Example: add this to your test/ directory and run `flutter test`.
void main() {
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
    arbDir: 'lib/l10n',
    body: (tester) async {
      expect(find.text('Welcome'), findsOneWidget);
    },
  );
}
