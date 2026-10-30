import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';
import 'package:locale_sweep/src/cli/flow_filter.dart';

void main() {
  group('SweepResult.fromJson', () {
    /// A result written before `overflows` / `arbIssues` existed (or by a
    /// tool that omits them) must still deserialize.
    const legacyJson = <String, dynamic>{
      'flow': 'legacy',
      'variant': 'en_1.0_phone',
      'locale': 'en',
      'textScale': 1.0,
      'viewportName': 'phone',
      'viewportWidth': 393,
      'viewportHeight': 852,
      'brightness': 'light',
      'rtl': false,
      'passed': true,
    };

    test('accepts a result without the issue lists', () {
      final result = SweepResult.fromJson(legacyJson);

      expect(result.flowName, 'legacy');
      expect(result.overflows, isEmpty);
      expect(result.arbIssues, isEmpty);
      expect(result.truncations, isEmpty);
      expect(result.hardcodedTexts, isEmpty);
    });

    test('accepts a result with null issue lists', () {
      final result = SweepResult.fromJson({
        ...legacyJson,
        'overflows': null,
        'arbIssues': null,
      });

      expect(result.overflows, isEmpty);
      expect(result.arbIssues, isEmpty);
    });

    test('still reads the issue lists when present', () {
      final result = SweepResult.fromJson({
        ...legacyJson,
        'arbIssues': [
          {
            'type': 'missingKey',
            'locale': 'de',
            'key': 'title',
            'detail': 'Key "title" missing in de',
          },
        ],
      });

      expect(result.arbIssues, hasLength(1));
      expect(result.arbIssues.first.key, 'title');
      expect(result.hasArbIssues, isTrue);
    });
  });

  group('Report escaping', () {
    SweepRunSummary summaryWith(String flowName) => SweepRunSummary(
      results: [
        SweepResult(
          flowName: flowName,
          variant: const SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: false,
          truncations: const [
            TruncationIssue(
              text: 'Save | Cancel',
              locale: 'en',
              overflowMode: 'ellipsis',
              availableWidth: 100,
              desiredWidth: 200,
            ),
          ],
          screenshotPath: 'a"b/image.png',
        ),
      ],
    );

    test('escapes pipes in Markdown table cells', () {
      final markdown = ReportGenerator.generateMarkdown(summaryWith('flow'));

      // An unescaped `|` would add columns and break the table.
      expect(markdown, contains(r'Save \| Cancel'));
    });

    test('escapes quotes in HTML attributes', () {
      final html = ReportGenerator.generateHtml(summaryWith('say "hi"'));

      expect(html, contains('data-flow="say &quot;hi&quot;"'));
      expect(html, contains('src="a&quot;b/image.png"'));
      expect(html, isNot(contains('data-flow="say "hi""')));
    });
  });

  group('selectFlows file-name fallback', () {
    const sources = {
      'test/sweep/login_test.dart': '''
void main() {
  sweepTest('sign_in', builder: () => const SignIn());
}
''',
    };

    test('runs the file unfiltered when only its name matches', () {
      final selection = selectFlows(sources, {'login'});

      expect(selection.files, ['test/sweep/login_test.dart']);
      expect(selection.namePattern, isNull);
    });

    test('narrows by name pattern when the flow is declared', () {
      final selection = selectFlows(sources, {'sign_in'});

      expect(selection.files, ['test/sweep/login_test.dart']);
      expect(selection.namePattern, isNotNull);
    });
  });

  group('SweepResult.copyWith', () {
    test('keeps the actual screenshot and diff when only the golden moves', () {
      const result = SweepResult(
        flowName: 'home',
        variant: SweepVariant(
          locale: 'de',
          textScale: 1.0,
          viewport: ViewportPreset.phone,
        ),
        passed: false,
        screenshotPath: 'test/sweep/.locale_sweep/screenshots/home.png',
        actualScreenshotPath: '.locale_sweep/actual/home.png',
        diff: DiffResult(diffPercent: 2.5, changedPixels: 10, totalPixels: 400),
      );

      final moved = result.copyWith(screenshotPath: 'apps/a/home.png');

      expect(moved.screenshotPath, 'apps/a/home.png');
      expect(moved.actualScreenshotPath, '.locale_sweep/actual/home.png');
      expect(moved.diff?.diffPercent, 2.5);
    });
  });
}
