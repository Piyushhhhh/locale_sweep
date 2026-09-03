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

Your app looks perfect in English. Then a German user opens Settings and *"Benachrichtigungseinstellungen"* overflows the row. An Arabic user sees left-aligned text. A Japanese user hits an untranslated screen. You find out from a 1-star review.

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
| 1 | **Text overflow** | Intercepts `RenderFlex` overflow errors — German compound words, Arabic text expansion, CJK line wrapping |
| 2 | **Missing ARB keys** | Finds keys present in `app_en.arb` but absent in target locale ARB files |
| 3 | **Placeholder mismatches** | Verifies `{count}`, `{name}`, etc. from base locale appear in every translation |
| 4 | **Untranslated strings** | Flags keys where the translation is identical to the base locale — likely copy-paste that was never translated |
| 5 | **Golden regression** | Pixel-level comparison against committed baselines — catches unintended visual changes |
| 6 | **Accessibility scaling** | Renders at 2x text scale to catch layouts that break for large-text users |
| 7 | **RTL layout** | Auto-detects 10 RTL locales (Arabic, Hebrew, Farsi, Urdu, Kurdish, Pashto, Yiddish, Dhivehi, Sindhi, Uyghur) — including subtags like `ar_EG` |
| 8 | **Dark mode regressions** | Tests both light and dark brightness with proper `Theme` wrapping — catches hardcoded colors and contrast issues |

---

## Getting started

### 1. Install

```yaml
dev_dependencies:
  locale_sweep: ^0.1.7
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

> `run` never regenerates goldens. `update` does. This prevents CI from silently accepting broken layouts as the new baseline.

---

## Dark mode testing

Enable `darkMode: true` to automatically test every variant in both light and dark brightness. LocaleSweep wraps your widget in a `Theme` so `Theme.of(context)` works correctly inside your builder.

```dart
sweepTest(
  'settings',
  builder: () => const SettingsPage(),
  darkMode: true,
);
// Each locale/scale/viewport variant is now tested in both light and dark
```

### Custom themes

Pass your app's actual ThemeData to catch real theme-specific issues:

```dart
sweepTest(
  'settings',
  builder: () => const SettingsPage(),
  darkMode: true,
  lightTheme: AppTheme.light,   // your ThemeData.light() variant
  darkTheme: AppTheme.dark,     // your ThemeData.dark() variant
);
```

When `darkMode` is enabled without custom themes, LocaleSweep uses `ThemeData.light()` and `ThemeData.dark()` as defaults. When `darkMode` is disabled (the default), no Theme wrapper is added unless you explicitly pass a theme.

You can also enable dark mode globally in `locale_sweep.yaml`:

```yaml
dark_mode: true
```

---

## Variant callbacks

### `body` — simple interactions

Run taps, scrolls, or assertions after the widget is pumped:

```dart
sweepTest(
  'onboarding',
  builder: () => const MyApp(),
  body: (tester) async {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  },
);
```

### `variantBody` — locale-aware interactions

Receives the current `SweepVariant` so you can write assertions per locale, direction, or brightness:

```dart
sweepTest(
  'checkout',
  builder: () => const CheckoutPage(),
  darkMode: true,
  variantBody: (tester, variant) async {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    if (variant.isRtl) {
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    }

    if (variant.isDark) {
      final theme = Theme.of(tester.element(find.byType(CheckoutPage)));
      expect(theme.brightness, Brightness.dark);
    }
  },
);
```

---

## Skipping variants

Exclude specific combinations from the test matrix using the `skip` callback. Useful for known issues, platform-specific flows, or reducing CI time:

```dart
sweepTest(
  'settings',
  builder: () => const SettingsPage(),
  locales: ['en', 'de', 'ar', 'ja'],
  textScales: [1.0, 2.0],
  darkMode: true,
  skip: (variant) {
    // Skip Japanese at 2x — known issue, tracked in JIRA-1234
    if (variant.locale == 'ja' && variant.textScale == 2.0) return true;
    // Skip dark mode for tablet — not supported yet
    if (variant.isDark && variant.viewport == ViewportPreset.tablet) return true;
    return false;
  },
);
```

Skipped variants appear as `~` (skipped) in Flutter's test output, not as failures.

---

## Configuration

### YAML config

Create `locale_sweep.yaml` in your project root for shared defaults:

```yaml
locales: [en, de, ar, ja]
text_scales: [1.0, 2.0]

viewports:
  - { name: "375x667", width: 375, height: 667 }
  - { name: "768x1024", width: 768, height: 1024 }

dark_mode: true
arb_dir: lib/l10n
screenshot_dir: .locale_sweep/screenshots
report_dir: .locale_sweep/reports
```

### Per-flow overrides

Any parameter passed directly to `sweepTest()` overrides the YAML config for that flow:

```dart
sweepTest(
  'checkout',
  builder: () => const CheckoutPage(),
  locales: ['en', 'de'],        // override — only test 2 locales for this flow
  textScales: [1.0, 1.5, 2.0],  // override — 3 scales instead of 2
  viewports: [ViewportPreset.phoneSmall],
  arbDir: 'lib/l10n',
);
```

### Config validation

LocaleSweep warns on stderr about typos and type mismatches in your YAML config, so silent misconfiguration doesn't waste CI runs:

```
Warning: Unknown keys in locale_sweep.yaml: locale, text_scale
Valid keys: locales, text_scales, viewports, dark_mode, screenshot_dir, report_dir, arb_dir

Warning: "locales" in locale_sweep.yaml should be a list, got String.
```

Invalid YAML or missing files fall back to sensible defaults.

---

## Reports

LocaleSweep generates three report formats in every run:

### HTML report

A self-contained, interactive HTML file with a dark theme, summary dashboard, screenshot gallery, and filters. Open it locally in any browser — no server required.

- **Summary cards** — total, passed, failed, overflows, ARB issues at a glance
- **Interactive filters** — filter by status (pass/fail), locale, and flow
- **Screenshot gallery** — cards grouped by flow, each with golden image, pass/fail badge, and issue details
- **Dark mode badges** — dark variants are clearly labeled with a `DARK` badge
- **RTL badges** — right-to-left variants are labeled with an `RTL` badge
- **Locale summary table** — per-locale pass/fail breakdown with failure row highlighting

### Markdown report

A concise failure table with locale summary — ideal for GitHub PR comments, commit notes, or quick scanning in the terminal.

### JSON report

Machine-readable output with every result, variant detail, overflow error, and ARB issue. Useful for custom dashboards, CI integrations, or trend tracking.

### Output structure

```
.locale_sweep/
  reports/
    report.html               # Interactive HTML dashboard
    report.md                 # Markdown failure table + locale summary
    report.json               # Machine-readable results
  screenshots/
    onboarding_en_393x852.png
    onboarding_en_dark_393x852.png
    onboarding_de_2.0x_393x852.png
    onboarding_ar_768x1024.png
    settings_en_375x667.png
    ...
  results/
    onboarding.json           # Per-flow result data (used by CLI)
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

Posts a PR comment with a failure table, locale summary, and screenshot links. Updates the same comment on re-runs.

### `--fail-on` — control what fails CI

By default, any issue (overflow, ARB, golden mismatch) fails the run. Use `--fail-on` to control which categories trigger a non-zero exit code:

```bash
# Only fail on overflows and golden mismatches — treat ARB issues as warnings
dart run locale_sweep run --fail-on overflow,golden

# Fail on everything (default)
dart run locale_sweep run --fail-on all

# Never fail — report-only mode, useful for initial adoption
dart run locale_sweep run --fail-on none

# Only fail on ARB translation issues
dart run locale_sweep run --fail-on arb
```

Categories: `overflow`, `arb`, `golden`, `all`, `none`

### `screenshotLinkBuilder` — fix broken CI screenshot links

In CI environments, local screenshot paths don't work in PR comments. Use `screenshotLinkBuilder` on the report generator to customize how paths are rendered:

```dart
final md = ReportGenerator.generateMarkdown(
  summary,
  screenshotLinkBuilder: (path) {
    final filename = path.split('/').last;
    return '`$filename`';  // or link to your artifact storage
  },
);
```

The `GitHubReporter` uses this automatically to render filenames instead of broken image links.

### CLI reference

```bash
dart run locale_sweep run                                 # Compare goldens, fail broken variants
dart run locale_sweep run --flows onboarding,checkout     # Run specific flows only
dart run locale_sweep run --github-pr                     # Post results as a PR comment
dart run locale_sweep run --fail-on overflow,golden       # Only fail on specific categories
dart run locale_sweep run --fail-on none                  # Report-only mode
dart run locale_sweep run --config my_config.yaml         # Use a custom config file
dart run locale_sweep run --verbose                       # Print flutter test output
dart run locale_sweep update                              # Regenerate golden baselines
dart run locale_sweep update --flows settings             # Update specific flows only
```

---

## Screenshot gallery

Every variant gets its own golden PNG — locale, text scale, viewport, and brightness encoded in the filename.

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

## API reference

### `sweepTest()` parameters

| Parameter | Type | Default | Description |
|:--|:--|:--|:--|
| `flowName` | `String` | required | Identifies this flow in test labels and screenshot filenames |
| `builder` | `Widget Function()` | required | The widget to render |
| `body` | `Future<void> Function(WidgetTester)?` | `null` | Interactions to run after the widget is pumped |
| `variantBody` | `Future<void> Function(WidgetTester, SweepVariant)?` | `null` | Like `body`, but also receives the current variant for locale-aware assertions |
| `locales` | `List<String>?` | from config | BCP-47 locale codes (e.g. `'en'`, `'de'`, `'ar'`, `'ar_EG'`) |
| `textScales` | `List<double>?` | from config | Text scale factors to test |
| `viewports` | `List<ViewportPreset>?` | from config | Screen dimensions to test |
| `darkMode` | `bool?` | from config | Test both light and dark brightness for every variant |
| `lightTheme` | `ThemeData?` | `ThemeData.light()` | Theme for light variants (only applied when `darkMode` is enabled) |
| `darkTheme` | `ThemeData?` | `ThemeData.dark()` | Theme for dark variants (only applied when `darkMode` is enabled) |
| `skip` | `bool Function(SweepVariant)?` | `null` | Return `true` to exclude a variant from the test matrix |
| `arbDir` | `String?` | from config | Path to `.arb` translation files for static analysis |
| `captureScreenshots` | `bool` | `true` | Whether to save golden screenshots |
| `config` | `SweepConfig?` | auto-loaded | Override the entire config for this flow |
| `screenshotDir` | `String` | from config | Directory for golden screenshots |

### `ViewportPreset` built-in presets

| Preset | Dimensions | Use case |
|:--|:--|:--|
| `ViewportPreset.phoneSmall` | 375 x 667 | iPhone SE, compact phones |
| `ViewportPreset.phone` | 393 x 852 | Standard modern phones |
| `ViewportPreset.phoneWide` | 412 x 915 | Tall/wide phones |
| `ViewportPreset.tablet` | 768 x 1024 | iPad, Android tablets |

Custom: `ViewportPreset(name: '1280x800', width: 1280, height: 800)`

### `SweepVariant` properties

Available in `variantBody` and `skip` callbacks:

| Property | Type | Description |
|:--|:--|:--|
| `locale` | `String` | BCP-47 locale code (e.g. `'ar'`, `'de'`, `'ar_EG'`) |
| `isRtl` | `bool` | Whether this locale is right-to-left |
| `isDark` | `bool` | Whether this variant is in dark brightness |
| `brightness` | `Brightness` | `Brightness.light` or `Brightness.dark` |
| `textDirection` | `TextDirection` | `TextDirection.rtl` or `TextDirection.ltr` |
| `textScale` | `double` | Current text scale factor |
| `viewport` | `ViewportPreset` | Current viewport dimensions |
| `displayLabel` | `String` | Human-readable label (e.g. `"AR · RTL · Dark · 2.0x scale · 393x852"`) |
| `label` | `String` | File-safe label used in screenshot filenames (e.g. `"ar_dark_2.0x_393x852"`) |

### `ReportGenerator` methods

| Method | Returns | Description |
|:--|:--|:--|
| `generateHtml(summary)` | `String` | Self-contained HTML dashboard with filters, gallery, and summary cards |
| `generateMarkdown(summary, {screenshotLinkBuilder})` | `String` | Markdown failure table with locale summary |
| `generateJson(summary)` | `String` | Machine-readable JSON with all results and issue details |

---

## How it works

| Step | What happens |
|:--|:--|
| **1** | `sweepTest()` expands `locales x scales x viewports x brightness` into individual `testWidgets` calls |
| **2** | Each test configures the Flutter test view with the target viewport, locale, text scale, and platform brightness |
| **3** | Your widget is pumped inside `Directionality` + `MediaQuery` + `Theme` wrappers |
| **4** | `OverflowDetector` hooks into `FlutterError.onError` to capture `RenderFlex` overflow |
| **5** | `matchesGoldenFile` saves or compares the screenshot |
| **6** | `ArbAnalyzer` runs static analysis on ARB JSON files — no rendering needed |
| **7** | Results are recorded **before** assertions — screenshots always exist, even for broken variants |
| **8** | Each flow writes results to `.locale_sweep/results/{flowName}.json` for CLI aggregation |

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

167 tests across 9 test files. Run with `flutter test`.

| Test file | Coverage |
|:--|:--|
| `arb_analyzer_test.dart` | Missing keys, placeholder mismatches, untranslated detection, metadata filtering |
| `overflow_detector_test.dart` | RenderFlex capture, pixel extraction, handler restore |
| `sweep_variant_test.dart` | RTL detection (10 locales + subtags), label formatting, screenshot paths |
| `report_test.dart` | JSON structure, markdown tables, locale summary, HTML report (structure, filters, badges, XSS escaping) |
| `sweep_integration_test.dart` | End-to-end: clean pass, broken ARB, matrix variant count |
| `p0_p1_verification_test.dart` | RTL expansion, config loading/validation, variantBody, skip callback, screenshotLinkBuilder, dark mode + Theme wrapping, untranslated strings |
| `full_integration_test.dart` | All features together: darkMode + skip + variantBody, config YAML parsing, all 3 report formats, brightness serialization, file-based sink, ARB + dark mode |
| `real_world_arb_test.dart` | Spotube + wger ARB analysis — zero false positives on real apps |
| `screenshot_demo_test.dart` | Gallery screenshot generation for onboarding + settings flows |

---

*MIT License*
