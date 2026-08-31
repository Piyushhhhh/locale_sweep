import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

import 'fixtures/load_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  group('Onboarding flow', () {
    clearSweepResults();

    sweepTest(
      'onboarding',
      builder: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF6750A4),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6750A4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.translate,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'LocaleSweep',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Localization QA for Flutter',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _FeatureCard(
                    icon: Icons.language,
                    color: const Color(0xFF6750A4),
                    title: 'Missing Translation Keys',
                    subtitle:
                        'Detects keys present in English but missing in German, Arabic, or Japanese ARB files.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    icon: Icons.format_size,
                    color: const Color(0xFF0061A4),
                    title: 'Text Overflow at 2x Scale',
                    subtitle:
                        'Catches layouts that break when accessibility text scaling is enabled by users.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    icon: Icons.swap_horiz,
                    color: const Color(0xFF7D5260),
                    title: 'RTL Layout Verification',
                    subtitle:
                        'Renders Arabic and Hebrew in right-to-left mode to catch directional layout bugs.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    icon: Icons.screenshot_monitor,
                    color: const Color(0xFF006C4C),
                    title: 'Golden Screenshot Proof',
                    subtitle:
                        'Captures a screenshot of every variant before failing, so you can see exactly what broke.',
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6750A4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      locales: ['en', 'de', 'ar', 'ja'],
      textScales: [1.0, 2.0],
      viewports: [ViewportPreset.phone, ViewportPreset.tablet],
      captureScreenshots: true,
      screenshotDir: '.locale_sweep/screenshots',
    );
  });

  group('Settings flow', () {
    sweepTest(
      'settings',
      builder: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF6750A4),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            centerTitle: false,
          ),
          body: ListView(
            children: [
              _SettingsSection(
                title: 'General',
                children: [
                  _SettingsTile(
                    icon: Icons.language,
                    iconColor: const Color(0xFF6750A4),
                    title: 'Language & Region',
                    value: 'English (US)',
                  ),
                  _SettingsTile(
                    icon: Icons.dark_mode,
                    iconColor: const Color(0xFF0061A4),
                    title: 'Appearance',
                    value: 'System default',
                  ),
                  _SettingsTile(
                    icon: Icons.text_fields,
                    iconColor: const Color(0xFF7D5260),
                    title: 'Text Size',
                    value: 'Medium',
                  ),
                ],
              ),
              _SettingsSection(
                title: 'Notifications',
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_active,
                    iconColor: const Color(0xFFB3261E),
                    title: 'Push Notifications',
                    value: 'Enabled',
                  ),
                  _SettingsTile(
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFF006C4C),
                    title: 'Email Digests',
                    value: 'Weekly summary',
                  ),
                ],
              ),
              _SettingsSection(
                title: 'Account',
                children: [
                  _SettingsTile(
                    icon: Icons.security,
                    iconColor: const Color(0xFF006C4C),
                    title: 'Privacy & Security',
                    value: '2FA enabled',
                  ),
                  _SettingsTile(
                    icon: Icons.storage,
                    iconColor: const Color(0xFF0061A4),
                    title: 'Storage & Cache',
                    value: '248 MB used',
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    iconColor: Colors.grey,
                    title: 'About',
                    value: 'Version 0.1.1',
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      locales: ['en', 'de', 'ar', 'ja'],
      textScales: [1.0, 2.0],
      viewports: [ViewportPreset.phone, ViewportPreset.tablet],
      captureScreenshots: true,
      screenshotDir: '.locale_sweep/screenshots',
    );
  });
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title),
      subtitle: Text(
        value,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
      ),
    );
  }
}
