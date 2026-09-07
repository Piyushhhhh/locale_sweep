// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:locale_sweep/locale_sweep.dart';

/// Add this file to your test/sweep/ directory and run:
///   flutter test test/sweep/
///
/// LocaleSweep will test your widget across every combination of locale,
/// text scale, viewport, and brightness — then report overflows, missing
/// translations, and golden regressions.
void main() {
  // 8 locales × 2 scales × 2 viewports × 2 brightness = 64 variants
  sweepTest(
    'settings',
    builder: () => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // This Row overflows in German — LocaleSweep catches it.
              Row(
                children: [
                  const Icon(Icons.email),
                  const SizedBox(width: 12),
                  const Text('Email notifications enabled'),
                  const Spacer(),
                  Switch(value: true, onChanged: (_) {}),
                ],
              ),
              const Divider(),
              // Fixed-width text overflows at 2x scale.
              const SizedBox(
                width: 280,
                child: Text(
                  'Upgrade to Pro for unlimited projects',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    locales: ['en', 'de', 'ar', 'ja', 'ko', 'he', 'th', 'hi'],
    textScales: [1.0, 2.0],
    viewports: [ViewportPreset.phone, ViewportPreset.tablet],
    darkMode: true,
    arbDir: 'lib/l10n', // checks for missing keys & placeholder mismatches
  );
}
