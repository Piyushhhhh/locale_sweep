<div align="center">

# LocaleSweep

**Localization QA for Flutter — automated.**

One function call. Every locale, viewport, text scale, and brightness. Screenshots + reports.

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

Your app looks perfect in English. Then a German user opens Settings and *"Benachrichtigungseinstellungen"* overflows the row. An Arabic user sees left-aligned text. A Japanese user hits an untranslated screen.

**LocaleSweep catches these before your users do.** It multiplies a single test across every combination of locale, text scale, viewport, and brightness — then captures a golden screenshot of each variant and fails only the ones that break.

```dart
sweepTest(
  'settings',
  builder: () => const MyApp(),
  locales: ['en', 'de', 'ar', 'ja'],
  textScales: [1.0, 2.0],
  viewports: [ViewportPreset.phone, ViewportPreset.tablet],
  darkMode: true,
  arbDir: 'lib/l10n',
);
// 4 locales x 2 scales x 2 viewports x 2 brightness = 32 test cases from one call
```

---

## What it catches

| # | Category | How |
|:--|:--|:--|
| 1 | **Text overflow** | Intercepts `RenderFlex` overflow errors — German compound words, Arabic expansion, CJK wrapping |
| 2 | **Missing ARB keys** | Keys in `app_en.arb` absent from target locale files |
| 3 | **Placeholder mismatches** | `{count}`, `{name}` etc. missing in translations |
| 4 | **Untranslated strings** | Strings identical to the base locale — likely never translated |
| 5 | **Golden regression** | Pixel-level comparison against committed baselines |
| 6 | **Screenshot diffing** | Pixel-diff %, 3-panel side-by-side images, configurable tolerance |
| 7 | **Accessibility scaling** | Renders at 2x text scale to catch layouts that break for large-text users |
| 8 | **RTL layout** | Auto-detects 10 RTL locales (ar, he, fa, ur, ku, ps, yi, dv, sd, ug) including subtags |
| 9 | **Dark mode regressions** | Tests both brightness modes with proper `Theme` wrapping |

---

## Getting started

### 1. Install

```yaml
dev_dependencies:
  locale_sweep: ^0.3.0
```

### 2. Write a sweep test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  sweepTest(
    'onboarding',
    builder: () => const MyApp(),
    arbDir: 'lib/l10n',
  );
}
```

### 3. Run

```bash
# Generate golden baselines (run locally first)
dart run locale_sweep update

# Compare against baselines (run in CI)
dart run locale_sweep run
```

> `run` never regenerates goldens. `update` does. This prevents CI from silently accepting broken layouts.

---

## Dark mode

Enable `darkMode: true` to test every variant in both light and dark brightness:

```dart
sweepTest(
  'settings',
  builder: () => const SettingsPage(),
  darkMode: true,
  lightTheme: AppTheme.light,  // optional — defaults to ThemeData.light()
  darkTheme: AppTheme.dark,    // optional — defaults to ThemeData.dark()
);
```

Also configurable via YAML: `dark_mode: true`

---

## Screenshot diffing

Set `tolerance` to allow minor pixel differences (anti-aliasing, CI rendering jitter) without masking real regressions:

```dart
sweepTest(
  'settings',
  builder: () => const SettingsPage(),
  tolerance: 0.5, // allow up to 0.5% pixel difference
);
```

Also configurable via YAML: `tolerance: 0.5`

When pixels differ, a 3-panel diff image (Golden | Actual | Diff) is saved to `.locale_sweep/diffs/`. Diff data flows into all report formats — percentage column in Markdown, badge + link in HTML, structured object in JSON.

---

## Variant callbacks

Run interactions after the widget is pumped. Use `body` for simple cases, `variantBody` when you need the current locale/brightness/direction:

```dart
sweepTest(
  'checkout',
  builder: () => const CheckoutPage(),
  body: (tester) async {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  },
  // or: variantBody: (tester, variant) async { ... }
);
```

---

## Skipping variants

Exclude specific combinations from the matrix:

```dart
sweepTest(
  'settings',
  builder: () => const SettingsPage(),
  skip: (variant) {
    if (variant.locale == 'ja' && variant.textScale == 2.0) return true;
    if (variant.isDark && variant.viewport == ViewportPreset.tablet) return true;
    return false;
  },
);
```

---

## Configuration

### YAML config

Create `locale_sweep.yaml` for shared defaults:

```yaml
locales: [en, de, ar, ja]
text_scales: [1.0, 2.0]
viewports:
  - { name: "375x667", width: 375, height: 667 }
  - { name: "768x1024", width: 768, height: 1024 }
dark_mode: true
tolerance: 0.5
arb_dir: lib/l10n
screenshot_dir: .locale_sweep/screenshots
report_dir: .locale_sweep/reports
```

Any parameter passed directly to `sweepTest()` overrides the YAML config for that flow. Config validation warns about typos and type mismatches on stderr.

---

## Reports

Three formats generated on every run:

- **HTML** — self-contained dashboard with filters, screenshot gallery, summary cards, dark/RTL badges
- **Markdown** — failure table with locale summary, ideal for PR comments
- **JSON** — machine-readable results for custom dashboards or trend tracking

### Output structure

```
.locale_sweep/
  reports/
    report.html
    report.md
    report.json
  screenshots/
    onboarding_en_393x852.png
    onboarding_en_dark_393x852.png
    onboarding_de_2.0x_393x852.png
    ...
  diffs/
    onboarding_de_393x852_diff.png
    ...
  results/
    onboarding.json
    settings.json
```

---

## CI integration

### GitHub Actions

```yaml
- name: LocaleSweep
  run: dart run locale_sweep run --github-pr
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### `--fail-on`

Control which categories trigger a non-zero exit code:

```bash
dart run locale_sweep run --fail-on overflow,golden   # only these categories fail
dart run locale_sweep run --fail-on none              # report-only mode
dart run locale_sweep run --fail-on all               # everything (default)
```

Categories: `overflow`, `arb`, `golden`, `all`, `none`

### CLI reference

```bash
dart run locale_sweep run                                 # Compare goldens
dart run locale_sweep run --flows onboarding,checkout     # Specific flows
dart run locale_sweep run --github-pr                     # Post PR comment
dart run locale_sweep run --fail-on overflow,golden       # Selective failure
dart run locale_sweep run --config my_config.yaml         # Custom config
dart run locale_sweep run --verbose                       # Print flutter test output
dart run locale_sweep update                              # Regenerate baselines
dart run locale_sweep update --flows settings             # Update specific flows
```

---

## API reference

### `sweepTest()` parameters

| Parameter | Type | Default | Description |
|:--|:--|:--|:--|
| `flowName` | `String` | required | Identifies this flow in test labels and filenames |
| `builder` | `Widget Function()` | required | The widget to render |
| `body` | `Future<void> Function(WidgetTester)?` | `null` | Interactions after the widget is pumped |
| `variantBody` | `Future<void> Function(WidgetTester, SweepVariant)?` | `null` | Like `body`, but receives the current variant |
| `locales` | `List<String>?` | from config | BCP-47 locale codes |
| `textScales` | `List<double>?` | from config | Text scale factors |
| `viewports` | `List<ViewportPreset>?` | from config | Screen dimensions |
| `darkMode` | `bool?` | from config | Test both light and dark brightness |
| `lightTheme` / `darkTheme` | `ThemeData?` | Flutter defaults | Themes for brightness variants |
| `skip` | `bool Function(SweepVariant)?` | `null` | Exclude variants from the matrix |
| `arbDir` | `String?` | from config | Path to `.arb` files for static analysis |
| `tolerance` | `double?` | from config | Max pixel-diff % (0.0–100.0) |
| `captureScreenshots` | `bool` | `true` | Save golden screenshots |
| `diffOutputDir` | `String` | `.locale_sweep/diffs` | Directory for diff images |
| `screenshotDir` | `String` | from config | Directory for golden screenshots |

### `ViewportPreset` built-ins

| Preset | Dimensions |
|:--|:--|
| `phoneSmall` | 375 x 667 |
| `phone` | 393 x 852 |
| `phoneWide` | 412 x 915 |
| `tablet` | 768 x 1024 |

Custom: `ViewportPreset(name: '1280x800', width: 1280, height: 800)`

---

## Real-world validation

| App | Stars | Result |
|:--|:--|:--|
| **Spotube** | 48k+ | 0 issues across de/ar/ja/fr/es/ko/zh — **zero false positives** |
| **wger** | 960+ | **165 missing Arabic keys**, **1 placeholder mismatch**, **301 missing Hebrew keys** — all real bugs |

> Zero noise on complete translations. Real findings on incomplete ones.

---

202 tests across 11 files. [MIT License](https://opensource.org/licenses/MIT).
