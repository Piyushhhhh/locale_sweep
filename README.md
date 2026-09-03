<div align="center">

# LocaleSweep

**Localization QA for Flutter — automated.**

One function call. Every locale, viewport, and text scale. Screenshots + failure reports.

[![pub.dev](https://img.shields.io/pub/v/locale_sweep.svg?style=for-the-badge&color=E91E63)](https://pub.dev/packages/locale_sweep)
[![pub points](https://img.shields.io/pub/points/locale_sweep?style=for-the-badge&color=E91E63&label=pub%20points)](https://pub.dev/packages/locale_sweep/score)
[![License: MIT](https://img.shields.io/badge/license-MIT-E91E63.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Flutter 3.32+](https://img.shields.io/badge/flutter-%E2%89%A53.32-E91E63.svg?style=for-the-badge)](https://flutter.dev)

</div>

| English | German | Config | 2x Scale |
|:---:|:---:|:---:|:---:|
| <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_en_393x852.png?v=6" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_de_393x852.png?v=6" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/config_en_393x852.png?v=6" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_en_2.0x_393x852.png?v=6" width="180" /> |

---

## Why LocaleSweep?

Your app looks perfect in English. Then a German user opens Settings and *"Benachrichtigungseinstellungen"* overflows the row. An Arabic user sees left-aligned text. A Japanese user hits an untranslated screen. You find out from a 1-star review.

**LocaleSweep catches these before your users do.** It multiplies a single test across every combination of locale, text scale, and viewport — then captures a golden screenshot of each variant and fails only the ones that break.

```dart
sweepTest(
  'settings',                    // flow name — used in test labels & screenshot filenames
  builder: () => const MyApp(),  // the widget under test
  arbDir: 'lib/l10n',            // optional — path to your .arb files to detect missing translation keys
  locales: ['en', 'de', 'ar', 'ja'],
  textScales: [1.0, 2.0],
  viewports: [ViewportPreset.phone, ViewportPreset.tablet],
);
// 4 locales × 2 scales × 2 viewports = 16 test cases from one call
```

---

## What it catches

| # | Category | How |
|:--|:--|:--|
| 1 | **Text overflow** | Intercepts `RenderFlex` overflow errors — German compound words, Arabic text expansion, CJK line wrapping |
| 2 | **Missing ARB keys** | Finds keys present in `app_en.arb` but absent in target locale ARB files |
| 3 | **Placeholder mismatches** | Verifies `{count}`, `{name}`, etc. from base locale appear in every translation |
| 4 | **Golden regression** | Pixel-level comparison against committed baselines — catches unintended visual changes |
| 5 | **Accessibility scaling** | Renders at 2x text scale to catch layouts that break for large-text users |
| 6 | **RTL layout** | Auto-detects 10 RTL locales (Arabic, Hebrew, Farsi, Urdu, Kurdish, Pashto, Yiddish, Dhivehi, Sindhi, Uyghur) — including subtags like `ar_EG` |
| 7 | **Untranslated strings** | Flags keys where the translation is identical to the base locale — likely copy-paste that was never translated |

---

## Getting started

### 1. Install

```yaml
dev_dependencies:
  locale_sweep: ^0.1.5
```

### 2. Write a sweep test

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  sweepTest(
    'onboarding',
    builder: () => const MyApp(),
    arbDir: 'lib/l10n',
    body: (tester) async {
      // optional — interact with the widget before screenshot
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
    },
  );
}
```

Need locale-aware interactions? Use `variantBody` instead of `body` to get the current variant:

```dart
sweepTest(
  'checkout',
  builder: () => const CheckoutPage(),
  variantBody: (tester, variant) async {
    // variant.locale — current locale code (e.g. 'ar', 'de')
    // variant.isRtl  — true for Arabic, Hebrew, Farsi, Urdu, etc.
    // variant.textScale — current text scale factor
    // variant.viewport — current viewport dimensions

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    if (variant.isRtl) {
      // verify RTL-specific layout, e.g. back button on the right
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    }
  },
);
```

### 3. Run

```bash
# Generate golden baselines (run locally first)
dart run locale_sweep update

# Compare against baselines (run in CI)
dart run locale_sweep run
```

> `run` never regenerates goldens. `update` does. This prevents CI from silently accepting broken layouts as the new baseline.

---

## Screenshot gallery

Every variant gets its own golden PNG — locale, text scale, and viewport encoded in the filename.

**Onboarding flow**

| English | German | 2x Scale | Tablet |
|:---:|:---:|:---:|:---:|
| <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_en_393x852.png?v=6" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_de_393x852.png?v=6" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_en_2.0x_393x852.png?v=6" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_en_768x1024.png?v=6" width="180" /> |

**Configuration flow**

| English | German | 2x Scale | Tablet |
|:---:|:---:|:---:|:---:|
| <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/config_en_393x852.png?v=6" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/config_de_393x852.png?v=6" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/config_en_2.0x_393x852.png?v=6" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/config_en_768x1024.png?v=6" width="180" /> |

*Real golden files from headless Flutter widget tests — not mockups.*

---

## CI integration

### GitHub Actions

```yaml
- name: LocaleSweep
  run: dart run locale_sweep run --github-pr
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Posts a PR comment with a failure table, locale summary, and inline screenshot links. Updates the same comment on re-runs.

### CLI reference

```bash
dart run locale_sweep run                           # Compare goldens, fail broken variants
dart run locale_sweep run --flows onboarding        # Run specific flows only
dart run locale_sweep run --github-pr               # Post results as a PR comment
dart run locale_sweep run --config my_config.yaml   # Use a custom config file
dart run locale_sweep update                        # Regenerate golden baselines
dart run locale_sweep update --flows settings       # Update specific flows only
```

The CLI reads `locale_sweep.yaml` by default. Override with `--config`.

---

## Configuration

Create `locale_sweep.yaml` in your project root for shared defaults:

```yaml
locales: [en, de, ar, ja]
text_scales: [1.0, 2.0]

viewports:
  - { name: "375x667", width: 375, height: 667 }
  - { name: "768x1024", width: 768, height: 1024 }

arb_dir: lib/l10n
screenshot_dir: .locale_sweep/screenshots
report_dir: .locale_sweep/reports
```

Or override per-flow directly in `sweepTest()`:

```dart
sweepTest(
  'checkout',
  builder: () => const CheckoutPage(),
  locales: ['en', 'de'],
  textScales: [1.0, 1.5, 2.0],
  viewports: [ViewportPreset.phoneSmall],
  arbDir: 'lib/l10n',
);
```

---

## API reference

### `sweepTest()` parameters

| Parameter | Type | Default | Description |
|:--|:--|:--|:--|
| `flowName` | `String` | required | Identifies this flow in test labels and screenshot filenames |
| `builder` | `Widget Function()` | required | The widget to render |
| `body` | `Future<void> Function(WidgetTester)?` | `null` | Optional interactions to run after the widget is pumped |
| `variantBody` | `Future<void> Function(WidgetTester, SweepVariant)?` | `null` | Like `body`, but also receives the current variant — use for locale-aware interactions |
| `locales` | `List<String>?` | from config | BCP-47 locale codes (e.g. `'en'`, `'de'`, `'ar'`, `'ar_EG'`) |
| `textScales` | `List<double>?` | from config | Text scale factors to test |
| `viewports` | `List<ViewportPreset>?` | from config | Screen dimensions to test |
| `arbDir` | `String?` | from config | Path to `.arb` translation files for missing-key analysis |
| `captureScreenshots` | `bool` | `true` | Whether to save golden screenshots |

### `ViewportPreset` built-in presets

| Preset | Dimensions | Use case |
|:--|:--|:--|
| `ViewportPreset.phoneSmall` | 375 x 667 | iPhone SE, compact phones |
| `ViewportPreset.phone` | 393 x 852 | Standard modern phones |
| `ViewportPreset.phoneWide` | 412 x 915 | Tall/wide phones |
| `ViewportPreset.tablet` | 768 x 1024 | iPad, Android tablets |

Custom: `ViewportPreset(name: '1280x800', width: 1280, height: 800)`

### `SweepVariant` properties

Available in `variantBody` callback:

| Property | Type | Description |
|:--|:--|:--|
| `locale` | `String` | BCP-47 locale code (e.g. `'ar'`, `'de'`, `'ar_EG'`) |
| `isRtl` | `bool` | Whether this locale is right-to-left |
| `textDirection` | `TextDirection` | `TextDirection.rtl` or `TextDirection.ltr` |
| `textScale` | `double` | Current text scale factor |
| `viewport` | `ViewportPreset` | Current viewport dimensions |
| `displayLabel` | `String` | Human-readable label (e.g. `"AR · RTL · 2.0x scale · 393x852"`) |

---

## Output

```
.locale_sweep/
  report.md               # Markdown failure table + locale summary
  report.json             # Machine-readable results for CI
  screenshots/
    onboarding_en_393x852.png
    onboarding_de_2.0x_393x852.png
    onboarding_ar_768x1024.png
    settings_en_375x667.png
    ...
```

---

## How it works

| Step | What happens |
|:--|:--|
| **1** | `sweepTest()` expands into `locales x scales x viewports` individual `testWidgets` calls |
| **2** | Each test configures the Flutter test view with the target viewport, locale, and text scale |
| **3** | Your widget is pumped inside `Directionality` + `MediaQuery` wrappers |
| **4** | `OverflowDetector` hooks into `FlutterError.onError` to capture `RenderFlex` overflow |
| **5** | `matchesGoldenFile` saves or compares the screenshot |
| **6** | `ArbAnalyzer` runs static analysis on ARB JSON files — no rendering needed |
| **7** | Results are recorded **before** assertions — screenshots always exist, even for broken variants |

---

## Real-world validation

Tested against two popular open-source Flutter apps:

| App | Stars | Result |
|:--|:--|:--|
| **Spotube** | 48k+ | 0 issues across de/ar/ja/fr/es/ko/zh — **zero false positives** |
| **wger** | 960+ | **165 missing Arabic keys**, **1 placeholder mismatch**, **301 missing Hebrew keys** — all real bugs |

> Zero noise on complete translations. Real findings on incomplete ones.

---

## Test suite

108 tests across 7 test files. Run with `flutter test`.

| Test file | Coverage |
|:--|:--|
| `arb_analyzer_test.dart` | Missing keys, placeholder mismatches, untranslated detection, metadata filtering |
| `overflow_detector_test.dart` | RenderFlex capture, pixel extraction, handler restore |
| `sweep_variant_test.dart` | RTL detection (10 locales + subtags), label formatting, screenshot paths |
| `report_test.dart` | JSON structure, markdown tables, locale summary |
| `sweep_integration_test.dart` | End-to-end: clean pass, broken ARB, matrix variant count |
| `p0_p1_verification_test.dart` | RTL expansion, config loading, variantBody callback, untranslated strings |
| `real_world_arb_test.dart` | Spotube + wger ARB analysis — zero false positives on real apps |

---

*MIT License*
