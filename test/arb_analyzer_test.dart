import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  group('ArbAnalyzer', () {
    group('broken fixture', () {
      late ArbReport report;

      setUp(() {
        report = ArbAnalyzer.analyze(
          arbDir: 'test/fixtures/broken_localized_app/l10n',
          locales: ['en', 'de', 'ar'],
        );
      });

      test('detects missing key in German locale', () {
        final missingKeys = report.issues
            .where((i) => i.type == ArbIssueType.missingKey)
            .toList();
        expect(missingKeys, isNotEmpty);
        expect(
          missingKeys.any((i) => i.key == 'settingsTitle' && i.locale == 'de'),
          isTrue,
          reason: 'German ARB is missing settingsTitle',
        );
      });

      test('detects ICU placeholder mismatch in Arabic locale', () {
        final placeholderIssues = report.issues
            .where((i) => i.type == ArbIssueType.placeholderMismatch)
            .toList();
        expect(placeholderIssues, isNotEmpty);

        final arabicCountIssues = placeholderIssues
            .where((i) => i.locale == 'ar' && i.key == 'itemCount')
            .toList();
        expect(
          arabicCountIssues,
          isNotEmpty,
          reason: 'Arabic itemCount is missing {count} placeholder',
        );
        expect(arabicCountIssues.first.detail, contains('{count}'));
      });

      test('detects multiple placeholder mismatches', () {
        final arabicPlaceholderIssues = report.issues
            .where(
              (i) =>
                  i.type == ArbIssueType.placeholderMismatch &&
                  i.locale == 'ar',
            )
            .toList();
        expect(
          arabicPlaceholderIssues.any((i) => i.key == 'greeting'),
          isTrue,
          reason: 'Arabic greeting is missing {count} placeholder',
        );
      });

      test('ignores @-prefixed metadata keys', () {
        for (final issue in report.issues) {
          if (issue.key != null) {
            expect(
              issue.key!.startsWith('@'),
              isFalse,
              reason:
                  'Metadata key "${issue.key}" should not appear as an issue',
            );
          }
        }
      });

      test('ignores @@locale metadata', () {
        for (final issue in report.issues) {
          if (issue.key != null) {
            expect(
              issue.key!.startsWith('@@'),
              isFalse,
              reason: '@@locale should not appear as an issue',
            );
          }
        }
      });

      test('issue detail messages are actionable', () {
        for (final issue in report.issues) {
          expect(issue.detail, isNotEmpty);
          expect(issue.locale, isNotEmpty);
          if (issue.type == ArbIssueType.missingKey) {
            expect(issue.detail, contains('missing'));
            expect(issue.detail, contains(issue.locale));
          }
          if (issue.type == ArbIssueType.placeholderMismatch) {
            expect(issue.detail, contains('Placeholder'));
            expect(issue.detail, contains(issue.locale));
          }
        }
      });
    });

    group('clean fixture', () {
      test('reports no issues', () {
        final report = ArbAnalyzer.analyze(
          arbDir: 'test/fixtures/clean_localized_app/l10n',
          locales: ['en', 'de', 'ar'],
        );
        expect(report.hasIssues, isFalse);
        expect(report.issues, isEmpty);
      });
    });

    group('ICU plural/select syntax', () {
      late ArbReport report;

      setUp(() {
        report = ArbAnalyzer.analyze(
          arbDir: 'test/fixtures/icu_localized_app/l10n',
          locales: ['en', 'de', 'ar', 'ja'],
        );
      });

      test('no false positives on correct ICU plural translations', () {
        final deIssues = report.issues
            .where(
              (i) =>
                  i.locale == 'de' &&
                  i.type == ArbIssueType.placeholderMismatch,
            )
            .toList();
        expect(
          deIssues,
          isEmpty,
          reason:
              'German uses correct ICU plural/select — no mismatches expected',
        );
      });

      test('no false positives on Arabic ICU plural with many forms', () {
        final arIssues = report.issues
            .where(
              (i) =>
                  i.locale == 'ar' &&
                  i.type == ArbIssueType.placeholderMismatch,
            )
            .toList();
        expect(
          arIssues,
          isEmpty,
          reason:
              'Arabic uses correct ICU plural/select — no mismatches expected',
        );
      });

      test('detects genuinely missing placeholders in ICU context', () {
        final jaIssues = report.issues
            .where(
              (i) =>
                  i.locale == 'ja' &&
                  i.type == ArbIssueType.placeholderMismatch,
            )
            .toList();
        expect(
          jaIssues,
          isNotEmpty,
          reason: 'Japanese genderGreeting is missing {gender} and {name}',
        );

        final missingGender = jaIssues.where(
          (i) => i.key == 'genderGreeting' && i.detail.contains('{gender}'),
        );
        expect(missingGender, isNotEmpty);

        final missingName = jaIssues.where(
          (i) => i.key == 'genderGreeting' && i.detail.contains('{name}'),
        );
        expect(missingName, isNotEmpty);
      });

      test(
        'detects missing placeholder in simple string even with ICU fixture',
        () {
          final jaSimple = report.issues
              .where(
                (i) =>
                    i.locale == 'ja' &&
                    i.key == 'simpleGreeting' &&
                    i.type == ArbIssueType.placeholderMismatch,
              )
              .toList();
          expect(
            jaSimple,
            isNotEmpty,
            reason: 'Japanese simpleGreeting is missing {name}',
          );
        },
      );

      test('detects missing {name} in complexMessage but not {count}', () {
        final jaComplex = report.issues
            .where(
              (i) =>
                  i.locale == 'ja' &&
                  i.key == 'complexMessage' &&
                  i.type == ArbIssueType.placeholderMismatch,
            )
            .toList();
        expect(
          jaComplex.length,
          1,
          reason: 'Only {name} is missing — {count} is present in ICU plural',
        );
        expect(jaComplex.first.detail, contains('{name}'));
      });

      test(
        'handles {count, plural, ...} without flagging count as missing',
        () {
          final allCountIssues = report.issues
              .where(
                (i) =>
                    i.type == ArbIssueType.placeholderMismatch &&
                    i.detail.contains('{count}'),
              )
              .toList();
          // Only Japanese complexMessage should be missing count-related issues
          // German and Arabic should have zero count placeholder issues
          final deArCount = allCountIssues
              .where((i) => i.locale == 'de' || i.locale == 'ar')
              .toList();
          expect(deArCount, isEmpty);
        },
      );

      test(
        'handles {gender, select, ...} without flagging gender as missing',
        () {
          final deGender = report.issues
              .where(
                (i) =>
                    i.locale == 'de' &&
                    i.key == 'genderGreeting' &&
                    i.type == ArbIssueType.placeholderMismatch,
              )
              .toList();
          expect(
            deGender,
            isEmpty,
            reason:
                'German genderGreeting uses {gender, select, ...} — should not flag',
          );
        },
      );
    });

    group('edge cases', () {
      test('reports missingFile when directory does not exist', () {
        final report = ArbAnalyzer.analyze(
          arbDir: 'test/fixtures/nonexistent_directory/l10n',
          locales: ['en', 'de'],
        );
        expect(report.hasIssues, isTrue);
        expect(report.issues.first.type, ArbIssueType.missingFile);
        expect(report.issues.first.detail, contains('not found'));
      });

      test('reports missingFile when requested locale has no ARB', () {
        final report = ArbAnalyzer.analyze(
          arbDir: 'test/fixtures/clean_localized_app/l10n',
          locales: ['en', 'de', 'ar', 'ja'],
        );
        final jaIssues = report.issuesForLocale('ja');
        expect(jaIssues, isNotEmpty);
        expect(jaIssues.first.type, ArbIssueType.missingFile);
      });

      test('byLocale groups issues correctly', () {
        final report = ArbAnalyzer.analyze(
          arbDir: 'test/fixtures/broken_localized_app/l10n',
          locales: ['en', 'de', 'ar'],
        );
        final byLocale = report.byLocale;
        expect(byLocale.containsKey('de'), isTrue);
        expect(byLocale.containsKey('ar'), isTrue);
        expect(
          byLocale.containsKey('en'),
          isFalse,
          reason: 'Base locale should have no issues',
        );
      });
    });
  });
}
