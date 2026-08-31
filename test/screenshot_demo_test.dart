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
          brightness: Brightness.dark,
          fontFamily: 'Roboto',
        ),
        home: const _OnboardingScreen(),
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
          brightness: Brightness.light,
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        ),
        home: const _SettingsScreen(),
      ),
      locales: ['en', 'de', 'ar', 'ja'],
      textScales: [1.0, 2.0],
      viewports: [ViewportPreset.phone, ViewportPreset.tablet],
      captureScreenshots: true,
      screenshotDir: '.locale_sweep/screenshots',
    );
  });
}

// ─── Onboarding ────────────────────────────────────────────────────────────

class _OnboardingScreen extends StatelessWidget {
  const _OnboardingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero gradient header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C3CE1), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withAlpha(50),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.translate_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'v0.1.1',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withAlpha(180),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'LocaleSweep',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Catch broken translations\nbefore your users do.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withAlpha(190),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Features list
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                children: [
                  _FeatureRow(
                    gradient: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
                    icon: Icons.language_rounded,
                    title: 'Missing Keys',
                    desc: 'Finds absent ARB keys in target locales',
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    gradient: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    icon: Icons.format_size_rounded,
                    title: 'Overflow Detection',
                    desc: 'Catches broken layouts at 2x text scale',
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    gradient: const [Color(0xFFDB2777), Color(0xFFF472B6)],
                    icon: Icons.swap_horiz_rounded,
                    title: 'RTL Verification',
                    desc: 'Auto-flips layout for Arabic, Hebrew, Farsi',
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    gradient: const [Color(0xFF059669), Color(0xFF34D399)],
                    icon: Icons.camera_alt_rounded,
                    title: 'Golden Screenshots',
                    desc: 'Pixel-level proof for every variant',
                  ),
                  const SizedBox(height: 22),

                  // CTA button
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C3CE1), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C3CE1).withAlpha(80),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'pub.dev/packages/locale_sweep',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(90),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FeatureRow extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureRow({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161628),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withAlpha(60),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withAlpha(120),
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

// ─── Settings ──────────────────────────────────────────────────────────────

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6C3CE1), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.translate_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuration',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'locale_sweep.yaml',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8EA0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Locales card
            _SectionCard(
              children: [
                _SectionHeader(
                  title: 'Locales',
                  icon: Icons.language_rounded,
                  color: const Color(0xFF6C3CE1),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LocaleTag('EN', const Color(0xFF6C3CE1), active: true),
                    _LocaleTag('DE', const Color(0xFF2563EB), active: true),
                    _LocaleTag('AR', const Color(0xFFDB2777), active: true),
                    _LocaleTag('JA', const Color(0xFF059669), active: true),
                    _LocaleTag('FR', const Color(0xFF8E8EA0), active: false),
                    _LocaleTag('ES', const Color(0xFF8E8EA0), active: false),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Viewports card
            _SectionCard(
              children: [
                _SectionHeader(
                  title: 'Viewports',
                  icon: Icons.devices_rounded,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(height: 14),
                _ViewportRow(
                  icon: Icons.phone_iphone_rounded,
                  name: 'Phone',
                  dims: '393 × 852',
                  color: const Color(0xFF2563EB),
                  active: true,
                ),
                const SizedBox(height: 8),
                _ViewportRow(
                  icon: Icons.tablet_rounded,
                  name: 'Tablet',
                  dims: '768 × 1024',
                  color: const Color(0xFF6C3CE1),
                  active: true,
                ),
                const SizedBox(height: 8),
                _ViewportRow(
                  icon: Icons.desktop_windows_rounded,
                  name: 'Desktop',
                  dims: '1280 × 800',
                  color: const Color(0xFF8E8EA0),
                  active: false,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Text scales card
            _SectionCard(
              children: [
                _SectionHeader(
                  title: 'Text Scales',
                  icon: Icons.format_size_rounded,
                  color: const Color(0xFFDB2777),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ScalePill('1.0×', const Color(0xFF059669), active: true),
                    const SizedBox(width: 8),
                    _ScalePill('1.5×', const Color(0xFF8E8EA0), active: false),
                    const SizedBox(width: 8),
                    _ScalePill('2.0×', const Color(0xFFDB2777), active: true),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Output card
            _SectionCard(
              children: [
                _SectionHeader(
                  title: 'Output',
                  icon: Icons.folder_outlined,
                  color: const Color(0xFF059669),
                ),
                const SizedBox(height: 14),
                _PathRow(
                  label: 'Screenshots',
                  path: '.locale_sweep/screenshots/',
                ),
                const Divider(height: 20, color: Color(0xFFEEEEF2)),
                _PathRow(
                  label: 'Reports',
                  path: '.locale_sweep/reports/',
                ),
                const Divider(height: 20, color: Color(0xFFEEEEF2)),
                _PathRow(
                  label: 'ARB source',
                  path: 'lib/l10n/',
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Matrix summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C3CE1), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C3CE1).withAlpha(40),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Matrix',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '4 locales × 2 scales × 2 viewports',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withAlpha(170),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '16',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _LocaleTag extends StatelessWidget {
  final String code;
  final Color color;
  final bool active;

  const _LocaleTag(this.code, this.color, {required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 36,
      decoration: BoxDecoration(
        color: active ? color.withAlpha(20) : const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? color.withAlpha(60) : const Color(0xFFE0E0E8),
        ),
      ),
      child: Center(
        child: Text(
          code,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? color : const Color(0xFFAAAAAA),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ViewportRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String dims;
  final Color color;
  final bool active;

  const _ViewportRow({
    required this.icon,
    required this.name,
    required this.dims,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withAlpha(12) : const Color(0xFFF8F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color.withAlpha(40) : const Color(0xFFE8E8EE),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? color : const Color(0xFFAAAAAA),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF1A1A2E) : const Color(0xFFAAAAAA),
            ),
          ),
          const Spacer(),
          Text(
            dims,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: active ? color : const Color(0xFFBBBBBB),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: active ? color : const Color(0xFFE0E0E8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.check : Icons.add,
              color: Colors.white,
              size: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScalePill extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  const _ScalePill(this.label, this.color, {required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: active ? color.withAlpha(18) : const Color(0xFFF0F0F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color.withAlpha(60) : const Color(0xFFE0E0E8),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: active ? color : const Color(0xFFAAAAAA),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  final String label;
  final String path;

  const _PathRow({required this.label, required this.path});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              path,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6C3CE1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
