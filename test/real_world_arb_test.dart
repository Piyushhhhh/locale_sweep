import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

const _spotubeArbDir = '/tmp/locale_sweep_test/spotube/lib/l10n';
const _wgerArbDir = '/tmp/locale_sweep_test/wger/lib/l10n';

bool _hasFixture(String path) => Directory(path).existsSync();

void _skipUnless(String path) {
  if (!_hasFixture(path)) {
    markTestSkipped('ARB fixtures not found at $path');
  }
}

void main() {
  group('Spotube (48k+ stars) ARB analysis', () {
    ArbReport? report;

    setUpAll(() {
      if (!_hasFixture(_spotubeArbDir)) return;
      report = ArbAnalyzer.analyze(
        arbDir: _spotubeArbDir,
        locales: ['en', 'de', 'ar', 'ja', 'fr', 'es', 'ko', 'zh'],
      );
    });

    test('finds locale ARB files without error', () {
      _skipUnless(_spotubeArbDir);
      if (report == null) return;
      final fileIssues = report!.issues
          .where((i) => i.type == ArbIssueType.missingFile)
          .toList();
      expect(fileIssues, isEmpty, reason: 'All target locales should exist');
      print('Spotube: analyzed ${report!.byLocale.keys.length} locales');
    });

    test('German (de) coverage', () {
      _skipUnless(_spotubeArbDir);
      if (report == null) return;
      final deIssues = report!.issuesForLocale('de');
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
      _skipUnless(_spotubeArbDir);
      if (report == null) return;
      final arIssues = report!.issuesForLocale('ar');
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
      _skipUnless(_spotubeArbDir);
      if (report == null) return;
      final jaIssues = report!.issuesForLocale('ja');
      print('Spotube JA: ${jaIssues.length} total issues');
      for (final issue in jaIssues.take(5)) {
        print('  ${issue.type.name}: ${issue.detail}');
      }
    });

    test('base locale (en) has no issues', () {
      _skipUnless(_spotubeArbDir);
      if (report == null) return;
      final enIssues = report!.issuesForLocale('en');
      expect(enIssues, isEmpty, reason: 'Base locale should have no issues');
    });
  });

  group('wger Workout Manager (960+ stars) ARB analysis', () {
    ArbReport? report;

    setUpAll(() {
      if (!_hasFixture(_wgerArbDir)) return;
      report = ArbAnalyzer.analyze(
        arbDir: _wgerArbDir,
        locales: ['en', 'de', 'ar', 'fr', 'es', 'ja', 'he', 'tr'],
      );
    });

    test('finds locale ARB files', () {
      _skipUnless(_wgerArbDir);
      if (report == null) return;
      final fileIssues = report!.issues
          .where((i) => i.type == ArbIssueType.missingFile)
          .toList();
      print('wger: analyzed, ${fileIssues.length} missing file(s)');
    });

    test('German (de) has good coverage', () {
      _skipUnless(_wgerArbDir);
      if (report == null) return;
      final deIssues = report!.issuesForLocale('de');
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
      _skipUnless(_wgerArbDir);
      if (report == null) return;
      final arIssues = report!.issuesForLocale('ar');
      final missing =
          arIssues.where((i) => i.type == ArbIssueType.missingKey).toList();
      final placeholders = arIssues
          .where((i) => i.type == ArbIssueType.placeholderMismatch)
          .toList();

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
      _skipUnless(_wgerArbDir);
      if (report == null) return;
      final heIssues = report!.issuesForLocale('he');
      final missing =
          heIssues.where((i) => i.type == ArbIssueType.missingKey).toList();
      print('wger HE: ${missing.length} missing keys');
    });

    test('base locale (en) has no issues', () {
      _skipUnless(_wgerArbDir);
      if (report == null) return;
      final enIssues = report!.issuesForLocale('en');
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
      arbDir: _hasFixture(_spotubeArbDir) ? _spotubeArbDir : null,
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
      arbDir: _hasFixture(_wgerArbDir) ? _wgerArbDir : null,
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
