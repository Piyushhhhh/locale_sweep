## 0.3.0

### Screenshot diffing
- Added pixel-level diff computation between golden and actual screenshots via `GoldenDiffer.computeDiff()`.
- Per-channel threshold of 2 absorbs anti-aliasing jitter — only real visual changes are flagged.
- Added `tolerance` parameter to `sweepTest()` and `locale_sweep.yaml` — screenshots within the tolerance pass even when pixels differ. Default `0.0` (exact match).
- `SweepGoldenComparator` wraps Flutter's `GoldenFileComparator`, intercepts golden comparisons, computes diff, and applies tolerance automatically.
- 3-panel side-by-side diff images generated on mismatch: Golden | Actual | Diff (identical pixels dimmed, changed pixels highlighted in magenta).
- Diff images saved to `.locale_sweep/diffs/` with `_diff.png` suffix.
- `DiffResult` model with `diffPercent`, `changedPixels`, `totalPixels`, `diffImagePath` — full JSON serialization.

### Diff data in reports
- Markdown failure table gains a **Diff %** column showing the pixel-diff percentage for each failing variant.
- HTML report shows a **diff badge** on cards with non-zero diff percentage.
- HTML report includes a **"View diff image"** link to the 3-panel comparison PNG.
- JSON report includes `diff` object in each result with full diff metrics.

### Updated config
- Added `tolerance` key to `locale_sweep.yaml` (number, 0.0–100.0).
- Config validation now handles `num` type for tolerance field.
- `SweepResult` gains `diff` field with full JSON round-trip support.
- `sweepTest()` gains `tolerance` and `diffOutputDir` parameters.

### Other
- Exported `DiffResult`, `GoldenDiffer`, and `SweepGoldenComparator` from barrel file.
- 35 new tests across 2 test files: `golden_diff_test.dart` (19 unit tests) and `screenshot_diff_e2e_test.dart` (16 end-to-end tests).
- 202 tests total across 11 test files.

## 0.2.0

### Dark mode testing
- Added `darkMode` parameter to `sweepTest()` — set to `true` to test every variant in both light and dark brightness.
- Added `lightTheme` / `darkTheme` parameters — pass your app's `ThemeData` so `Theme.of(context)` works correctly inside the builder. Defaults to `ThemeData.light()` and `ThemeData.dark()` when omitted.
- Added `dark_mode: true` support in `locale_sweep.yaml` config.
- `SweepVariant` gains `isDark` and `brightness` properties.
- Dark variants include "Dark" in `displayLabel` and "dark" in file-safe `label`.

### Variant exclusion
- Added `skip` callback to `sweepTest()` — return `true` to exclude specific locale/scale/viewport/brightness combinations from the test matrix.
- Skipped variants show as `~` (skipped) in Flutter test output, not failures.

### Interactive HTML report
- Added `ReportGenerator.generateHtml()` — self-contained HTML dashboard with dark theme, no external dependencies.
- Summary cards: total, passed, failed, overflows, ARB issues at a glance.
- Interactive filters: filter by status (pass/fail), locale, and flow.
- Screenshot gallery: cards grouped by flow with golden images, pass/fail badges, and issue details.
- Dark mode and RTL badges on variant cards.
- Locale summary table with failure row highlighting.
- CLI now outputs `report.html` alongside `report.md` and `report.json`.

### CI control
- Added `--fail-on` CLI flag — comma-separated categories (`overflow`, `arb`, `golden`, `all`, `none`) that control which issues trigger a non-zero exit code.
- Added `screenshotLinkBuilder` parameter to `ReportGenerator.generateMarkdown()` — customize how screenshot paths render in PR comments.

### Config validation
- `SweepConfig.load()` now warns on stderr about unknown keys (likely typos) and type mismatches.
- Invalid YAML, empty files, and wrong types fall back to defaults with clear warning messages.

### File-based result sink
- Each `sweepTest()` flow writes results to `.locale_sweep/results/{flowName}.json` — isolate-safe, no global state.
- CLI reads result files for full overflow and ARB data instead of parsing `--machine` output.

### Other
- Brightness field added to `SweepResult.toJson()` / `fromJson()` serialization.
- Comprehensive integration test covering all new features (167 tests total).
- Rewritten README with full documentation for every feature.

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
