# LocaleSweep

Localization release QA for Flutter. Runs app flows across every locale, viewport size, text scale, and RTL mode, then fails only the broken variants with screenshot proof.

## What it catches

- **Text overflow** — German compound words, Arabic text, CJK characters that break layout at specific viewport sizes
- **Missing ARB keys** — keys present in your base locale but absent in target locale files
- **Placeholder mismatches** — `{count}` in English but missing in the German translation
- **Golden regression** — visual diff between committed baseline and current render
- **Accessibility scaling** — layouts that overflow at 200% text scale

Headless widget tests give you accurate Flutter layout at any viewport size. They do not reproduce native fonts, keyboard behavior, safe-area insets, or platform plugins — that is fine for catching localization regressions. For native-level testing, pair with device-farm integration tests.

## Quick start

Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  locale_sweep:
    git:
      url: https://github.com/AstrixelHQ/locale_sweep.git
```

Write a sweep test in `test/sweep/onboarding_test.dart`:

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
      expect(find.text('Welcome'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
    },
  );
}
```

Generate golden baselines locally:

```bash
dart run locale_sweep update
```

Then run checks in CI:

```bash
dart run locale_sweep run --flows onboarding
```

## CLI

```bash
# Compare goldens, fail broken variants
dart run locale_sweep run

# Run specific flows
dart run locale_sweep run --flows onboarding,checkout,settings

# Post results to GitHub PR (in CI)
dart run locale_sweep run --github-pr

# Regenerate golden baselines (local only, then commit)
dart run locale_sweep update
dart run locale_sweep update --flows onboarding
```

`run` compares against committed goldens and exits non-zero on any failure. `update` regenerates goldens — run it locally and commit the screenshots.

## Configuration

Create `locale_sweep.yaml` in your project root:

```yaml
locales:
  - en
  - de
  - ar
  - ja

text_scales:
  - 1.0
  - 2.0

viewports:
  - name: 375x667
    width: 375
    height: 667
  - name: 768x1024
    width: 768
    height: 1024

arb_dir: lib/l10n

screenshot_dir: .locale_sweep/screenshots
report_dir: .locale_sweep/reports
```

## ARB analysis

When `arbDir` is set, LocaleSweep parses your ARB files before running tests:

- **Missing keys** — keys in `app_en.arb` not found in `app_de.arb`
- **Placeholder mismatches** — `{count}` declared in the base locale's `@key` metadata but absent in the translated string

ARB issues are reported per-locale in the test output and PR summary. They do not require running the widget — the check is static.

## GitHub Actions

```yaml
- name: Run LocaleSweep
  run: dart run locale_sweep run --github-pr
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Posts a PR comment with a failure table and screenshot links. Updates the same comment on re-runs.

## sweepTest API

```dart
sweepTest(
  'flow_name',
  builder: () => const MyApp(),          // Widget to test
  body: (tester) async { ... },          // Interactions to run
  locales: ['en', 'de', 'ar'],           // Override default locales
  textScales: [1.0, 2.0],               // Override default scales
  viewports: [ViewportPreset.phone],     // Override default viewports
  arbDir: 'lib/l10n',                    // ARB directory for key/placeholder checks
  captureScreenshots: true,              // Save golden per variant
);
```

Each call generates `locales × scales × viewports` test cases. Overflow errors fail the variant. Golden mismatches fail the variant. ARB issues are reported per-locale.

Flows are defined by the developer — LocaleSweep does not auto-discover routes. This keeps the tool deterministic and fast.

## Output

```
.locale_sweep/
  report.md          # Markdown summary
  report.json        # Machine-readable results
  screenshots/
    onboarding_en_393x852.png
    onboarding_de_2.0x_393x852.png
    onboarding_ar_393x852.png
    ...
```

## Validation suite

The package includes fixture apps and a test suite that proves the tool works end to end.

### Fixtures

- `test/fixtures/broken_localized_app/` — intentionally broken: German missing ARB key (`settingsTitle`), Arabic missing `{count}` placeholder, layout that overflows, LTR-only padding
- `test/fixtures/clean_localized_app/` — correct ARB files for en/de/ar, all placeholders present, RTL-safe layout with `EdgeInsetsDirectional`, no overflow

### What the tests prove

| Test file | What it validates |
|-----------|-------------------|
| `arb_analyzer_test.dart` | Missing keys detected, placeholder mismatches detected, `@`-prefixed metadata keys ignored, clean fixture passes, missing directory/locale reported |
| `overflow_detector_test.dart` | Real `RenderFlex` overflow captured with pixel count, clean layout has no overflow, handler restored after uninstall, non-overflow errors passed through |
| `sweep_variant_test.dart` | RTL detection (ar/he/fa), LTR detection (en/de/ja), label formatting, screenshot path generation, viewport preset dimensions |
| `report_test.dart` | `report.json` contains flow, locale, viewport, textScale, issue type; `report.md` contains failure table with all fields; locale summary table |
| `sweep_integration_test.dart` | Clean fixture passes all variants, ARB issues appear per-locale in results, variant matrix is `locales × scales × viewports`, screenshot path assigned before overflow failure |

### Running the tests

```bash
# Run the full validation suite
flutter test

# Run a specific test file
flutter test test/arb_analyzer_test.dart
flutter test test/overflow_detector_test.dart

# Run with verbose output
flutter test --reporter expanded
```

### Running the CLI

```bash
# Compare golden screenshots (CI mode — fails on mismatch)
dart run locale_sweep run

# Regenerate golden baselines (local only — then commit the screenshots)
dart run locale_sweep update

# Run specific flows
dart run locale_sweep run --flows onboarding,checkout

# Post to GitHub PR
dart run locale_sweep run --github-pr
```

`run` never passes `--update-goldens` to `flutter test`. `update` is the only command that regenerates goldens. This prevents CI from silently accepting a broken layout as the new baseline.

### Important: viewport presets are layout simulations

Viewport presets (`ViewportPreset.phone`, `.tablet`, etc.) set the Flutter test view's `physicalSize` and `devicePixelRatio`. This gives you accurate Flutter layout at those dimensions. It does **not** reproduce native fonts, keyboard behavior, safe-area insets, or platform plugins. For native-level testing, pair with device-farm integration tests.

### Important: flows are defined by the developer

`sweepTest()` does not auto-discover routes. The developer defines each flow — the widget to render and the interactions to perform. This keeps the tool deterministic and fast.
