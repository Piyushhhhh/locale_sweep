import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  group('SweepVariant', () {
    test('detects RTL for Arabic, Hebrew, Farsi', () {
      for (final locale in ['ar', 'he', 'fa']) {
        final variant = SweepVariant(
          locale: locale,
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        );
        expect(variant.isRtl, isTrue, reason: '$locale should be RTL');
        expect(variant.textDirection, TextDirection.rtl);
      }
    });

    test('detects LTR for English, German, Japanese', () {
      for (final locale in ['en', 'de', 'ja']) {
        final variant = SweepVariant(
          locale: locale,
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        );
        expect(variant.isRtl, isFalse, reason: '$locale should be LTR');
        expect(variant.textDirection, TextDirection.ltr);
      }
    });

    test('label includes locale, scale (when not 1.0), viewport', () {
      const variant1x = SweepVariant(
        locale: 'de',
        textScale: 1.0,
        viewport: ViewportPreset.phone,
      );
      expect(variant1x.label, 'de_393x852');

      const variant2x = SweepVariant(
        locale: 'de',
        textScale: 2.0,
        viewport: ViewportPreset.phone,
      );
      expect(variant2x.label, 'de_2.0x_393x852');
    });

    test('displayLabel includes RTL marker for Arabic', () {
      const variant = SweepVariant(
        locale: 'ar',
        textScale: 2.0,
        viewport: ViewportPreset.tablet,
      );
      final label = variant.displayLabel;
      expect(label, contains('AR'));
      expect(label, contains('RTL'));
      expect(label, contains('2.0x scale'));
      expect(label, contains('768x1024'));
    });

    test('screenshotPath uses flow name and variant label', () {
      const variant = SweepVariant(
        locale: 'en',
        textScale: 1.0,
        viewport: ViewportPreset.phone,
      );
      expect(variant.screenshotPath('onboarding'), 'onboarding_en_393x852.png');
    });

    test('screenshotPath replaces spaces with underscores', () {
      const variant = SweepVariant(
        locale: 'en',
        textScale: 1.0,
        viewport: ViewportPreset(
          name: 'Custom Device',
          width: 400,
          height: 800,
        ),
      );
      expect(variant.screenshotPath('my flow'), 'my_flow_en_Custom_Device.png');
    });
  });

  group('ViewportPreset', () {
    test('size returns correct dimensions', () {
      expect(ViewportPreset.phone.size, const Size(393, 852));
      expect(ViewportPreset.phoneSmall.size, const Size(375, 667));
      expect(ViewportPreset.tablet.size, const Size(768, 1024));
    });

    test('toString returns name', () {
      expect(ViewportPreset.phone.toString(), '393x852');
    });
  });
}
