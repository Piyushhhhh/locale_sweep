import 'package:flutter/material.dart';
import 'package:locale_sweep/locale_sweep.dart';
import 'package:taskflow_example/screens/settings_screen.dart';

void main() {
  sweepTest(
    'settings',
    builder: () => const MaterialApp(home: SettingsScreen()),
    locales: ['en', 'de', 'ar', 'ja', 'ko', 'he', 'th', 'hi'],
    textScales: [1.0, 2.0],
    viewports: [ViewportPreset.phone, ViewportPreset.tablet],
    darkMode: true,
    arbDir: 'lib/l10n',
  );
}
