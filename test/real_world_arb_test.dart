import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  group('Spotube (48k+ stars) ARB analysis', () {
    late ArbReport report;

    setUpAll(() {
      report = ArbAnalyzer.analyze(
        arbDir: '/tmp/locale_sweep_test/spotube/lib/l10n',
        locales: ['en', 'de', 'ar', 'ja', 'fr', 'es', 'ko', 'zh'],
      );
    });

    test('finds locale ARB files without error', () {
      final fileIssues = report.issues
          .where((i) => i.type == ArbIssueType.missingFile)
          .toList();
      expect(fileIssues, isEmpty, reason: 'All target locales should exist');
      print('Spotube: analyzed ${report.byLocale.keys.length} locales');
    });

    test('German (de) coverage', () {
      final deIssues = report.issuesForLocale('de');
      final missing =
          deIssues.where((i) => i.type == ArbIssueType.missingKey).toList();
      final placeholders = deIssues
          .where((i) => i.type == ArbIssueType.placeholderMismatch)
          .toList();
      print('Spotube DE: ${missing.length} missing, '
          '${placeholders.length} placeholder mismatches');
      for (final issue in deIssues.take(5)) {
        print('  ${issue.type.name}: ${issue.detail}');
      }
    });

    test('Arabic (ar) coverage', () {
      final arIssues = report.issuesForLocale('ar');
      final missing =
          arIssues.where((i) => i.type == ArbIssueType.missingKey).toList();
      final placeholders = arIssues
          .where((i) => i.type == ArbIssueType.placeholderMismatch)
          .toList();
      print('Spotube AR: ${missing.length} missing, '
          '${placeholders.length} placeholder mismatches');
      for (final issue in arIssues.take(5)) {
        print('  ${issue.type.name}: ${issue.detail}');
      }
    });

    test('Japanese (ja) coverage', () {
      final jaIssues = report.issuesForLocale('ja');
      print('Spotube JA: ${jaIssues.length} total issues');
      for (final issue in jaIssues.take(5)) {
        print('  ${issue.type.name}: ${issue.detail}');
      }
    });

    test('base locale (en) has no issues', () {
      final enIssues = report.issuesForLocale('en');
      expect(enIssues, isEmpty, reason: 'Base locale should have no issues');
    });
  });

  group('wger Workout Manager (960+ stars) ARB analysis', () {
    late ArbReport report;

    setUpAll(() {
      report = ArbAnalyzer.analyze(
        arbDir: '/tmp/locale_sweep_test/wger/lib/l10n',
        locales: ['en', 'de', 'ar', 'fr', 'es', 'ja', 'he', 'tr'],
      );
    });

    test('finds locale ARB files', () {
      final fileIssues = report.issues
          .where((i) => i.type == ArbIssueType.missingFile)
          .toList();
      print('wger: analyzed, ${fileIssues.length} missing file(s)');
    });

    test('German (de) has good coverage', () {
      final deIssues = report.issuesForLocale('de');
      final missing =
          deIssues.where((i) => i.type == ArbIssueType.missingKey).toList();
      final placeholders = deIssues
          .where((i) => i.type == ArbIssueType.placeholderMismatch)
          .toList();
      print('wger DE: ${missing.length} missing, '
          '${placeholders.length} placeholder mismatches');
      for (final issue in deIssues.take(5)) {
        print('  ${issue.type.name}: ${issue.detail}');
      }
    });

    test('Arabic (ar) has significant missing translations', () {
      final arIssues = report.issuesForLocale('ar');
      final missing =
          arIssues.where((i) => i.type == ArbIssueType.missingKey).toList();
      final placeholders = arIssues
          .where((i) => i.type == ArbIssueType.placeholderMismatch)
          .toList();

      // wger has ~165 missing Arabic keys — real bugs
      expect(
        missing.length,
        greaterThan(100),
        reason: 'wger Arabic locale has significant missing translations',
      );

      print('wger AR: ${missing.length} missing keys, '
          '${placeholders.length} placeholder mismatches');
      print('Sample missing keys:');
      for (final issue in missing.take(10)) {
        print('  ${issue.key}');
      }
      if (placeholders.isNotEmpty) {
        print('Placeholder mismatches:');
        for (final issue in placeholders) {
          print('  ${issue.detail}');
        }
      }
    });

    test('Hebrew (he) coverage', () {
      final heIssues = report.issuesForLocale('he');
      final missing =
          heIssues.where((i) => i.type == ArbIssueType.missingKey).toList();
      print('wger HE: ${missing.length} missing keys');
    });

    test('base locale (en) has no issues', () {
      final enIssues = report.issuesForLocale('en');
      expect(enIssues, isEmpty, reason: 'Base locale should have no issues');
    });
  });

  group('sweepTest end-to-end with Spotube ARBs', () {
    clearSweepResults();

    sweepTest(
      'spotube_layout',
      builder: () => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Now Playing'),
                Text('Artist — Album'),
                SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.skip_previous),
                    SizedBox(width: 24),
                    Icon(Icons.play_arrow, size: 48),
                    SizedBox(width: 24),
                    Icon(Icons.skip_next),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      locales: ['en', 'de', 'ar', 'ja'],
      textScales: [1.0, 2.0],
      viewports: [ViewportPreset.phone],
      arbDir: '/tmp/locale_sweep_test/spotube/lib/l10n',
      captureScreenshots: false,
    );

    tearDownAll(() {
      final results =
          sweepResults.where((r) => r.flowName == 'spotube_layout').toList();
      final summary = SweepRunSummary(results: results);

      print('\n=== Spotube sweepTest Summary ===');
      print('Variants: ${summary.total}, Passed: ${summary.passed}, '
          'Failed: ${summary.failed}');
      print('Overflows: ${summary.overflowCount}, '
          'ARB issues: ${summary.arbIssueCount}');

      for (final r in results.where((r) => r.arbIssues.isNotEmpty)) {
        print('  ${r.variant.locale}: ${r.arbIssues.length} ARB issues');
      }
    });
  });

  group('sweepTest end-to-end with wger ARBs', () {
    clearSweepResults();

    sweepTest(
      'wger_layout',
      builder: () => const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workout Plan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('Bench Press: 3 x 10 @ 80kg'),
                Text('Squat: 4 x 8 @ 100kg'),
                Text('Deadlift: 3 x 5 @ 120kg'),
              ],
            ),
          ),
        ),
      ),
      locales: ['en', 'de', 'ar'],
      textScales: [1.0, 2.0],
      viewports: [ViewportPreset.phone, ViewportPreset.phoneSmall],
      arbDir: '/tmp/locale_sweep_test/wger/lib/l10n',
      captureScreenshots: false,
    );

    tearDownAll(() {
      final results =
          sweepResults.where((r) => r.flowName == 'wger_layout').toList();
      final summary = SweepRunSummary(results: results);

      print('\n=== wger sweepTest Summary ===');
      print('Variants: ${summary.total}, Passed: ${summary.passed}, '
          'Failed: ${summary.failed}');
      print('Overflows: ${summary.overflowCount}, '
          'ARB issues: ${summary.arbIssueCount}');

      for (final r in results) {
        final issueCount = r.arbIssues.length;
        if (issueCount > 0) {
          print('  ${r.variant.displayLabel}: $issueCount ARB issues');
        }
      }
    });
  });
}
