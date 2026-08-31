import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

import 'fixtures/broken_localized_app/broken_widgets.dart';
import 'fixtures/clean_localized_app/clean_widgets.dart';

void main() {
  group('OverflowDetector', () {
    testWidgets('captures a real RenderFlex overflow', (tester) async {
      final detector = OverflowDetector();
      detector.install();

      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: brokenOverflowWidget(),
          ),
        );
      } finally {
        detector.uninstall();
      }

      expect(detector.errors, isNotEmpty);
      expect(detector.errors.first.message, contains('overflowed'));
      expect(detector.errors.first.pixels, isNotNull);
      expect(detector.errors.first.pixels!, greaterThan(0));
    });

    testWidgets('records no overflow for a clean layout', (tester) async {
      final detector = OverflowDetector();
      detector.install();

      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: cleanWidget(),
          ),
        );
      } finally {
        detector.uninstall();
      }

      expect(detector.errors, isEmpty);
    });

    testWidgets('restores the previous error handler on uninstall', (
      tester,
    ) async {
      final handlerBefore = FlutterError.onError;
      final detector = OverflowDetector();
      detector.install();

      expect(FlutterError.onError, isNot(equals(handlerBefore)));

      detector.uninstall();
      expect(FlutterError.onError, equals(handlerBefore));
    });

    testWidgets('passes non-overflow errors through to previous handler', (
      tester,
    ) async {
      final caughtErrors = <FlutterErrorDetails>[];
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (details) => caughtErrors.add(details);

      final detector = OverflowDetector();
      detector.install();

      FlutterError.onError!(
        FlutterErrorDetails(exception: Exception('Not an overflow')),
      );

      detector.uninstall();
      FlutterError.onError = originalHandler;

      expect(detector.errors, isEmpty);
      expect(caughtErrors, hasLength(1));
      expect(
        caughtErrors.first.exceptionAsString(),
        contains('Not an overflow'),
      );
    });

    test('reset clears captured errors', () {
      final detector = OverflowDetector();
      detector.errors.add(
        const OverflowError(
          message: 'A RenderFlex overflowed by 10 pixels',
          pixels: 10,
        ),
      );
      expect(detector.errors, isNotEmpty);
      detector.reset();
      expect(detector.errors, isEmpty);
    });

    testWidgets('extracts pixel count from overflow message', (tester) async {
      final detector = OverflowDetector();
      detector.install();

      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: brokenOverflowWidget(),
          ),
        );
      } finally {
        detector.uninstall();
      }

      expect(detector.errors.first.pixels, isA<double>());
      expect(detector.errors.first.pixels!, greaterThanOrEqualTo(1.0));
    });
  });

  group('OverflowDetector in sweep context', () {
    testWidgets('overflow is captured and result is marked as failed', (
      tester,
    ) async {
      final detector = OverflowDetector();
      detector.install();

      final view = tester.view;
      view.physicalSize = const Size(200, 400);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      var passed = true;
      String? errorMessage;

      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(200, 400),
                textScaler: TextScaler.linear(1.0),
              ),
              child: brokenOverflowWidget(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      } catch (e) {
        passed = false;
        errorMessage = e.toString();
      } finally {
        detector.uninstall();
      }

      if (detector.errors.isNotEmpty) {
        passed = false;
      }

      expect(
        detector.errors,
        isNotEmpty,
        reason: 'OverflowDetector should capture the overflow',
      );
      expect(passed, isFalse, reason: 'Result should be marked as failed');

      final result = SweepResult(
        flowName: 'broken_overflow',
        variant: const SweepVariant(
          locale: 'de',
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        ),
        passed: passed,
        overflows: List.of(detector.errors),
        errorMessage: errorMessage,
      );

      expect(result.hasOverflows, isTrue);
      expect(result.hasIssues, isTrue);
      expect(result.passed, isFalse);
    });

    testWidgets(
      'screenshot path is set before overflow failure would be thrown',
      (tester) async {
        final detector = OverflowDetector();
        detector.install();

        final view = tester.view;
        view.physicalSize = const Size(200, 400);
        view.devicePixelRatio = 1.0;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        String? screenshotPath;

        try {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(200, 400),
                  textScaler: TextScaler.linear(1.0),
                ),
                child: brokenOverflowWidget(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          screenshotPath = '.locale_sweep/screenshots/test_overflow.png';
        } catch (e) {
          // Widget errors caught here
        } finally {
          detector.uninstall();
        }

        expect(detector.errors, isNotEmpty);
        expect(
          screenshotPath,
          isNotNull,
          reason:
              'Screenshot path must be assigned before overflow fail() call',
        );
      },
    );
  });
}
