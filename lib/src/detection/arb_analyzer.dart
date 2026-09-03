import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Static analyzer for ARB (Application Resource Bundle) translation files.
///
/// Detects missing keys and placeholder mismatches by comparing target locale
/// ARB files against the base locale.
class ArbAnalyzer {
  /// Analyzes ARB files in [arbDir] for missing keys and placeholder issues.
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

        final value = arb[key];
        final baseValue = baseArb[key];

        if (value is String && baseValue is String && value == baseValue) {
          issues.add(
            ArbIssue(
              type: ArbIssueType.untranslated,
              locale: locale,
              key: key,
              detail:
                  'Key "$key" in $locale is identical to $baseLocale (possibly untranslated)',
            ),
          );
        }

        final expectedPlaceholders = basePlaceholders[key];
        if (expectedPlaceholders != null && expectedPlaceholders.isNotEmpty) {
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

/// Result of an ARB analysis containing all detected issues.
class ArbReport {
  /// All issues found across all analyzed locales.
  final List<ArbIssue> issues;

  /// Creates an ARB report.
  const ArbReport({this.issues = const []});

  /// Whether any issues were detected.
  bool get hasIssues => issues.isNotEmpty;

  /// Returns issues for a specific [locale].
  List<ArbIssue> issuesForLocale(String locale) =>
      issues.where((i) => i.locale == locale).toList();

  /// Groups issues by locale.
  Map<String, List<ArbIssue>> get byLocale {
    final map = <String, List<ArbIssue>>{};
    for (final issue in issues) {
      map.putIfAbsent(issue.locale, () => []).add(issue);
    }
    return map;
  }
}

/// The type of issue found during ARB analysis.
enum ArbIssueType {
  /// An expected ARB file was not found.
  missingFile,

  /// A key present in the base locale is missing in the target locale.
  missingKey,

  /// A placeholder (e.g. `{count}`) is in the base but missing in the target.
  placeholderMismatch,

  /// A key's value is identical to the base locale (possibly untranslated).
  untranslated,
}

/// A single issue found during ARB analysis.
class ArbIssue {
  /// The category of this issue.
  final ArbIssueType type;

  /// The locale where this issue was found.
  final String locale;

  /// The ARB key involved, if applicable.
  final String? key;

  /// Human-readable description of the issue.
  final String detail;

  const ArbIssue({
    required this.type,
    required this.locale,
    this.key,
    required this.detail,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'locale': locale,
    'key': key,
    'detail': detail,
  };

  factory ArbIssue.fromJson(Map<String, dynamic> json) => ArbIssue(
    type: ArbIssueType.values.byName(json['type'] as String),
    locale: json['locale'] as String,
    key: json['key'] as String?,
    detail: json['detail'] as String,
  );

  @override
  String toString() => detail;
}
