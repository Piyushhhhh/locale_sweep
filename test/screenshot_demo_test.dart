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
        theme: ThemeData(brightness: Brightness.light, fontFamily: 'Roboto'),
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
        theme: ThemeData(brightness: Brightness.light, fontFamily: 'Roboto'),
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

// ─── Colors ────────────────────────────────────────────────────────────────

const _pink = Color(0xFFE91E63);
const _pinkLight = Color(0xFFFCE4EC);
const _pinkSoft = Color(0xFFFFF0F5);
const _pinkMedium = Color(0xFFF8BBD0);
const _rose = Color(0xFFEC4899);
const _dark = Color(0xFF1A1A2E);
const _grey = Color(0xFF9E9E9E);
const _greyLight = Color(0xFFF5F5F5);
const _white = Color(0xFFFFFFFF);

// ─── Translations ──────────────────────────────────────────────────────────

const _t = {
  'en': {
    'title': 'LocaleSweep',
    'subtitle': 'Catch broken translations\nbefore your users do',
    'checks': '6 checks',
    'ci': 'CI ready',
    'config': '0 config',
    'missing': 'Missing Keys',
    'missingDesc': 'Finds absent ARB keys across target locales',
    'overflow': 'Overflow Detection',
    'overflowDesc': 'Catches broken layouts at 2x text scale',
    'rtl': 'RTL Verification',
    'rtlDesc': 'Auto-flips layout for Arabic & Hebrew',
    'golden': 'Golden Screenshots',
    'goldenDesc': 'Pixel-level proof for every variant',
    'cta': 'Get Started',
    'configuration': 'Configuration',
  },
  'de': {
    'title': 'LocaleSweep',
    'subtitle': 'Fehlerhafte Ubersetzungen\nfinden, bevor Nutzer es tun',
    'checks': '6 Pruefungen',
    'ci': 'CI-fhig',
    'config': '0 Konfig',
    'missing': 'Fehlende Schluessel',
    'missingDesc': 'Findet fehlende ARB-Schluessel in Zielsprachen',
    'overflow': 'Uberlauf-Erkennung',
    'overflowDesc': 'Erkennt defekte Layouts bei 2x Textgroesse',
    'rtl': 'RTL-Pruefung',
    'rtlDesc': 'Spiegelt Layout fuer Arabisch & Hebraeisch',
    'golden': 'Golden Screenshots',
    'goldenDesc': 'Pixelgenauer Nachweis jeder Variante',
    'cta': 'Loslegen',
    'configuration': 'Konfiguration',
  },
  'ar': {
    'title': 'LocaleSweep',
    'subtitle': 'RTL mode active\nLayout is mirrored',
    'checks': '6 checks',
    'ci': 'CI ready',
    'config': 'RTL',
    'missing': 'Missing Keys',
    'missingDesc': 'Finds absent ARB keys across target locales',
    'overflow': 'Overflow Detection',
    'overflowDesc': 'Catches broken layouts at 2x text scale',
    'rtl': 'RTL Verification',
    'rtlDesc': 'Auto-flips layout for Arabic & Hebrew',
    'golden': 'Golden Screenshots',
    'goldenDesc': 'Pixel-level proof for every variant',
    'cta': 'Get Started',
    'configuration': 'Configuration',
  },
  'ja': {
    'title': 'LocaleSweep',
    'subtitle': 'Catch broken translations\nbefore your users do',
    'checks': '6 checks',
    'ci': 'CI ready',
    'config': '0 config',
    'missing': 'Missing Keys',
    'missingDesc': 'Finds absent ARB keys across target locales',
    'overflow': 'Overflow Detection',
    'overflowDesc': 'Catches broken layouts at 2x text scale',
    'rtl': 'RTL Verification',
    'rtlDesc': 'Auto-flips layout for Arabic & Hebrew',
    'golden': 'Golden Screenshots',
    'goldenDesc': 'Pixel-level proof for every variant',
    'cta': 'Get Started',
    'configuration': 'Configuration',
  },
};

String _tr(BuildContext context, String key) {
  final locale = View.of(context).platformDispatcher.locale.languageCode;
  return _t[locale]?[key] ?? _t['en']![key]!;
}

// ─── Onboarding ────────────────────────────────────────────────────────────

class _OnboardingScreen extends StatelessWidget {
  const _OnboardingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pinkSoft,
      body: Builder(
        builder: (ctx) {
          String t(String k) => _tr(ctx, k);
          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _pink,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _pink.withAlpha(60),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.translate_rounded,
                                  color: _white,
                                  size: 22,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _white.withAlpha(180),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'v0.1.1',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _pink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            t('title'),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: _dark,
                              letterSpacing: -1.0,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t('subtitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: _dark.withAlpha(140),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _StatPill(t('checks'), Icons.shield_outlined),
                              _StatPill(t('ci'), Icons.rocket_launch_outlined),
                              _StatPill(t('config'), Icons.bolt_outlined),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    children: [
                      _FeatureCard(
                        icon: Icons.language_rounded,
                        title: t('missing'),
                        desc: t('missingDesc'),
                        accent: _pink,
                      ),
                      const SizedBox(height: 10),
                      _FeatureCard(
                        icon: Icons.format_size_rounded,
                        title: t('overflow'),
                        desc: t('overflowDesc'),
                        accent: _rose,
                      ),
                      const SizedBox(height: 10),
                      _FeatureCard(
                        icon: Icons.swap_horiz_rounded,
                        title: t('rtl'),
                        desc: t('rtlDesc'),
                        accent: const Color(0xFFAD1457),
                      ),
                      const SizedBox(height: 10),
                      _FeatureCard(
                        icon: Icons.camera_alt_rounded,
                        title: t('golden'),
                        desc: t('goldenDesc'),
                        accent: const Color(0xFFC2185B),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE91E63), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _pink.withAlpha(70),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            t('cta'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'pub.dev/packages/locale_sweep',
                        style: TextStyle(
                          fontSize: 11,
                          color: _dark.withAlpha(80),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatPill(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _white.withAlpha(200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _pinkMedium.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _pink),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _pink,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color accent;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _pink.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withAlpha(20),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: _dark.withAlpha(110),
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
      backgroundColor: _pinkSoft,
      body: SafeArea(
        child: Builder(
          builder: (ctx) {
            final title = _tr(ctx, 'configuration');
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _pink.withAlpha(50),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: _white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _dark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Text(
                            'locale_sweep.yaml',
                            style: TextStyle(
                              fontSize: 12,
                              color: _grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Locales
                const _Card(
                  children: [
                    _Header('Locales', Icons.language_rounded),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Tag('EN', _pink, active: true),
                        _Tag('DE', _rose, active: true),
                        _Tag('AR', Color(0xFFAD1457), active: true),
                        _Tag('JA', Color(0xFFC2185B), active: true),
                        _Tag('FR', _grey, active: false),
                        _Tag('ES', _grey, active: false),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Viewports
                const _Card(
                  children: [
                    _Header('Viewports', Icons.devices_rounded),
                    SizedBox(height: 12),
                    _DeviceRow(
                      Icons.phone_iphone_rounded,
                      'Phone',
                      '393 × 852',
                      _pink,
                      true,
                    ),
                    SizedBox(height: 8),
                    _DeviceRow(
                      Icons.tablet_rounded,
                      'Tablet',
                      '768 × 1024',
                      _rose,
                      true,
                    ),
                    SizedBox(height: 8),
                    _DeviceRow(
                      Icons.desktop_windows_rounded,
                      'Desktop',
                      '1280 × 800',
                      _grey,
                      false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Text scales
                const _Card(
                  children: [
                    _Header('Text Scales', Icons.format_size_rounded),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        _ScaleChip('1.0×', _pink, true),
                        SizedBox(width: 8),
                        _ScaleChip('1.5×', _grey, false),
                        SizedBox(width: 8),
                        _ScaleChip('2.0×', _rose, true),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Output
                _Card(
                  children: [
                    const _Header('Output', Icons.folder_outlined),
                    const SizedBox(height: 12),
                    const _PathItem(
                      'Screenshots',
                      '.locale_sweep/screenshots/',
                    ),
                    Divider(height: 16, color: _pinkLight.withAlpha(180)),
                    const _PathItem('Reports', '.locale_sweep/reports/'),
                    Divider(height: 16, color: _pinkLight.withAlpha(180)),
                    const _PathItem('ARB source', 'lib/l10n/'),
                  ],
                ),
                const SizedBox(height: 12),

                // Matrix banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _pink.withAlpha(40),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
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
                                fontWeight: FontWeight.w700,
                                color: _white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '4 locales × 2 scales × 2 viewports',
                              style: TextStyle(
                                fontSize: 11,
                                color: _white.withAlpha(180),
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
                          color: _white.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '16',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _pink.withAlpha(10),
            blurRadius: 12,
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

class _Header extends StatelessWidget {
  final String title;
  final IconData icon;
  const _Header(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _pinkLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: _pink, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _pink,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String code;
  final Color color;
  final bool active;
  const _Tag(this.code, this.color, {required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 34,
      decoration: BoxDecoration(
        color: active ? color.withAlpha(18) : _greyLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? color.withAlpha(60) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Center(
        child: Text(
          code,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: active ? color : const Color(0xFFBBBBBB),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String dims;
  final Color color;
  final bool active;

  const _DeviceRow(this.icon, this.name, this.dims, this.color, this.active);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withAlpha(10) : _greyLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color.withAlpha(35) : const Color(0xFFE8E8E8),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: active ? color : const Color(0xFFBBBBBB)),
          const SizedBox(width: 10),
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? _dark : const Color(0xFFBBBBBB),
            ),
          ),
          const Spacer(),
          Text(
            dims,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? color : const Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: active ? color : const Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.check : Icons.add,
              color: _white,
              size: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  const _ScaleChip(this.label, this.color, this.active);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: active ? color.withAlpha(15) : _greyLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color.withAlpha(50) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: active ? color : const Color(0xFFBBBBBB),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathItem extends StatelessWidget {
  final String label;
  final String path;
  const _PathItem(this.label, this.path);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _pinkSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              path,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _pink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
