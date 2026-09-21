import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  group('TruncationDetector', () {
    testWidgets('detects ellipsis overflow on constrained text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 50,
              child: Text(
                'This is a very long string that will be truncated',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final issues = TruncationDetector.detect(tester, 'en');
      expect(issues, isNotEmpty);
      expect(issues.first.overflowMode, 'ellipsis');
      expect(issues.first.locale, 'en');
      expect(
        issues.first.desiredWidth,
        greaterThan(issues.first.availableWidth),
      );
      expect(issues.first.maxLines, 1);
    });

    testWidgets('detects clip overflow', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 50,
              child: Text(
                'This long text is clipped silently without any indication',
                overflow: TextOverflow.clip,
                maxLines: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final issues = TruncationDetector.detect(tester, 'de');
      expect(issues, isNotEmpty);
      expect(issues.first.overflowMode, 'clip');
      expect(issues.first.locale, 'de');
    });

    testWidgets('detects fade overflow', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 50,
              child: Text(
                'Fading text that is too wide for this container',
                overflow: TextOverflow.fade,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final issues = TruncationDetector.detect(tester, 'en');
      expect(issues, isNotEmpty);
      expect(issues.first.overflowMode, 'fade');
    });

    testWidgets('ignores visible overflow', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 50,
              child: Text(
                'This overflows visibly which is fine',
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final issues = TruncationDetector.detect(tester, 'en');
      expect(issues, isEmpty);
    });

    testWidgets('ignores text that fits', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 500,
              child: Text(
                'Short',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final issues = TruncationDetector.detect(tester, 'en');
      expect(issues, isEmpty);
    });

    testWidgets('detects maxLines exceeded', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 100,
              child: Text(
                'Line one is here. Line two is also here. Line three continues further. Line four overflows the max.',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final issues = TruncationDetector.detect(tester, 'en');
      expect(issues, isNotEmpty);
      expect(issues.first.maxLines, 2);
    });

    testWidgets('ignores empty text', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 50,
              child: Text('', overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final issues = TruncationDetector.detect(tester, 'en');
      expect(issues, isEmpty);
    });
  });

  group('TruncationIssue', () {
    test('toJson and fromJson roundtrip', () {
      const issue = TruncationIssue(
        text: 'Einstellungen',
        locale: 'de',
        overflowMode: 'ellipsis',
        availableWidth: 100.0,
        desiredWidth: 150.0,
        maxLines: 1,
      );

      final json = issue.toJson();
      final restored = TruncationIssue.fromJson(json);

      expect(restored.text, issue.text);
      expect(restored.locale, issue.locale);
      expect(restored.overflowMode, issue.overflowMode);
      expect(restored.availableWidth, issue.availableWidth);
      expect(restored.desiredWidth, issue.desiredWidth);
      expect(restored.maxLines, issue.maxLines);
    });

    test('toJson omits null maxLines', () {
      const issue = TruncationIssue(
        text: 'Hello',
        locale: 'en',
        overflowMode: 'clip',
        availableWidth: 100.0,
        desiredWidth: 150.0,
      );

      final json = issue.toJson();
      expect(json.containsKey('maxLines'), isFalse);
    });

    test('toString shows truncation details', () {
      const issue = TruncationIssue(
        text: 'Einstellungen',
        locale: 'de',
        overflowMode: 'ellipsis',
        availableWidth: 100.0,
        desiredWidth: 150.0,
        maxLines: 1,
      );

      expect(issue.toString(), contains('Truncated'));
      expect(issue.toString(), contains('ellipsis'));
      expect(issue.toString(), contains('+50px'));
      expect(issue.toString(), contains('maxLines: 1'));
    });

    test('toString truncates long text', () {
      final issue = TruncationIssue(
        text: 'A' * 60,
        locale: 'en',
        overflowMode: 'clip',
        availableWidth: 100.0,
        desiredWidth: 200.0,
      );

      expect(issue.toString(), contains('...'));
    });
  });

  group('SweepResult with truncations', () {
    test('hasTruncations reflects list state', () {
      const result = SweepResult(
        flowName: 'test',
        variant: SweepVariant(
          locale: 'de',
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        ),
        passed: false,
        truncations: [
          TruncationIssue(
            text: 'Test',
            locale: 'de',
            overflowMode: 'ellipsis',
            availableWidth: 100,
            desiredWidth: 150,
          ),
        ],
      );

      expect(result.hasTruncations, isTrue);
      expect(result.hasIssues, isTrue);
    });

    test('truncations included in toJson', () {
      const result = SweepResult(
        flowName: 'test',
        variant: SweepVariant(
          locale: 'en',
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        ),
        passed: true,
        truncations: [
          TruncationIssue(
            text: 'Hello',
            locale: 'en',
            overflowMode: 'clip',
            availableWidth: 100,
            desiredWidth: 120,
          ),
        ],
      );

      final json = result.toJson();
      expect(json['truncations'], isList);
      expect((json['truncations'] as List).length, 1);
    });

    test('fromJson handles missing truncations for backwards compat', () {
      final json = {
        'flow': 'test',
        'locale': 'en',
        'textScale': 1.0,
        'viewportName': 'phone',
        'viewportWidth': 393.0,
        'viewportHeight': 852.0,
        'brightness': 'light',
        'rtl': false,
        'passed': true,
        'overflows': <dynamic>[],
        'arbIssues': <dynamic>[],
        'screenshot': null,
        'error': null,
        'durationMs': 0,
      };

      final result = SweepResult.fromJson(json);
      expect(result.truncations, isEmpty);
    });
  });

  group('shouldFail with truncation', () {
    test('fails on truncation when fail-on includes truncation', () {
      const result = SweepResult(
        flowName: 'test',
        variant: SweepVariant(
          locale: 'de',
          textScale: 2.0,
          viewport: ViewportPreset.phone,
        ),
        passed: true,
        truncations: [
          TruncationIssue(
            text: 'Einstellungen',
            locale: 'de',
            overflowMode: 'ellipsis',
            availableWidth: 100,
            desiredWidth: 150,
          ),
        ],
      );

      final report = ParsedReport(
        markdown: '',
        json: '',
        html: '',
        summary: '',
        total: 1,
        passed: 0,
        failed: 1,
        results: [result],
      );

      expect(shouldFail(report, {'truncation'}), isTrue);
      expect(shouldFail(report, {'overflow'}), isFalse);
      expect(shouldFail(report, {'all'}), isTrue);
      expect(shouldFail(report, {'none'}), isFalse);
    });
  });
}
