## 0.8.2

- **The pub.dev Example tab now shows the sweep example.** 0.8.1 added it as
  `example/README.md`, but pub.dev shows `example/lib/main.dart` ahead of that
  file, so the tab still showed the demo app. The example now lives in
  `example/example.md`, which pub.dev shows first.

## 0.8.1

- **The pub.dev Example tab shows how to use LocaleSweep.** It used to show
  the demo app's `main.dart`; `example/README.md` now leads with a real sweep
  test, how to run it, and the bugs the example app contains.
- **An invalid `--timeout` fails before `flutter test` starts**, instead of
  after the test process was already launched.
- **`SweepResult.copyWith` keeps `actualScreenshotPath`** when it is not
  passed, so moving only the golden path no longer drops the failure
  screenshot.

## 0.8.0

**Upgrade notes** — these changes can alter results on existing projects:

- **Placeholder checks are stricter**, so CI that passed on 0.7.x can report
  new `placeholderMismatch` findings. They are real bugs: translations that
  drop a placeholder, or add one the base locale does not pass.
- **ARB findings are reported once per locale** instead of on every variant,
  so failed-variant counts drop. Base-locale problems no longer fail every
  variant in the matrix.
- **`truncation_ignore` rules with a typo are skipped** instead of being
  applied with their remaining fields, so truncations they silently hid may
  appear again.

**Changes**

- **ARB files that cannot be read are reported** instead of being treated as
  empty. A broken base ARB used to yield an empty key set and silently pass
  every check; it now produces a `parseError` finding (`ArbIssueType`). A broken
  target ARB no longer reports every base key as `missing`.
- **ARB file names with subtags are recognized** — `app_zh_Hans.arb`,
  `app_zh_Hant_CN.arb`, `app_es_419.arb`, `app_fil.arb`, `en.arb` and
  `app_en-US.arb` are all loaded now (previously only `app_en.arb` /
  `app_en_US.arb`; everything else was skipped as "No ARB file").
- **Placeholder checks are two-way and metadata optional.** A placeholder that
  exists only in the target (`{nmae}`) is reported, and when `@key.placeholders`
  metadata is absent the placeholders are read from the base message itself, so
  hand-written ARB files are no longer skipped. Placeholder names are matched
  literally (so `{file.name}` is safe) and ICU branch bodies (`good{Super}`,
  `male {he}`) are not mistaken for placeholders — the spaced style from
  Flutter's gen-l10n docs is handled.
- **`truncation_ignore` rules with an unknown key are skipped** instead of being
  applied with the remaining fields — a misspelled `text_regexp` next to a valid
  `max_lines` used to ignore every short truncation. An unsupported `overflow`
  value (`ellipses`) is rejected with a warning too, instead of leaving a
  permanently dead rule.
- **`--timeout` is opt-in and bounded with escalation.** When omitted the run is
  unbounded (the CI job timeout applies), so large matrices and monorepos that
  currently pass are not killed. An invalid value (`--timeout abc` / `0`) is now a
  usage error. A run that exceeds the limit is killed, and if it survives that it
  is escalated to SIGKILL, so a hung golden wait or font download cannot pin the
  CLI open forever.
- **`--flows` warns when it widens the run.** Selecting a file by name only (for
  a file declaring different flow names) runs every flow in that file; `selectFlows`
  now reports this through a flag instead of writing to stderr from library code.
- **Malformed `locale_sweep.yaml` no longer aborts the run.** Wrong-typed entries
  (`locales: [en, 1]`, `text_scales: ["2.0"]`, a viewport without `width`) are
  dropped with a warning and the default is used when nothing valid remains,
  instead of throwing a `TypeError` before any report is written. Empty
  `LOCALE_SWEEP_*` variables fall back to the configured value, boolean variables
  accept `true`/`1`/`yes`, and unparseable numbers warn instead of silently
  reverting.
- **Failing variants save their actual screenshot** to `.locale_sweep/actual/`
  and the reports show it (`actualScreenshotPath`, JSON `actualScreenshot`), so a
  first run with no baseline has screenshot proof instead of "No screenshot".
  `screenshotPath` keeps pointing at the golden, which is never overwritten.
- **Diff data is produced at every tolerance, including `0`.** The diff
  comparator was only installed when `tolerance > 0`, so the default config had
  an empty Diff % column and no `diff` field in `report.json`. Golden lookup
  also falls back to the `LocalFileComparator` layout, fixing missing diffs for
  tests that live in a subdirectory.
- **ARB findings are reported once**, on the variant of the locale they belong
  to, instead of being duplicated across every locale × scale × viewport ×
  brightness. When the base locale is not in the matrix they attach to the first
  variant that actually runs.
- **Reports escape their inputs.** Markdown table cells escape `|` and newlines,
  and HTML attributes (`src`, `href`, `data-*`) escape `"` `'` `<` `>`, so
  truncation text or a flow name containing those no longer breaks the report.
- **Windows support for the CLI** — `flutter test` is started through
  `flutter.bat` when `flutter` cannot be resolved from `PATH`.
- **Old runs are pruned** — `.locale_sweep/runs/` keeps the 10 most recent run
  directories instead of growing without bound.
- **Older result files still load.** A result without `overflows` /
  `arbIssues` lists is read as having no findings instead of discarding the
  whole file.

Thanks to @AmisKwok for these fixes.

## 0.7.3

- **Hardcoded text detection no longer goes silent when the ARB contains a
  placeholder-only message.** A message such as `"userName": "{name}"`, or a
  `plural` branch like `=0{{count}}`, compiled to a pattern that matched any
  text, so no hardcoded string was ever reported for that locale. Message
  shapes without literal letters are now ignored when matching. Text rendered
  only through such a message (a user's name, for example) is reported;
  exempt it with `hardcoded_text_allowlist`.

## 0.7.2

- **Pseudo-localization** — add `pseudo` to `locales` to render the base
  locale with longer, accented, bracketed text (`Settings` →
  `[Šéţţîñĝš one two]`). Overflow and truncation detection then run against
  the expanded layout, so problems surface before translations exist. Works
  with any localization library because it rewrites the rendered text.
  `SweepVariant` gains `isPseudo` and `renderLocale` (the locale the app is
  rendered in); `builderWithVariant` users should pass `variant.renderLocale`.
- **Hardcoded text detection** — `detectHardcodedText: true` (or
  `hardcoded_text: true` in YAML) reports rendered text that matches no ARB
  message for the variant's locale, its language, or the base locale.
  Placeholders and `plural` / `select` branches are understood. Exempt brand
  names and user data with `hardcodedTextAllowlist` /
  `hardcoded_text_allowlist`. Findings are advisory, appear in all reports,
  and fail the run with the new `--fail-on hardcoded` category or
  `--fail-on all`.
- **`ArbAnalyzer.loadMessages`** — returns ARB message values per locale.

## 0.7.1

- **Ignore intentional truncations** — added `ignoreTruncation` to `sweepTest` plus `TruncationIgnores` helpers (`byWidgetType`, `byKey`, `byMaxLines`, `byText`, `any`, `fromConfig`) to exclude by-design text truncation from reports and `--fail-on truncation`. Declarative `truncation_ignore:` rules in `locale_sweep.yaml` cover the common list-row ellipsis case without any Dart code. `TruncationDetector.detect` gains an optional `ignore` parameter (backwards compatible).
- **Safe YAML ignore rules** — unknown keys, empty rules, wrong-typed values and invalid `text_regex` patterns print a warning once per flow and are skipped, so a typo can never hide every truncation.

Thanks to @AmisKwok for this contribution.

## 0.7.0

- **Behavior change: truncation-only variants now report `passed: true`** in
  `report.json` and count as passed in report summaries. CLI exit codes are
  unchanged — `--fail-on all` (the default) and `--fail-on truncation` still
  fail on truncations. Update custom tooling that reads `passed` from the JSON.
- **Truncation detection no longer reports wrapping text** — paragraphs without
  `maxLines` wrap instead of truncating, so the intrinsic-width fallback now only
  applies when `maxLines` is set. Single-line horizontal truncation
  (`softWrap: false`) is still detected.
- **Truncations are advisory in pass/fail state** — `SweepResult.passed`,
  `SweepRunSummary.passed`, JSON output, and report badges are driven by
  overflows, ARB issues and execution errors. Truncations are labelled
  `ADVISORY`; `--fail-on truncation` promotes them, and `--fail-on all` (the
  CLI default) already includes them.
- **`untranslated_allowlist` config** — exempt intentionally identical values
  (app names, language self-names) from the ARB `untranslated` check. Missing
  keys and placeholder mismatches are still reported.
- **`builderWithVariant`** — `sweepTest` can now pass the current `SweepVariant`
  to its builder, so callers can supply the variant locale directly instead of
  relying on an injected `Localizations` ancestor. Exactly one of `builder` or
  `builderWithVariant` is required.
- **Report screenshots resolve locally** — results now record the actual
  package-relative screenshot location (resolved through the golden
  comparator's basedir; absolute configured paths stay absolute), and report
  links are rewritten relative to the report output directory.
- **Capture-only screenshots** — new `compareScreenshots` parameter (default
  `true`). Set it to `false` with `captureScreenshots: true` to write PNGs for
  reports without asserting against golden baselines.

Thanks to @jeromexiong for the contributions in this release.

## 0.6.2

- **Fix crash on the `flutter test --machine` startup line** — the CLI parsed
  every stdout line as a JSON object, but `flutter test --machine` first prints a
  JSON *array* line (`[{"event":"test.startedProcess","params":{...}}]`). The
  resulting `TypeError` was not caught by the `on FormatException` handler, so
  `run` and `update` aborted with an unhandled exception before writing any
  results or report. Both shapes are now decoded by one shared helper
  (`parseMachineLine` in `lib/src/cli/machine_output.dart`) that returns the
  event objects a line carries and ignores anything else. No public API change.
- **`--flows` matches flow names** — `--flows login` now selects
  `sweepTest('login', ...)` in any test file and runs only that flow, instead of
  requiring a file named `login_test.dart`. File-name matching still works. When
  nothing matches, the error lists the available flows.

## 0.6.1

- **Truncation findings no longer fail direct tests** — truncation issues are now advisory in `flutter test` runs. They are recorded in `SweepResult` for the CLI's `--fail-on truncation` to handle, preventing unexpected test failures in existing suites after upgrading to 0.6.0.

## 0.6.0

- **Text truncation detection** — after every `pumpAndSettle()`, walks the render tree to find `RenderParagraph` nodes where text is silently truncated by `ellipsis`, `clip`, or `fade` overflow modes. Reports the text, locale, overflow mode, available vs. desired width, and maxLines. Catches localization bugs that overflow detection misses — translated strings that fit the container but lose content.
- **`--fail-on truncation`** — new category for the `--fail-on` flag. Truncation findings are included in Markdown, HTML, and JSON reports alongside overflows and ARB issues.
- **Report improvements** — Markdown and HTML locale summary tables include a Truncations column. HTML report adds a Truncations summary card. CLI summary line includes truncation count.
- **Backwards compatible** — `truncations` field defaults to empty; existing JSON results without it deserialize cleanly.

## 0.5.1

- **Reliable exit codes** — ARB-only findings now mark variants as failed and respect `--fail-on`; unexpected test, setup, compilation, and result-read failures always return a non-zero exit, even with `--fail-on none`.
- **Consistent reports** — Markdown, HTML, JSON, CLI summaries, and process exit codes now derive pass/fail state from the same result model. Reports also expose execution errors when a run is incomplete.
- **Current-run isolation** — every CLI invocation writes to a unique results directory, so stale files cannot contaminate a later report. Duplicate flow names across test isolates are preserved, and corrupt or partial results fail visibly.
- **Configuration propagation** — `sweepTest()` now loads the CLI-selected YAML file and environment overrides automatically. Explicit Dart arguments remain highest priority, including `screenshotDir`.
- **Safer CLI orchestration** — single-package, monorepo, shard, merge, and golden-update paths share the same validation and failure rules. Invalid categories, shard ranges, configs, flow selections, and missing packages fail clearly.
- 329 tests total across 17 test files.

## 0.5.0

- **Localizations integration** — new `localizationsDelegates` parameter on `sweepTest()`. Wraps the widget in a `Localizations` ancestor so `AppLocalizations.of(context)` works for individual screen tests without needing a full `MaterialApp`. Fallback Material/Widgets delegates are included automatically for all locales.
- **`baseLocale` config** — configurable base locale for ARB analysis. Set via `sweepTest(baseLocale:)`, YAML `base_locale:`, or `LOCALE_SWEEP_BASE_LOCALE` env var. Defaults to `'en'`.
- **`parseLocale()` helper** — proper BCP-47 locale parsing. Handles `en`, `en_US`, `pt-BR`, `zh_Hans`, `zh_Hans_CN`. Used internally and exported for user convenience.
- **Example app uses `flutter gen-l10n`** — all three example screens now use `AppLocalizations.of(context)` instead of hardcoded strings. Demonstrates both patterns: full `MaterialApp` with delegates (home) and screen-in-isolation with `localizationsDelegates` param (settings, profile).
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
