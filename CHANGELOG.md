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
