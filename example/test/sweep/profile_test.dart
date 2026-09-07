import 'package:flutter/material.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  // Profile screen with intentional RTL bug:
  // - EdgeInsets.only(left: 24) instead of EdgeInsetsDirectional.only(start: 24)
  // - Arabic/Hebrew users see content jammed against the wrong edge
  sweepTest(
    'profile',
    builder: () => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Padding(
          padding: EdgeInsets.only(left: 24, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 32),
              CircleAvatar(radius: 40, child: Icon(Icons.person, size: 48)),
              SizedBox(height: 16),
              Text(
                'Hello, Sarah!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Last login: September 3, 2026',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Delete account permanently',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right),
                ],
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
