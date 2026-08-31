import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../config/sweep_config.dart';
import '../config/viewport_preset.dart';
import '../detection/arb_analyzer.dart';
import '../detection/overflow_detector.dart';
import '../report/sweep_result.dart';
import 'sweep_variant.dart';

final _allResults = <SweepResult>[];

/// Returns all results recorded by [sweepTest] in this isolate.
List<SweepResult> get sweepResults => List.unmodifiable(_allResults);

/// Clears all recorded sweep results.
void clearSweepResults() => _allResults.clear();

/// Callback for interactions to run after the widget is pumped.
typedef SweepBody = Future<void> Function(WidgetTester tester);

/// Generates `locales × textScales × viewports` test cases for [flowName].
///
/// Each combination is run as a separate `testWidgets`, wrapped in
/// [Directionality] and [MediaQuery] to simulate the target environment.
/// Overflow errors are captured and fail the variant after the result
/// is recorded (so screenshots exist before failure).
void sweepTest(
  String flowName, {
  required Widget Function() builder,
  SweepBody? body,
  SweepConfig? config,
  List<String>? locales,
  List<double>? textScales,
  List<ViewportPreset>? viewports,
  String? arbDir,
  bool captureScreenshots = true,
  String screenshotDir = '.locale_sweep/screenshots',
}) {
  final cfg = config ?? const SweepConfig();
  final effectiveLocales = locales ?? cfg.locales;
  final effectiveScales = textScales ?? cfg.textScales;
  final effectiveViewports = viewports ?? cfg.viewports;
  final effectiveArbDir = arbDir ?? cfg.arbDir;

  final variants = <SweepVariant>[];
  for (final locale in effectiveLocales) {
    for (final scale in effectiveScales) {
      for (final vp in effectiveViewports) {
        variants.add(
          SweepVariant(locale: locale, textScale: scale, viewport: vp),
        );
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

  group('sweep: $flowName', () {
    for (final variant in variants) {
      testWidgets('$flowName [${variant.displayLabel}]', (tester) async {
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

          final widget = Directionality(
            textDirection: variant.textDirection,
            child: MediaQuery(
              data: MediaQueryData(
                size: variant.viewport.size,
                textScaler: TextScaler.linear(variant.textScale),
              ),
              child: builder(),
            ),
          );

          await tester.pumpWidget(widget);
          await tester.pumpAndSettle();

          if (body != null) {
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

  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    tester.platformDispatcher.clearLocaleTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
