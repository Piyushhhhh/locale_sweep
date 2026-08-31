import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

SweepResult _makeResult({
  String flow = 'onboarding',
  String locale = 'en',
  double textScale = 1.0,
  ViewportPreset viewport = ViewportPreset.phone,
  bool passed = true,
  List<OverflowError> overflows = const [],
  List<ArbIssue> arbIssues = const [],
  String? screenshotPath,
  String? errorMessage,
}) {
  return SweepResult(
    flowName: flow,
    variant: SweepVariant(
      locale: locale,
      textScale: textScale,
      viewport: viewport,
    ),
    passed: passed,
    overflows: overflows,
    arbIssues: arbIssues,
    screenshotPath: screenshotPath,
    errorMessage: errorMessage,
  );
}

void main() {
  group('SweepResult.toJson', () {
    test('contains flow name, locale, viewport, textScale', () {
      final result = _makeResult(
        flow: 'checkout',
        locale: 'de',
        textScale: 2.0,
        viewport: ViewportPreset.phoneSmall,
      );
      final json = result.toJson();

      expect(json['flow'], 'checkout');
      expect(json['locale'], 'de');
      expect(json['textScale'], 2.0);
      expect(json['viewport'], '375x667');
      expect(json['rtl'], isFalse);
    });

    test('contains RTL flag for Arabic', () {
      final result = _makeResult(locale: 'ar');
      expect(result.toJson()['rtl'], isTrue);
    });

    test('contains overflow details', () {
      final result = _makeResult(
        passed: false,
        overflows: [
          const OverflowError(
            message: 'A RenderFlex overflowed by 42 pixels on the right.',
            pixels: 42,
          ),
        ],
      );
      final json = result.toJson();

      expect(json['passed'], isFalse);
      expect(json['overflows'], isA<List>());
      expect((json['overflows'] as List).first, contains('42'));
    });

    test('contains ARB issue details', () {
      final result = _makeResult(
        locale: 'de',
        arbIssues: [
          const ArbIssue(
            type: ArbIssueType.missingKey,
            locale: 'de',
            key: 'settingsTitle',
            detail: 'Key "settingsTitle" missing in de (present in en)',
          ),
        ],
      );
      final json = result.toJson();

      expect(json['arbIssues'], isA<List>());
      expect((json['arbIssues'] as List).first, contains('settingsTitle'));
    });

    test('contains screenshot path when set', () {
      final result = _makeResult(
        screenshotPath: '.locale_sweep/screenshots/onboarding_en_393x852.png',
      );
      expect(
        result.toJson()['screenshot'],
        '.locale_sweep/screenshots/onboarding_en_393x852.png',
      );
    });
  });

  group('SweepRunSummary', () {
    test('counts passed and failed correctly', () {
      final summary = SweepRunSummary(
        results: [
          _makeResult(locale: 'en', passed: true),
          _makeResult(
            locale: 'de',
            passed: false,
            overflows: [const OverflowError(message: 'overflowed', pixels: 10)],
          ),
          _makeResult(locale: 'ar', passed: true),
        ],
      );

      expect(summary.total, 3);
      expect(summary.passed, 2);
      expect(summary.failed, 1);
      expect(summary.overflowCount, 1);
    });

    test('groups results by flow', () {
      final summary = SweepRunSummary(
        results: [
          _makeResult(flow: 'onboarding', locale: 'en'),
          _makeResult(flow: 'onboarding', locale: 'de'),
          _makeResult(flow: 'checkout', locale: 'en'),
        ],
      );

      expect(summary.byFlow.keys, containsAll(['onboarding', 'checkout']));
      expect(summary.byFlow['onboarding'], hasLength(2));
      expect(summary.byFlow['checkout'], hasLength(1));
    });

    test('groups results by locale', () {
      final summary = SweepRunSummary(
        results: [
          _makeResult(flow: 'onboarding', locale: 'en'),
          _makeResult(flow: 'checkout', locale: 'en'),
          _makeResult(flow: 'onboarding', locale: 'ar'),
        ],
      );

      expect(summary.byLocale.keys, containsAll(['en', 'ar']));
      expect(summary.byLocale['en'], hasLength(2));
    });
  });

  group('ReportGenerator.generateJson', () {
    test('contains all required top-level fields', () {
      final summary = SweepRunSummary(
        results: [
          _makeResult(locale: 'en', passed: true),
          _makeResult(
            locale: 'de',
            passed: false,
            overflows: [
              const OverflowError(
                message: 'overflowed by 20 pixels',
                pixels: 20,
              ),
            ],
            arbIssues: [
              const ArbIssue(
                type: ArbIssueType.missingKey,
                locale: 'de',
                key: 'settingsTitle',
                detail: 'Key "settingsTitle" missing in de',
              ),
            ],
          ),
        ],
      );

      final jsonStr = ReportGenerator.generateJson(summary);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(data['timestamp'], isNotNull);
      expect(data['total'], 2);
      expect(data['passed'], 1);
      expect(data['failed'], 1);
      expect(data['overflows'], 1);
      expect(data['arbIssues'], 1);
      expect(data['results'], isA<List>());
    });

    test(
      'each result contains flow, locale, viewport, textScale, issue type',
      () {
        final summary = SweepRunSummary(
          results: [
            _makeResult(
              flow: 'settings',
              locale: 'ar',
              textScale: 2.0,
              viewport: ViewportPreset.tablet,
              passed: false,
              overflows: [
                const OverflowError(message: 'overflowed', pixels: 50),
              ],
            ),
          ],
        );

        final jsonStr = ReportGenerator.generateJson(summary);
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final result = (data['results'] as List).first as Map<String, dynamic>;

        expect(result['flow'], 'settings');
        expect(result['locale'], 'ar');
        expect(result['textScale'], 2.0);
        expect(result['viewport'], '768x1024');
        expect(result['rtl'], isTrue);
        expect(result['overflows'], isA<List>());
        expect((result['overflows'] as List), isNotEmpty);
      },
    );
  });

  group('ReportGenerator.generateMarkdown', () {
    test('all-passing summary is concise', () {
      final summary = SweepRunSummary(
        results: [
          _makeResult(locale: 'en', passed: true),
          _makeResult(locale: 'de', passed: true),
        ],
      );

      final md = ReportGenerator.generateMarkdown(summary);

      expect(md, contains('All 2 variants passed'));
      expect(md, isNot(contains('## Failures')));
    });

    test(
      'failure summary contains flow, locale, viewport, scale, issue type',
      () {
        final summary = SweepRunSummary(
          results: [
            _makeResult(locale: 'en', passed: true),
            _makeResult(
              flow: 'onboarding',
              locale: 'de',
              textScale: 2.0,
              viewport: ViewportPreset.phone,
              passed: false,
              overflows: [
                const OverflowError(
                  message: 'overflowed by 30 pixels',
                  pixels: 30,
                ),
              ],
            ),
            _makeResult(
              flow: 'onboarding',
              locale: 'ar',
              passed: true,
              arbIssues: [
                const ArbIssue(
                  type: ArbIssueType.missingKey,
                  locale: 'ar',
                  key: 'helpTitle',
                  detail: 'Key "helpTitle" missing in ar',
                ),
              ],
            ),
          ],
        );

        final md = ReportGenerator.generateMarkdown(summary);

        expect(md, contains('## Failures'));
        expect(md, contains('### onboarding'));
        expect(md, contains('| de |'));
        expect(md, contains('2.0x'));
        expect(md, contains('393x852'));
        expect(md, contains('Overflow'));
        expect(md, contains('missingKey'));
        expect(md, contains('## Locale Summary'));
      },
    );

    test('locale summary table is present with failure counts', () {
      final summary = SweepRunSummary(
        results: [
          _makeResult(locale: 'en', passed: true),
          _makeResult(
            locale: 'de',
            passed: false,
            overflows: [const OverflowError(message: 'overflowed', pixels: 10)],
          ),
        ],
      );

      final md = ReportGenerator.generateMarkdown(summary);

      expect(md, contains('| Locale | Passed | Failed | Overflows |'));
      expect(md, contains('| en | 1 | 0 | 0 | 0 |'));
      expect(md, contains('| de | 0 | 1 | 1 | 0 |'));
    });
  });
}
