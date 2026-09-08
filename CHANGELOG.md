## 0.5.0

- **Localizations integration** — new `localizationsDelegates` parameter on `sweepTest()`. Wraps the widget in a `Localizations` ancestor so `AppLocalizations.of(context)` works for individual screen tests without needing a full `MaterialApp`. Fallback Material/Widgets delegates are included automatically for all locales.
- **`baseLocale` config** — configurable base locale for ARB analysis. Set via `sweepTest(baseLocale:)`, YAML `base_locale:`, or `LOCALE_SWEEP_BASE_LOCALE` env var. Defaults to `'en'`.
- **`parseLocale()` helper** — proper BCP-47 locale parsing. Handles `en`, `en_US`, `pt-BR`, `zh_Hans`, `zh_Hans_CN`. Used internally and exported for user convenience.
- 320 tests total across 16 test files.

## 0.4.2

- **German umlaut fix** — screenshot gallery now renders proper umlauts (Übersetzungen, Prüfungen, Schlüssel, etc.) instead of ASCII fallbacks.
- **Japanese translations** — gallery screenshots use real Japanese text instead of untranslated English strings. Added NotoSansJP font for CJK rendering.
- **Version badge** — gallery screenshots updated from v0.1.1 to v0.4.1.

## 0.4.1

- **Example app** — 3 sweep tests across 8 locales (en, de, ar, ja, ko, he, th, hi) with intentional bugs: missing ARB keys, placeholder mismatches, untranslated strings, overflow layouts, RTL issues.
- **Arabic RTL screenshot** — README gallery now shows real Arabic text with mirrored layout instead of Config screen. Added NotoNaskhArabic font for proper rendering.
- **pub.dev Example tab** — updated `example.dart` with 64-variant sweep (8 locales × 2 scales × 2 viewports × 2 brightness).

## 0.4.0

- **Parallel sharding** — `--shards N --shard-index I` CLI flags split variant matrices across CI jobs. Passes through to `flutter test --total-shards/--shard-index`.
- **Merge command** — `locale_sweep merge -i shard_0 -i shard_1` combines shard reports into a single HTML/Markdown/JSON report. Supports `--github-pr` and `--fail-on`.
- **Monorepo support** — `locale_sweep scan` auto-discovers packages with `test/sweep/` dirs (checks `melos.yaml` first). `--packages apps/auth,apps/dashboard` runs sweep across multiple packages with merged reporting.
- **Landscape presets** — 4 new presets: `phoneSmallLandscape` (667x375), `phoneLandscape` (852x393), `phoneWideLandscape` (915x412), `tabletLandscape` (1024x768).
- **CLI progress** — real-time pass/fail counts during `flutter test` runs.
- **Environment overrides** — `LOCALE_SWEEP_LOCALES`, `LOCALE_SWEEP_TOLERANCE`, etc. for CI without modifying YAML.
- **setUp callback** — `sweepTest(setUp: () async { ... })` for loading custom fonts before the sweep group.
- **CLI parser extracted** — testable `cli_parser.dart` library with 43 new tests.
- **Bug fix** — ARB analyzer false positives on ICU plural/select syntax (`{count, plural, ...}`).
- **Bug fix** — CLI crash from transitive `dart:ui` dependency. Extracted `DiffResult` and `OverflowError` into pure-Dart files.
- **Bug fix** — removed `http` package dependency. `GitHubReporter` uses `dart:io` `HttpClient` directly.
- 283 tests total across 14 test files.

## 0.3.0

- **Screenshot diffing** — pixel-level diff via `GoldenDiffer.computeDiff()`. Per-channel threshold of 2 absorbs anti-aliasing jitter.
- **Tolerance** — `tolerance` parameter on `sweepTest()` and in `locale_sweep.yaml`. Screenshots within tolerance pass even when pixels differ.
- **Diff images** — 3-panel side-by-side (Golden | Actual | Diff) saved to `.locale_sweep/diffs/`. Changed pixels highlighted in magenta.
- **Diff in reports** — Diff % column in Markdown, diff badge + link in HTML, structured object in JSON.
- **DiffResult model** — `diffPercent`, `changedPixels`, `totalPixels`, `diffImagePath` with full JSON serialization.
- **Config** — `tolerance` key in YAML, `tolerance` and `diffOutputDir` params on `sweepTest()`.
- 202 tests total across 11 test files.

## 0.2.0

- **Dark mode** — `darkMode: true` on `sweepTest()` tests every variant in both light and dark brightness. Optional `lightTheme`/`darkTheme` params.
- **Variant exclusion** — `skip` callback to exclude specific locale/scale/viewport/brightness combos.
- **HTML report** — self-contained dashboard with dark theme, summary cards, screenshot gallery, interactive filters, locale summary table.
- **--fail-on** — CLI flag for selective failure categories (`overflow`, `arb`, `golden`, `all`, `none`).
- **Config validation** — warns on unknown keys (typos) and type mismatches. Falls back to defaults.
- **File-based results** — each flow writes JSON to `.locale_sweep/results/`. Isolate-safe, no global state.
- 167 tests total.

## 0.1.7

- Updated README with variantBody examples, SweepVariant API docs, untranslated detection docs.

## 0.1.6

- Auto-published on 2026-09-03.

## 0.1.5

- Expanded RTL locale detection: 10 locales (ar, he, fa, ur, ku, ps, yi, dv, sd, ug) with subtag support (e.g. ar_EG).
- CLI now reads `locale_sweep.yaml` config file via `--config` flag.
- CLI uses `GitHubReporter` for PR comments instead of duplicate HTTP logic.
- Added `variantBody` callback to `sweepTest()` for locale-aware test interactions.
- Added `ArbIssueType.untranslated` detection for strings identical to the base locale.

## 0.1.4

- Fixed Dart SDK constraint from ^3.11.5 to ^3.8.0 for broader compatibility.
- Centered title and badges on pub.dev README.
- Updated CI workflows to Flutter 3.41.9.

## 0.1.3

- Rewrote README for pub.dev compatibility — pure Markdown, proper image alignment.
- Added CI and auto-publish GitHub Actions workflows.

## 0.1.2

- Updated README with professional layout and screenshot gallery.
- Fixed GitHub repository URLs in pubspec.yaml.

## 0.1.1

- Add dartdoc comments to all public API elements.
- Add `example/example.dart` for pub.dev example tab.
- Real-world validation: tested against Spotube (48k stars) and wger (960 stars).

## 0.1.0

- Initial release.
- `sweepTest()` generates `locales × textScales × viewports` test matrix.
- `OverflowDetector` captures RenderFlex overflow with pixel counts.
- `ArbAnalyzer` detects missing ARB keys and placeholder mismatches.
- Golden screenshot comparison (`run` vs `update` commands).
- Markdown and JSON report generation.
- GitHub PR comment integration.
- Built-in viewport presets: phone, phoneSmall, phoneWide, tablet.
- RTL auto-detection for Arabic, Hebrew, and Farsi.
