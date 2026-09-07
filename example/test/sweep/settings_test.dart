import 'package:flutter/material.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  // Settings screen with intentional overflow bugs:
  // - Row without Flexible wrapping — German "Benachrichtigungseinstellungen" overflows
  // - Fixed-width SizedBox — overflows at 2x text scale
  sweepTest(
    'settings',
    builder: () => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.email, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Email notifications enabled',
                    style: TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  Switch(value: true, onChanged: (_) {}),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.notifications, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Push notifications for all categories',
                    style: TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  Switch(value: false, onChanged: (_) {}),
                ],
              ),
              const Divider(),
              const SizedBox(
                width: 280,
                child: Text(
                  'Upgrade to Pro for unlimited projects and priority support',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                  ),
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
    arbDir: 'lib/l10n',
  );
}
