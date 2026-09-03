import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../config/sweep_config.dart';
import '../config/viewport_preset.dart';
import '../detection/arb_analyzer.dart';
import '../detection/overflow_detector.dart';
import '../report/sweep_result.dart';
import 'sweep_variant.dart';

/// Default directory where sweep results are written for CLI consumption.
const sweepResultsDir = '.locale_sweep/results';

final _allResults = <SweepResult>[];

/// Returns all results recorded by [sweepTest] in this test isolate.
///
/// **Note:** Each test file runs in its own isolate, so this list only
/// contains results from the current file. For cross-file aggregation,
/// use the JSON files written to [sweepResultsDir] instead.
List<SweepResult> get sweepResults => List.unmodifiable(_allResults);

/// Clears all recorded sweep results.
void clearSweepResults() => _allResults.clear();

/// Callback for interactions to run after the widget is pumped.
typedef SweepBody = Future<void> Function(WidgetTester tester);

/// Callback that also receives the current [SweepVariant] for locale-aware interactions.
typedef SweepVariantBody =
    Future<void> Function(WidgetTester tester, SweepVariant variant);

/// Generates `locales × textScales × viewports (× brightness)` test cases for [flowName].
///
/// Each combination is run as a separate `testWidgets`, wrapped in
/// [Directionality] and [MediaQuery] to simulate the target environment.
///
/// Set [darkMode] to `true` to test both light and dark for every variant.
/// Pass [lightTheme] / [darkTheme] to wrap the widget in a [Theme] so
/// `Theme.of(context)` works inside the builder — if omitted, default
/// Material themes are used when [darkMode] is enabled.
///
/// Overflow errors are captured and fail the variant after the result
/// is recorded (so screenshots exist before failure).
void sweepTest(
  String flowName, {
  required Widget Function() builder,
  SweepBody? body,
  SweepVariantBody? variantBody,
  SweepConfig? config,
  List<String>? locales,
  List<double>? textScales,
  List<ViewportPreset>? viewports,
  bool? darkMode,
  ThemeData? lightTheme,
  ThemeData? darkTheme,
  String? arbDir,
  bool captureScreenshots = true,
  String screenshotDir = '.locale_sweep/screenshots',
  bool Function(SweepVariant variant)? skip,
}) {
  final cfg = config ?? const SweepConfig();
  final effectiveLocales = locales ?? cfg.locales;
  final effectiveScales = textScales ?? cfg.textScales;
  final effectiveViewports = viewports ?? cfg.viewports;
  final effectiveDarkMode = darkMode ?? cfg.darkMode;
  final effectiveArbDir = arbDir ?? cfg.arbDir;

  final brightnesses = [
    Brightness.light,
    if (effectiveDarkMode) Brightness.dark,
  ];

  final resolvedLightTheme = effectiveDarkMode
      ? (lightTheme ?? ThemeData.light())
      : lightTheme;
  final resolvedDarkTheme = effectiveDarkMode
      ? (darkTheme ?? ThemeData.dark())
      : darkTheme;

  final variants = <SweepVariant>[];
  for (final locale in effectiveLocales) {
    for (final scale in effectiveScales) {
      for (final vp in effectiveViewports) {
        for (final brightness in brightnesses) {
          variants.add(
            SweepVariant(
              locale: locale,
              textScale: scale,
              viewport: vp,
              brightness: brightness,
            ),
          );
        }
      }
    }
  }

  ArbReport? arbReport;
  if (effectiveArbDir != null) {
    arbReport = ArbAnalyzer.analyze(
      arbDir: effectiveArbDir,
      locales: effectiveLocales,
    );
  }

  final flowResults = <SweepResult>[];

  group('sweep: $flowName', () {
    tearDownAll(() {
      final dir = Directory(sweepResultsDir);
      dir.createSync(recursive: true);
      final file = File('${dir.path}/$flowName.json');
      file.writeAsStringSync(
        jsonEncode(flowResults.map((r) => r.toJson()).toList()),
      );
    });

    for (final variant in variants) {
      final shouldSkip = skip != null && skip(variant);
      testWidgets('$flowName [${variant.displayLabel}]', skip: shouldSkip, (
        tester,
      ) async {
        final stopwatch = Stopwatch()..start();
        final overflowDetector = OverflowDetector();
        String? screenshotPath;
        String? errorMessage;
        var passed = true;
        final arbIssues = <ArbIssue>[];

        if (arbReport != null) {
          arbIssues.addAll(
            arbReport.issues.where((i) => i.locale == variant.locale),
          );
        }

        overflowDetector.install();

        try {
          _configureTestEnvironment(tester, variant);

          final themeData = variant.isDark
              ? resolvedDarkTheme
              : resolvedLightTheme;

          Widget child = builder();
          if (themeData != null) {
            child = Theme(data: themeData, child: child);
          }

          final widget = Directionality(
            textDirection: variant.textDirection,
            child: MediaQuery(
              data: MediaQueryData(
                size: variant.viewport.size,
                textScaler: TextScaler.linear(variant.textScale),
                platformBrightness: variant.brightness,
              ),
              child: child,
            ),
          );

          await tester.pumpWidget(widget);
          await tester.pumpAndSettle();

          if (variantBody != null) {
            await variantBody(tester, variant);
            await tester.pumpAndSettle();
          } else if (body != null) {
            await body(tester);
            await tester.pumpAndSettle();
          }

          if (captureScreenshots) {
            screenshotPath =
                '$screenshotDir/${variant.screenshotPath(flowName)}';
            await expectLater(
              find.byType(Directionality).first,
              matchesGoldenFile(screenshotPath),
            );
          }
        } catch (e) {
          passed = false;
          errorMessage = e.toString();
        } finally {
          overflowDetector.uninstall();
          stopwatch.stop();
        }

        if (overflowDetector.errors.isNotEmpty) {
          passed = false;
        }

        final result = SweepResult(
          flowName: flowName,
          variant: variant,
          passed: passed,
          overflows: List.of(overflowDetector.errors),
          arbIssues: arbIssues,
          screenshotPath: screenshotPath,
          errorMessage: errorMessage,
          duration: stopwatch.elapsed,
        );

        _allResults.add(result);
        flowResults.add(result);

        if (overflowDetector.errors.isNotEmpty) {
          fail(
            'Overflow detected in $flowName [${variant.displayLabel}]:\n'
            '${overflowDetector.errors.join('\n')}',
          );
        }
      });
    }
  });
}

void _configureTestEnvironment(WidgetTester tester, SweepVariant variant) {
  final view = tester.view;
  view.physicalSize = variant.viewport.size;
  view.devicePixelRatio = 1.0;

  tester.platformDispatcher.localeTestValue = ui.Locale(variant.locale);
  tester.platformDispatcher.textScaleFactorTestValue = variant.textScale;
  tester.platformDispatcher.platformBrightnessTestValue = variant.brightness;

  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    tester.platformDispatcher.clearLocaleTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}
