import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ArbAnalyzer {
  static ArbReport analyze({
    required String arbDir,
    List<String> locales = const ['en', 'de', 'ar', 'ja'],
    String baseLocale = 'en',
  }) {
    final dir = Directory(arbDir);
    if (!dir.existsSync()) {
      return ArbReport(
        issues: [
          ArbIssue(
            type: ArbIssueType.missingFile,
            locale: baseLocale,
            detail: 'ARB directory not found: $arbDir',
          ),
        ],
      );
    }

    final arbFiles = <String, Map<String, dynamic>>{};
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.arb')) continue;
      final name = p.basenameWithoutExtension(file.path);
      final locale = _extractLocale(name);
      if (locale == null) continue;
      try {
        arbFiles[locale] =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } catch (e) {
        arbFiles[locale] = {};
      }
    }

    final baseArb = arbFiles[baseLocale];
    if (baseArb == null) {
      return ArbReport(
        issues: [
          ArbIssue(
            type: ArbIssueType.missingFile,
            locale: baseLocale,
            detail: 'Base ARB file for "$baseLocale" not found in $arbDir',
          ),
        ],
      );
    }

    final baseKeys = baseArb.keys
        .where((k) => !k.startsWith('@') && !k.startsWith('@@'))
        .toSet();
    final basePlaceholders = <String, Set<String>>{};
    for (final key in baseKeys) {
      final meta = baseArb['@$key'];
      if (meta is Map && meta['placeholders'] is Map) {
        basePlaceholders[key] = (meta['placeholders'] as Map).keys
            .cast<String>()
            .toSet();
      }
    }

    final issues = <ArbIssue>[];

    for (final locale in locales) {
      if (locale == baseLocale) continue;

      final arb = arbFiles[locale];
      if (arb == null) {
        issues.add(
          ArbIssue(
            type: ArbIssueType.missingFile,
            locale: locale,
            detail: 'No ARB file for locale "$locale"',
          ),
        );
        continue;
      }

      final targetKeys = arb.keys
          .where((k) => !k.startsWith('@') && !k.startsWith('@@'))
          .toSet();

      for (final key in baseKeys) {
        if (!targetKeys.contains(key)) {
          issues.add(
            ArbIssue(
              type: ArbIssueType.missingKey,
              locale: locale,
              key: key,
              detail: 'Key "$key" missing in $locale (present in $baseLocale)',
            ),
          );
          continue;
        }

        final expectedPlaceholders = basePlaceholders[key];
        if (expectedPlaceholders != null && expectedPlaceholders.isNotEmpty) {
          final value = arb[key];
          if (value is String) {
            for (final ph in expectedPlaceholders) {
              if (!value.contains('{$ph}')) {
                issues.add(
                  ArbIssue(
                    type: ArbIssueType.placeholderMismatch,
                    locale: locale,
                    key: key,
                    detail:
                        'Placeholder {$ph} missing in $locale value for "$key"',
                  ),
                );
              }
            }
          }
        }
      }
    }

    return ArbReport(issues: issues);
  }

  static String? _extractLocale(String filename) {
    final match = RegExp(r'_([a-z]{2}(?:_[A-Z]{2})?)$').firstMatch(filename);
    return match?.group(1);
  }
}

class ArbReport {
  final List<ArbIssue> issues;

  const ArbReport({this.issues = const []});

  bool get hasIssues => issues.isNotEmpty;

  List<ArbIssue> issuesForLocale(String locale) =>
      issues.where((i) => i.locale == locale).toList();

  Map<String, List<ArbIssue>> get byLocale {
    final map = <String, List<ArbIssue>>{};
    for (final issue in issues) {
      map.putIfAbsent(issue.locale, () => []).add(issue);
    }
    return map;
  }
}

enum ArbIssueType { missingFile, missingKey, placeholderMismatch }

class ArbIssue {
  final ArbIssueType type;
  final String locale;
  final String? key;
  final String detail;

  const ArbIssue({
    required this.type,
    required this.locale,
    this.key,
    required this.detail,
  });

  @override
  String toString() => detail;
}
