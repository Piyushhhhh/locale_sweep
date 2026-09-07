import 'package:flutter/material.dart';
import 'package:locale_sweep/locale_sweep.dart';
import 'package:taskflow_example/screens/profile_screen.dart';

void main() {
  sweepTest(
    'profile',
    builder: () => const MaterialApp(home: ProfileScreen()),
    locales: ['en', 'de', 'ar', 'ja', 'ko', 'he', 'th', 'hi'],
    textScales: [1.0, 2.0],
    viewports: [ViewportPreset.phone, ViewportPreset.tablet],
    darkMode: true,
    arbDir: 'lib/l10n',
  );
}
