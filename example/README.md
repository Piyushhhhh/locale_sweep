# LocaleSweep example

A small task app (TaskFlow) localized with `flutter gen-l10n` into 8 locales,
with layout and translation bugs left in on purpose. The sweep tests in
[`test/sweep/`](test/sweep) find them.

## A sweep test

```dart
import 'package:locale_sweep/locale_sweep.dart';
import 'package:taskflow_example/l10n/app_localizations.dart';
import 'package:taskflow_example/screens/settings_screen.dart';

void main() {
  // 8 locales × 2 text scales × 2 viewports × 2 brightness = 64 variants
  sweepTest(
    'settings',
    builder: () => const SettingsScreen(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locales: ['en', 'de', 'ar', 'ja', 'ko', 'he', 'th', 'hi'],
    textScales: [1.0, 2.0],
    viewports: [ViewportPreset.phone, ViewportPreset.tablet],
    darkMode: true,
    arbDir: 'lib/l10n', // missing keys, placeholder mismatches
  );
}
```

`localizationsDelegates` lets you test a single screen without wrapping it in
a `MaterialApp`. To test inside your app shell instead, build the
`MaterialApp` in `builder`, as
[`onboarding_test.dart`](test/sweep/onboarding_test.dart) does.

Two more checks you can switch on:

```dart
    locales: ['en', 'de', 'pseudo'], // pseudo: longer, accented base-locale text
    detectHardcodedText: true,       // rendered text that matches no ARB message
```

## Run it

```bash
cd example
flutter pub get
dart run locale_sweep update   # write golden baselines
dart run locale_sweep run      # check every variant against them
```

Open `.locale_sweep/reports/report.html` for the screenshot gallery, or read
`report.md` / `report.json`.

## What it finds

| Screen | Bug | Shows up in |
|:--|:--|:--|
| Home | Fixed-width task counter | German at 2x text scale |
| Settings | `Row` without `Expanded` | German at 2x text scale |
| Settings | Fixed-width upgrade banner | 2x text scale, German |
| Settings | Translations drop the `{category}` placeholder | de, ar, th, hi |
| Profile | Hardcoded left padding | Arabic and Hebrew (RTL) |
| Profile | `Row` without `Flexible` on the delete button | German at 2x text scale |
| All | Keys missing from translations, untranslated strings | ARB analysis |
