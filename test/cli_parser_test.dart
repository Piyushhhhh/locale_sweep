import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  // ── parseFlowFromName ────────────────────────────────────────────────────

  group('parseFlowFromName', () {
    test('extracts flow name from standard sweep label', () {
      expect(
        parseFlowFromName('onboarding flow sweep: onboarding [EN · 393x852]'),
        'onboarding',
      );
    });

    test('extracts flow name with underscores', () {
      expect(
        parseFlowFromName('sweep: user_settings [DE · 768x1024]'),
        'user_settings',
      );
    });

    test('returns full name if no sweep: prefix found', () {
      expect(
        parseFlowFromName('some random test name'),
        'some random test name',
      );
    });

    test('extracts first word after sweep:', () {
      expect(
        parseFlowFromName('sweep: checkout extra text [EN · 393x852]'),
        'checkout',
      );
    });
  });

  // ── parseVariantFromName ─────────────────────────────────────────────────

  group('parseVariantFromName', () {
    final cfg = SweepConfig.load('/dev/null');

    test('parses simple locale and viewport', () {
      final v = parseVariantFromName('sweep: settings [EN · 393x852]', cfg);
      expect(v.locale, 'en');
      expect(v.viewport.width, 393);
      expect(v.viewport.height, 852);
      expect(v.textScale, 1.0);
      expect(v.isDark, isFalse);
    });

    test('parses RTL locale', () {
      final v = parseVariantFromName(
        'sweep: settings [AR · RTL · 393x852]',
        cfg,
      );
      expect(v.locale, 'ar');
      expect(v.isRtl, isTrue);
    });

    test('parses dark mode', () {
      final v = parseVariantFromName(
        'sweep: settings [EN · Dark · 393x852]',
        cfg,
      );
      expect(v.isDark, isTrue);
    });

    test('parses text scale', () {
      final v = parseVariantFromName(
        'sweep: settings [EN · 2.0x scale · 393x852]',
        cfg,
      );
      expect(v.textScale, 2.0);
    });

    test('parses combined: locale + RTL + dark + scale + viewport', () {
      final v = parseVariantFromName(
        'sweep: settings [AR · RTL · Dark · 2.0x scale · 768x1024]',
        cfg,
      );
      expect(v.locale, 'ar');
      expect(v.isRtl, isTrue);
      expect(v.isDark, isTrue);
      expect(v.textScale, 2.0);
      expect(v.viewport.width, 768);
      expect(v.viewport.height, 1024);
    });

    test('parses tablet viewport', () {
      final v = parseVariantFromName('sweep: onboarding [DE · 768x1024]', cfg);
      expect(v.viewport.width, 768);
      expect(v.viewport.height, 1024);
    });

    test('defaults to en/1.0/phone when no brackets', () {
      final v = parseVariantFromName('some test without brackets', cfg);
      expect(v.locale, 'en');
      expect(v.textScale, 1.0);
      expect(v.viewport.width, ViewportPreset.phone.width);
      expect(v.isDark, isFalse);
    });

    test('parses 1.5x scale', () {
      final v = parseVariantFromName(
        'sweep: settings [EN · 1.5x scale · 393x852]',
        cfg,
      );
      expect(v.textScale, 1.5);
    });

    test('parses locale subtag', () {
      final v = parseVariantFromName(
        'sweep: settings [ar_EG · RTL · 393x852]',
        cfg,
      );
      expect(v.locale, 'ar_eg');
    });

    test('parses Japanese locale', () {
      final v = parseVariantFromName('sweep: settings [JA · 393x852]', cfg);
      expect(v.locale, 'ja');
    });
  });

  // ── shouldFail ───────────────────────────────────────────────────────────

  group('shouldFail', () {
    ParsedReport makeReport({
      int failed = 0,
      bool hasOverflow = false,
      bool hasArb = false,
      String? errorMessage,
    }) {
      final results = <SweepResult>[
        SweepResult(
          flowName: 'test',
          variant: const SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: failed == 0,
          overflows: hasOverflow
              ? [const OverflowError(message: 'overflowed by 10px')]
              : [],
          arbIssues: hasArb
              ? [
                  const ArbIssue(
                    type: ArbIssueType.missingKey,
                    locale: 'de',
                    detail: 'missing key: title',
                  ),
                ]
              : [],
          errorMessage: errorMessage,
        ),
      ];
      return ParsedReport(
        markdown: '',
        json: '',
        html: '',
        summary: '',
        total: 1,
        passed: failed == 0 ? 1 : 0,
        failed: failed,
        results: results,
      );
    }

    test('fail-on all returns true when any failure exists', () {
      final report = makeReport(failed: 1);
      expect(shouldFail(report, {'all'}), isTrue);
    });

    test('fail-on all returns false when all pass', () {
      final report = makeReport();
      expect(shouldFail(report, {'all'}), isFalse);
    });

    test('fail-on none always returns false', () {
      final report = makeReport(failed: 1, hasOverflow: true, hasArb: true);
      expect(shouldFail(report, {'none'}), isFalse);
    });

    test('fail-on overflow triggers on overflow results', () {
      final report = makeReport(failed: 1, hasOverflow: true);
      expect(shouldFail(report, {'overflow'}), isTrue);
    });

    test('fail-on overflow does not trigger on arb-only failures', () {
      final report = makeReport(failed: 1, hasArb: true);
      expect(shouldFail(report, {'overflow'}), isFalse);
    });

    test('fail-on arb triggers on arb issues', () {
      final report = makeReport(failed: 1, hasArb: true);
      expect(shouldFail(report, {'arb'}), isTrue);
    });

    test('fail-on arb does not trigger on overflow-only failures', () {
      final report = makeReport(failed: 1, hasOverflow: true);
      expect(shouldFail(report, {'arb'}), isFalse);
    });

    test('fail-on golden triggers on error message', () {
      final report = makeReport(failed: 1, errorMessage: 'Golden mismatch');
      expect(shouldFail(report, {'golden'}), isTrue);
    });

    test('fail-on golden does not trigger on overflow failures', () {
      final report = makeReport(failed: 1, hasOverflow: true);
      expect(shouldFail(report, {'golden'}), isFalse);
    });

    test('fail-on overflow,arb triggers on either', () {
      final overflowReport = makeReport(failed: 1, hasOverflow: true);
      final arbReport = makeReport(failed: 1, hasArb: true);
      expect(shouldFail(overflowReport, {'overflow', 'arb'}), isTrue);
      expect(shouldFail(arbReport, {'overflow', 'arb'}), isTrue);
    });

    test('fail-on overflow,arb does not trigger on golden-only', () {
      final report = makeReport(failed: 1, errorMessage: 'Golden mismatch');
      expect(shouldFail(report, {'overflow', 'arb'}), isFalse);
    });

    test('passing results never trigger regardless of category', () {
      final report = makeReport(failed: 0);
      expect(shouldFail(report, {'all'}), isFalse);
      expect(shouldFail(report, {'overflow'}), isFalse);
      expect(shouldFail(report, {'arb'}), isFalse);
      expect(shouldFail(report, {'golden'}), isFalse);
    });
  });

  // ── parseMachineOutput ───────────────────────────────────────────────────

  group('parseMachineOutput', () {
    final cfg = SweepConfig.load('/dev/null');

    test('parses successful test events', () {
      final output = [
        '{"type":"testStart","test":{"id":1,"name":"sweep: onboarding [EN · 393x852]"}}',
        '{"type":"testDone","testID":1,"result":"success","skipped":false}',
        '{"type":"testStart","test":{"id":2,"name":"sweep: onboarding [DE · 393x852]"}}',
        '{"type":"testDone","testID":2,"result":"success","skipped":false}',
      ].join('\n');

      final report = parseMachineOutput(output, cfg);
      expect(report.total, 2);
      expect(report.passed, 2);
      expect(report.failed, 0);
      expect(report.summary, 'All 2 variants passed.');
    });

    test('parses failed test with error', () {
      final output = [
        '{"type":"testStart","test":{"id":1,"name":"sweep: settings [EN · 393x852]"}}',
        '{"type":"error","testID":1,"error":"Golden file mismatch"}',
        '{"type":"testDone","testID":1,"result":"failure","skipped":false}',
      ].join('\n');

      final report = parseMachineOutput(output, cfg);
      expect(report.total, 1);
      expect(report.failed, 1);
      expect(report.results.first.errorMessage, 'Golden file mismatch');
      expect(report.results.first.passed, isFalse);
    });

    test('skips skipped tests', () {
      final output = [
        '{"type":"testStart","test":{"id":1,"name":"sweep: settings [EN · 393x852]"}}',
        '{"type":"testDone","testID":1,"result":"success","skipped":true}',
        '{"type":"testStart","test":{"id":2,"name":"sweep: settings [DE · 393x852]"}}',
        '{"type":"testDone","testID":2,"result":"success","skipped":false}',
      ].join('\n');

      final report = parseMachineOutput(output, cfg);
      expect(report.total, 1);
    });

    test('ignores tests without bracket labels', () {
      final output = [
        '{"type":"testStart","test":{"id":1,"name":"loading test"}}',
        '{"type":"testDone","testID":1,"result":"success","skipped":false}',
        '{"type":"testStart","test":{"id":2,"name":"sweep: settings [EN · 393x852]"}}',
        '{"type":"testDone","testID":2,"result":"success","skipped":false}',
      ].join('\n');

      final report = parseMachineOutput(output, cfg);
      expect(report.total, 1);
      expect(report.results.first.flowName, 'settings');
    });

    test('handles empty output', () {
      final report = parseMachineOutput('', cfg);
      expect(report.total, 0);
      expect(report.summary, 'All 0 variants passed.');
    });

    test('ignores non-JSON lines', () {
      final output = [
        'Loading test...',
        '{"type":"testStart","test":{"id":1,"name":"sweep: x [EN · 393x852]"}}',
        'Some random output',
        '{"type":"testDone","testID":1,"result":"success","skipped":false}',
      ].join('\n');

      final report = parseMachineOutput(output, cfg);
      expect(report.total, 1);
    });

    test('extracts variant details from test names', () {
      final output = [
        '{"type":"testStart","test":{"id":1,"name":"sweep: checkout [AR · RTL · Dark · 2.0x scale · 768x1024]"}}',
        '{"type":"testDone","testID":1,"result":"success","skipped":false}',
      ].join('\n');

      final report = parseMachineOutput(output, cfg);
      final r = report.results.first;
      expect(r.flowName, 'checkout');
      expect(r.variant.locale, 'ar');
      expect(r.variant.isRtl, isTrue);
      expect(r.variant.isDark, isTrue);
      expect(r.variant.textScale, 2.0);
      expect(r.variant.viewport.width, 768);
    });

    test('generates valid markdown/html/json in report', () {
      final output = [
        '{"type":"testStart","test":{"id":1,"name":"sweep: app [EN · 393x852]"}}',
        '{"type":"testDone","testID":1,"result":"success","skipped":false}',
      ].join('\n');

      final report = parseMachineOutput(output, cfg);
      expect(report.markdown, isNotEmpty);
      expect(report.html, contains('<!DOCTYPE html>'));
      final json = jsonDecode(report.json) as Map<String, dynamic>;
      expect(json['results'], isList);
    });

    test('mixed pass and fail produces correct summary', () {
      final output = [
        '{"type":"testStart","test":{"id":1,"name":"sweep: app [EN · 393x852]"}}',
        '{"type":"testDone","testID":1,"result":"success","skipped":false}',
        '{"type":"testStart","test":{"id":2,"name":"sweep: app [DE · 393x852]"}}',
        '{"type":"error","testID":2,"error":"mismatch"}',
        '{"type":"testDone","testID":2,"result":"failure","skipped":false}',
        '{"type":"testStart","test":{"id":3,"name":"sweep: app [AR · RTL · 393x852]"}}',
        '{"type":"testDone","testID":3,"result":"success","skipped":false}',
      ].join('\n');

      final report = parseMachineOutput(output, cfg);
      expect(report.total, 3);
      expect(report.passed, 2);
      expect(report.failed, 1);
      expect(report.summary, contains('1/3 variants failed'));
    });
  });

  // ── loadResults (file-based) ─────────────────────────────────────────────

  group('loadResults', () {
    final cfg = SweepConfig.load('/dev/null');

    test('returns null when directory does not exist', () {
      final result = loadResults(
        cfg,
        resultsPath:
            '/tmp/nonexistent_sweep_results_${DateTime.now().millisecondsSinceEpoch}',
      );
      expect(result, isNull);
    });

    test('returns null when directory is empty', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cli_');
      final result = loadResults(cfg, resultsPath: tmpDir.path);
      expect(result, isNull);
      tmpDir.deleteSync(recursive: true);
    });

    test('loads results from JSON files', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cli_');
      final results = [
        const SweepResult(
          flowName: 'onboarding',
          variant: SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
        ),
        const SweepResult(
          flowName: 'onboarding',
          variant: SweepVariant(
            locale: 'de',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: false,
          errorMessage: 'Golden mismatch',
        ),
      ];

      File(
        '${tmpDir.path}/onboarding.json',
      ).writeAsStringSync(jsonEncode(results.map((r) => r.toJson()).toList()));

      final report = loadResults(cfg, resultsPath: tmpDir.path);
      expect(report, isNotNull);
      expect(report!.total, 2);
      expect(report.passed, 1);
      expect(report.failed, 1);
      expect(report.summary, contains('1/2 variants failed'));

      tmpDir.deleteSync(recursive: true);
    });

    test('aggregates results from multiple JSON files', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cli_');

      final onboarding = [
        const SweepResult(
          flowName: 'onboarding',
          variant: SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
        ),
      ];
      final settings = [
        const SweepResult(
          flowName: 'settings',
          variant: SweepVariant(
            locale: 'en',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: true,
        ),
      ];

      File('${tmpDir.path}/onboarding.json').writeAsStringSync(
        jsonEncode(onboarding.map((r) => r.toJson()).toList()),
      );
      File(
        '${tmpDir.path}/settings.json',
      ).writeAsStringSync(jsonEncode(settings.map((r) => r.toJson()).toList()));

      final report = loadResults(cfg, resultsPath: tmpDir.path);
      expect(report!.total, 2);
      expect(report.summary, 'All 2 variants passed.');

      tmpDir.deleteSync(recursive: true);
    });

    test('skips non-JSON files in results directory', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cli_');

      File('${tmpDir.path}/notes.txt').writeAsStringSync('not json');
      File('${tmpDir.path}/onboarding.json').writeAsStringSync(
        jsonEncode([
          const SweepResult(
            flowName: 'onboarding',
            variant: SweepVariant(
              locale: 'en',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: true,
          ).toJson(),
        ]),
      );

      final report = loadResults(cfg, resultsPath: tmpDir.path);
      expect(report!.total, 1);

      tmpDir.deleteSync(recursive: true);
    });

    test('handles corrupt JSON files gracefully', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cli_');

      File('${tmpDir.path}/bad.json').writeAsStringSync('not valid json{{{');
      File('${tmpDir.path}/good.json').writeAsStringSync(
        jsonEncode([
          const SweepResult(
            flowName: 'app',
            variant: SweepVariant(
              locale: 'en',
              textScale: 1.0,
              viewport: ViewportPreset.phone,
            ),
            passed: true,
          ).toJson(),
        ]),
      );

      final report = loadResults(cfg, resultsPath: tmpDir.path);
      expect(report!.total, 1);

      tmpDir.deleteSync(recursive: true);
    });

    test('summary includes overflow and arb counts', () {
      final tmpDir = Directory.systemTemp.createTempSync('sweep_cli_');

      final results = [
        const SweepResult(
          flowName: 'app',
          variant: SweepVariant(
            locale: 'de',
            textScale: 1.0,
            viewport: ViewportPreset.phone,
          ),
          passed: false,
          overflows: [OverflowError(message: 'overflowed by 10px')],
          arbIssues: [
            ArbIssue(
              type: ArbIssueType.missingKey,
              locale: 'de',
              detail: 'missing: title',
            ),
            ArbIssue(
              type: ArbIssueType.missingKey,
              locale: 'de',
              detail: 'missing: subtitle',
            ),
          ],
        ),
      ];

      File(
        '${tmpDir.path}/app.json',
      ).writeAsStringSync(jsonEncode(results.map((r) => r.toJson()).toList()));

      final report = loadResults(cfg, resultsPath: tmpDir.path);
      expect(report!.summary, contains('1 overflow(s)'));
      expect(report.summary, contains('2 ARB issue(s)'));

      tmpDir.deleteSync(recursive: true);
    });
  });

  // ── ParsedReport structure ───────────────────────────────────────────────

  group('ParsedReport', () {
    test('fields are accessible', () {
      final report = ParsedReport(
        markdown: '# Report',
        json: '{}',
        html: '<html></html>',
        summary: 'All passed',
        total: 5,
        passed: 5,
        failed: 0,
        results: [],
      );
      expect(report.total, 5);
      expect(report.passed, 5);
      expect(report.failed, 0);
      expect(report.markdown, '# Report');
      expect(report.summary, 'All passed');
    });
  });
}
