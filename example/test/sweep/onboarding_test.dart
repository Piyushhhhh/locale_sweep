import 'package:flutter/material.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  // Onboarding screen — catches ARB issues (missing keys, placeholder
  // mismatches, untranslated strings) and text overflow at large scales.
  sweepTest(
    'onboarding',
    builder: () => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('TaskFlow')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to TaskFlow',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Organize your work, your way. Manage tasks, '
                'track deadlines, and collaborate with your team.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Text(
                '5 tasks remaining',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Get Started'),
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
    arbDir: 'lib/l10n',
  );
}
