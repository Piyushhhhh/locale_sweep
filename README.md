<div align="center">

# LocaleSweep

**Localization QA for Flutter — automated.**

One function call. Every locale, viewport, text scale, and brightness. Screenshots + reports.

[![pub.dev](https://img.shields.io/pub/v/locale_sweep.svg?style=for-the-badge&color=E91E63)](https://pub.dev/packages/locale_sweep)
[![pub points](https://img.shields.io/pub/points/locale_sweep?style=for-the-badge&color=E91E63&label=pub%20points)](https://pub.dev/packages/locale_sweep/score)
[![License: MIT](https://img.shields.io/badge/license-MIT-E91E63.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Flutter 3.32+](https://img.shields.io/badge/flutter-%E2%89%A53.32-E91E63.svg?style=for-the-badge)](https://flutter.dev)

</div>

| English | German | Arabic RTL | 2x Scale |
|:---:|:---:|:---:|:---:|
| <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_en_393x852.png?v=7" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_de_393x852.png?v=7" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_ar_393x852.png?v=7" width="180" /> | <img src="https://raw.githubusercontent.com/Piyushhhhh/locale_sweep/main/docs/gallery/onboarding_en_2.0x_393x852.png?v=7" width="180" /> |

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
| 2 | **Missing ARB keys** | Keys in `app_en.arb` absent from target locale files, plus ARB files that can't be read (invalid JSON) |
| 3 | **Placeholder mismatches** | `{count}`, `{name}` etc. missing in translations, or added by them (`{nmae}`), even without `@key` metadata |
| 4 | **Untranslated strings** | Strings identical to the base locale — likely never translated |
| 5 | **Golden regression** | Pixel-level comparison against committed baselines |
| 6 | **Screenshot diffing** | Pixel-diff %, 3-panel side-by-side images, configurable tolerance |
| 7 | **Accessibility scaling** | Renders at 2x text scale to catch layouts that break for large-text users |
| 8 | **RTL layout** | Auto-detects 10 RTL locales (ar, he, fa, ur, ku, ps, yi, dv, sd, ug) including subtags |
| 9 | **Dark mode regressions** | Tests both brightness modes with proper `Theme` wrapping |
| 10 | **Text truncation** | Walks the render tree to find silently truncated text (ellipsis, clip, fade) — translated strings that fit the container but lose content |
| 11 | **Layouts that break before translations arrive** | A `pseudo` locale renders longer, accented text (`[Šéţţîñĝš one two]`) so overflow and truncation show up on day one |
| 12 | **Hardcoded strings** | Flags rendered text that matches no ARB message — copy that was never localized |

---

## Getting started

### 1. Install

```yaml
dev_dependencies:
  locale_sweep: ^0.8.2
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

### Custom fonts

By default, Flutter tests use the Ahem font (all squares). Pass `setUp` to load your app's fonts so screenshots look real:

```dart
sweepTest(
  'onboarding',
  builder: () => const MyApp(),
  setUp: () async {
    final font = rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final loader = FontLoader('Roboto')..addFont(font);
    await loader.load();
  },
);
```

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

## Pseudo-localization

Translations usually arrive late, but layout bugs can be caught now. Add the
`pseudo` locale to the matrix:

```dart
sweepTest(
  'settings',
  builder: () => const MyApp(),
  locales: ['en', 'pseudo'],
);
```

Pseudo variants render your base locale, then rewrite every visible string
before the checks run:

```
Settings      →  [Šéţţîñĝš one two]
Save changes  →  [Šáṽé çĥáñĝéš one two three]
```

- **Longer text** (+30% for long strings, up to +100% for short labels, the
  way real translations grow) exposes overflows and truncations.
- **Accented letters** reveal clipped ascenders and diacritics.
- **Brackets** make cut-off strings obvious in screenshots: a missing `]` means
  the text was truncated.

It works with any localization library because it rewrites the rendered text,
not your translation files. Numbers, icons and text without letters are left
alone. Widgets that rebuild after the screen settles show their original text
again.

## Hardcoded text detection

Find user-facing strings that never went through localization:

```dart
sweepTest(
  'settings',
  builder: () => const MyApp(),
  arbDir: 'lib/l10n',
  detectHardcodedText: true,
  hardcodedTextAllowlist: [r'^TaskFlow$'], // brand names, user data
);
```

Every rendered string is matched against the ARB messages for the variant's
locale, its language (`pt` for `pt_BR`) and the base locale. Placeholders match
any value, and each `plural` / `select` branch is understood, so
`{count, plural, one{# item} other{# items}}` matches `3 items`. Anything that
matches no message is reported as hardcoded text:

```
Hardcoded text: "Buy now" matches no ARB message for de
```

Messages without any literal text, such as `"userName": "{name}"`, can't tell
user data from hardcoded copy, so they never count as a match. Add patterns for
names and other data to `hardcodedTextAllowlist`. Strings built by joining
translations in code (`'${l10n.hello}, $name'`) are reported too. They usually need a single message with a placeholder instead.
Hardcoded text is advisory, like truncations (see [`--fail-on`](#--fail-on)).
Also configurable via YAML (`hardcoded_text: true`).

## Localizations integration

Test individual screens with `AppLocalizations.of(context)` — no `MaterialApp` wrapper needed:

```dart
sweepTest(
  'settings',
  builder: () => const SettingsScreen(),  // just the screen, not the full app
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  locales: ['en', 'de', 'ar', 'ja'],
  arbDir: 'lib/l10n',
);
```

LocaleSweep wraps the widget in a `Localizations` ancestor with your delegates, sets the locale per variant, and includes Material/Widgets fallback delegates automatically. Your screen's `AppLocalizations.of(context)` calls work as if it were inside a `MaterialApp`.

### Passing the variant locale directly

If your screens read the locale from `MaterialApp` (rather than an injected
`Localizations` ancestor), use `builderWithVariant` to hand the variant's locale
to your own app shell:

```dart
sweepTest(
  'settings',
  builderWithVariant: (variant) =>
      MyApp(locale: parseLocale(variant.renderLocale)),
  locales: ['en', 'de', 'ar', 'ja'],
);
```

This avoids relying on platform locale resolution, which depends on the host
machine's locale list and can silently render the wrong language. Use
`variant.renderLocale` rather than `variant.locale`, so
[pseudo-localized](#pseudo-localization) variants render the base locale.

### Capture-only screenshots

Set `compareScreenshots: false` to write PNGs for the report without asserting
against golden baselines. This is useful when screenshots are for diagnosis only
(for example, under Flutter's Ahem test font, where pixel diffs are not
meaningful):

```dart
sweepTest(
  'settings',
  builder: () => const SettingsScreen(),
  captureScreenshots: true,
  compareScreenshots: false,
);
```

### Base locale

By default, ARB analysis compares against `app_en.arb`. For non-English base locales:

```dart
sweepTest(
  'settings',
  builder: () => const SettingsScreen(),
  baseLocale: 'de',  // compare other locales against German
);
```

Also configurable via YAML (`base_locale: de`) or env var (`LOCALE_SWEEP_BASE_LOCALE=de`).

### Using with `flutter gen-l10n`

Most Flutter apps use `flutter gen-l10n` to generate `AppLocalizations`. Here's how to wire it up:

**Option 1: Full MaterialApp** (tests the screen inside its normal app shell)

```dart
sweepTest(
  'home',
  builder: () => const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HomeScreen(),
  ),
  locales: ['en', 'de', 'ar', 'ja'],
  arbDir: 'lib/l10n',
);
```

**Option 2: Screen in isolation** (faster, tests just the screen with `localizationsDelegates`)

```dart
sweepTest(
  'settings',
  builder: () => const SettingsScreen(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  locales: ['en', 'de', 'ar', 'ja'],
  arbDir: 'lib/l10n',
);
```

Option 2 skips the `MaterialApp` overhead and tests the screen directly. LocaleSweep injects the `Localizations` ancestor, so `AppLocalizations.of(context)!` works in both cases.

> See the [example app](https://github.com/Piyushhhhh/locale_sweep/tree/main/example) for a full `gen-l10n` setup with 8 locales and intentional bugs.

### Using with slang

[slang](https://pub.dev/packages/slang) uses a different file format than ARB, so the static analysis checks (missing keys, placeholders, untranslated strings) don't work against slang files directly. The runtime checks (overflow, RTL, dark mode, text scale, goldens) work out of the box since they're format-agnostic.

To get static analysis, use slang's built-in ARB export as a bridge:

```bash
# Export slang translations to ARB format
dart run slang:export --format arb --output lib/l10n/arb
```

Then point `arbDir` at the exported files:

```dart
sweepTest(
  'settings',
  builder: () => const SettingsScreen(),
  arbDir: 'lib/l10n/arb',  // slang's exported ARB files
);
```

This gives you the full static analysis (missing keys, placeholder mismatches, untranslated strings) on top of the runtime sweep. Re-export after updating translations to keep the checks in sync.

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

Every comparison produces diff data, including the default `tolerance: 0` (where
any pixel difference is a failure). When pixels differ, a 3-panel diff image
(Golden | Actual | Diff) is saved to `.locale_sweep/diffs/`. Diff data flows into
all report formats — percentage column in Markdown, badge + link in HTML,
structured object in JSON.

Golden comparison never writes the image it captured, so a failing variant also
writes its actual PNG to `.locale_sweep/actual/` and the reports link to it. That
is what gives a first run (no baselines yet) screenshot proof instead of
"No screenshot" everywhere. Baselines are never overwritten.

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
base_locale: en
# Values that are intentionally identical across locales (app name, language
# self-names): exempt from the "untranslated" check, still checked for missing
# keys and placeholder mismatches.
untranslated_allowlist: [appName]
# Report rendered text that matches no ARB message (needs arb_dir).
hardcoded_text: true
hardcoded_text_allowlist: ["^TaskFlow$"]
# ARB files may use locale subtags: app_zh_Hans.arb, app_es_419.arb, en.arb,
# app_en-US.arb are all recognized (previously only app_en.arb / app_en_US.arb).
screenshot_dir: .locale_sweep/screenshots
report_dir: .locale_sweep/reports
```

Any parameter passed directly to `sweepTest()` overrides the YAML config for that flow. Config validation warns about typos and type mismatches on stderr.

### Ignoring intentional truncations

Some truncations are by design — list-row cells clamp long data with
`maxLines: 1/2` + `ellipsis`, or a known ID pattern (`RCP-…`) is meant to be cut
off. Use declarative YAML rules to exclude them from reports and `--fail-on truncation`:

```yaml
truncation_ignore:
  # ignore any truncation whose maxLines is set and <= 2 (list-row ellipsis)
  - max_lines: 2
  # ignore truncations whose text matches a regex (e.g. known ID/brand patterns)
  - text_regex: "^(RCP-|INV-)"
  # ignore truncations of a specific overflow mode
  - overflow: ellipsis
```

A rule matches only when **all** of its fields match the issue; the issue is
ignored if **any** rule matches. `overflow` must be one of `ellipsis` / `clip` /
`fade` / `visible` (matching `TruncationIssue.overflowMode`).

A rule with an unknown key (a typo such as `text_regexp`) or an unsupported
`overflow` value is **skipped with a warning on stderr** rather than applied with
its remaining fields — otherwise a typo next to a valid `max_lines` would ignore
far more than intended.

For advanced cases that reference a widget type or key, pass `ignoreTruncation`
to `sweepTest` using the `TruncationIgnores` helpers:

```dart
sweepTest(
  'profile',
  builder: () => ProfileScreen(),
  ignoreTruncation: [
    TruncationIgnores.byWidgetType(ListCell),
    TruncationIgnores.byKey(const Key('brandTag')),
    TruncationIgnores.byText(RegExp(r'^RCP-')),
    TruncationIgnores.any([
      TruncationIgnores.byMaxLines(2),
      TruncationIgnores.byText(RegExp(r'^INV-')),
    ]),
  ],
);
```

> Note: `byWidgetType` / `byKey` rely on `RenderParagraph.debugCreator`,
> which Flutter populates only in debug/asserts builds (`flutter test`). In
> other builds those matchers simply won't match; `byMaxLines` / `byText` work
> everywhere since they inspect the issue data only.

### Environment variable overrides

Override any config value in CI without modifying YAML:

```bash
LOCALE_SWEEP_LOCALES=en,de LOCALE_SWEEP_TOLERANCE=1.0 dart run locale_sweep run
```

| Variable | Overrides |
|:--|:--|
| `LOCALE_SWEEP_CONFIG` | Path to the YAML config file (default `locale_sweep.yaml`; the CLI sets it from `--config`) |
| `LOCALE_SWEEP_LOCALES` | `locales` (comma-separated) |
| `LOCALE_SWEEP_TEXT_SCALES` | `text_scales` (comma-separated) |
| `LOCALE_SWEEP_DARK_MODE` | `dark_mode` (`true`/`false`) |
| `LOCALE_SWEEP_TOLERANCE` | `tolerance` |
| `LOCALE_SWEEP_SCREENSHOT_DIR` | `screenshot_dir` |
| `LOCALE_SWEEP_REPORT_DIR` | `report_dir` |
| `LOCALE_SWEEP_ARB_DIR` | `arb_dir` |
| `LOCALE_SWEEP_BASE_LOCALE` | `base_locale` |
| `LOCALE_SWEEP_UNTRANSLATED_ALLOWLIST` | `untranslated_allowlist` (comma-separated) |
| `LOCALE_SWEEP_HARDCODED_TEXT` | `hardcoded_text` (`true`/`false`) |

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
  actual/
    onboarding_de_393x852.png   # what a failing variant rendered
    ...
  runs/
    run_.../
      flutter.jsonl
      stderr.log
      results/
        flow_.../results.json
```

Each CLI invocation gets a separate run directory, so previous results cannot
leak into the current report. The 10 most recent run directories are kept.
Direct `flutter test` runs continue to write flow results under
`.locale_sweep/results/`.

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

Categories: `overflow`, `arb`, `golden`, `truncation`, `hardcoded`, `all`, `none`

Truncations and hardcoded text are advisory: they are reported but do not fail
a direct `flutter test` run or count towards the failed-variant total. Use
`--fail-on truncation` or `--fail-on hardcoded` to promote them; note that
`--fail-on all` (the CLI default) already includes both.

`--fail-on none` suppresses QA findings only. Compilation errors, broken test
setup or callbacks, incomplete runs, and unreadable result files always return
a non-zero exit code.

### Parallel sharding

Split large variant matrices across CI jobs for faster runs:

```yaml
# GitHub Actions matrix strategy
strategy:
  matrix:
    shard: [0, 1, 2]
steps:
  - run: dart run locale_sweep run --shards 3 --shard-index ${{ matrix.shard }} -o shard_${{ matrix.shard }}
  - uses: actions/upload-artifact@v4
    with:
      name: shard-${{ matrix.shard }}
      path: shard_${{ matrix.shard }}/

# Merge step (needs: [test])
- uses: actions/download-artifact@v4
- run: dart run locale_sweep merge -i shard_0 -i shard_1 -i shard_2 --github-pr
```

The `merge` command combines shard reports into a single HTML/Markdown/JSON report and optionally posts to the PR.

### Monorepo support

Run sweep tests across multiple packages in a monorepo:

```bash
# Auto-discover packages with test/sweep/ directories
dart run locale_sweep scan

# Run sweep in specific packages
dart run locale_sweep run --packages apps/auth,apps/dashboard

# Combine with sharding
dart run locale_sweep run --packages apps/auth,apps/dashboard --shards 4 --shard-index 0
```

Auto-discovery checks for `melos.yaml` first, then scans for packages containing a `test/sweep/` directory. Reports are generated per-package and merged into a single aggregate report.

### CLI reference

```bash
dart run locale_sweep run                                 # Compare goldens
dart run locale_sweep run --flows onboarding,checkout     # Specific flows
dart run locale_sweep run --github-pr                     # Post PR comment
dart run locale_sweep run --fail-on overflow,golden       # Selective failure
dart run locale_sweep run --config my_config.yaml         # Custom config
dart run locale_sweep run --test-dir test/l10n            # Sweep tests outside test/sweep
dart run locale_sweep run --verbose                       # Print flutter test output
dart run locale_sweep run --timeout 600                   # Kill the run after 10 min
dart run locale_sweep run --shards 3 --shard-index 0      # Parallel shard
dart run locale_sweep run --packages apps/a,apps/b        # Monorepo
dart run locale_sweep update                              # Regenerate baselines
dart run locale_sweep update --flows settings             # Update specific flows
dart run locale_sweep merge -i shard_0 -i shard_1         # Merge shard reports
dart run locale_sweep scan                                # Discover monorepo packages
dart run locale_sweep scan --root packages                # Discover under a subfolder
```

---

## API reference

### `sweepTest()` parameters

| Parameter | Type | Default | Description |
|:--|:--|:--|:--|
| `flowName` | `String` | required | Identifies this flow in test labels and filenames |
| `builder` | `Widget Function()?` | required* | The widget to render |
| `builderWithVariant` | `Widget Function(SweepVariant)?` | required* | Like `builder`, but receives the current variant (pass its locale directly to `MaterialApp`). Exactly one of `builder` / `builderWithVariant` must be provided |
| `body` | `Future<void> Function(WidgetTester)?` | `null` | Interactions after the widget is pumped |
| `variantBody` | `Future<void> Function(WidgetTester, SweepVariant)?` | `null` | Like `body`, but receives the current variant |
| `locales` | `List<String>?` | from config | BCP-47 locale codes, plus `pseudo` for pseudo-localization |
| `textScales` | `List<double>?` | from config | Text scale factors |
| `viewports` | `List<ViewportPreset>?` | from config | Screen dimensions |
| `darkMode` | `bool?` | from config | Test both light and dark brightness |
| `lightTheme` / `darkTheme` | `ThemeData?` | Flutter defaults | Themes for brightness variants |
| `skip` | `bool Function(SweepVariant)?` | `null` | Exclude variants from the matrix |
| `config` | `SweepConfig?` | loaded from YAML | Explicit configuration instead of `locale_sweep.yaml`. Other parameters still override it |
| `arbDir` | `String?` | from config | Path to `.arb` files for static analysis |
| `baseLocale` | `String?` | from config | Base locale for ARB analysis (default: `'en'`) |
| `untranslatedAllowlist` | `List<String>?` | from config | ARB keys exempt from the `untranslated` check |
| `localizationsDelegates` | `List<LocalizationsDelegate>?` | `null` | Wraps widget in `Localizations` for `AppLocalizations.of(context)` |
| `tolerance` | `double?` | from config | Max pixel-diff % (0.0–100.0) |
| `captureScreenshots` | `bool` | `true` | Save screenshots |
| `compareScreenshots` | `bool` | `true` | Assert captured screenshots against golden baselines. Set `false` for capture-only (no golden assertions) |
| `diffOutputDir` | `String` | `.locale_sweep/diffs` | Directory for diff images |
| `setUp` | `Future<void> Function()?` | `null` | Runs once before the sweep group (e.g. load custom fonts) |
| `screenshotDir` | `String` | from config | Directory for golden screenshots |
| `ignoreTruncation` | `List<TruncationIgnore>?` | from config | Predicates (incl. `TruncationIgnores` helpers) that exclude intentional truncations from the report |
| `detectHardcodedText` | `bool?` | from config (`false`) | Report rendered text that matches no ARB message. Requires `arbDir` |
| `hardcodedTextAllowlist` | `List<String>?` | from config | Regular expressions for rendered text that is intentionally not translated |

### `ViewportPreset` built-ins

| Preset | Dimensions |
|:--|:--|
| `phoneSmall` | 375 x 667 |
| `phone` | 393 x 852 |
| `phoneWide` | 412 x 915 |
| `tablet` | 768 x 1024 |
| `phoneSmallLandscape` | 667 x 375 |
| `phoneLandscape` | 852 x 393 |
| `phoneWideLandscape` | 915 x 412 |
| `tabletLandscape` | 1024 x 768 |

Custom: `ViewportPreset(name: '1280x800', width: 1280, height: 800)`

---

## Real-world validation

| App | Stars | Result |
|:--|:--|:--|
| **Spotube** | 48k+ | 0 issues across de/ar/ja/fr/es/ko/zh — **zero false positives** |
| **wger** | 960+ | **165 missing Arabic keys**, **1 placeholder mismatch**, **301 missing Hebrew keys** — all real bugs |

> Zero noise on complete translations. Real findings on incomplete ones.

---

463 tests across 29 files. [Full changelog](CHANGELOG.md). [MIT License](https://opensource.org/licenses/MIT).
