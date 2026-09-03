import 'dart:convert';

import 'sweep_result.dart';

/// Generates Markdown and JSON reports from sweep results.
class ReportGenerator {
  /// Generates a Markdown report with failure table and locale summary.
  ///
  /// [screenshotLinkBuilder] customizes how screenshot paths are rendered.
  /// Defaults to a Markdown image link. Pass a custom builder for CI
  /// environments where local paths are not accessible.
  static String generateMarkdown(
    SweepRunSummary summary, {
    String Function(String path)? screenshotLinkBuilder,
  }) {
    final buf = StringBuffer();

    buf.writeln('# LocaleSweep Report');
    buf.writeln();

    if (summary.failed == 0) {
      buf.writeln(
        '**All ${summary.total} variants passed** across ${summary.byLocale.length} locales and ${summary.byFlow.length} flows.',
      );
      buf.writeln();
      return buf.toString();
    }

    buf.writeln(
      '**${summary.failed}/${summary.total} variants failed** across ${summary.byLocale.length} locales and ${summary.byFlow.length} flows.',
    );
    buf.writeln();

    if (summary.overflowCount > 0) {
      buf.writeln('- ${summary.overflowCount} overflow errors');
    }
    if (summary.arbIssueCount > 0) {
      buf.writeln('- ${summary.arbIssueCount} ARB translation issues');
    }
    buf.writeln();

    buf.writeln('## Failures');
    buf.writeln();

    for (final entry in summary.byFlow.entries) {
      final failures = entry.value.where((r) => r.hasIssues).toList();
      if (failures.isEmpty) continue;

      buf.writeln('### ${entry.key}');
      buf.writeln();
      buf.writeln('| Locale | Scale | Viewport | Issue | Screenshot |');
      buf.writeln('|--------|-------|----------|-------|------------|');

      for (final r in failures) {
        final issues = <String>[];

        for (final o in r.overflows) {
          issues.add(
            'Overflow${o.pixels != null ? " (${o.pixels!.toStringAsFixed(0)}px)" : ""}',
          );
        }
        for (final a in r.arbIssues) {
          issues.add('${a.type.name}: ${a.key ?? a.detail}');
        }
        if (r.errorMessage != null) {
          final msg = r.errorMessage!.length > 80
              ? '${r.errorMessage!.substring(0, 80)}...'
              : r.errorMessage!;
          issues.add('Error: $msg');
        }

        final detail = issues.join('<br>');
        final screenshotLink = r.screenshotPath != null
            ? (screenshotLinkBuilder != null
                  ? screenshotLinkBuilder(r.screenshotPath!)
                  : '![${r.variant.label}](${r.screenshotPath})')
            : '';

        buf.writeln(
          '| ${r.variant.locale} | ${r.variant.textScale}x | ${r.variant.viewport.name} | $detail | $screenshotLink |',
        );
      }
      buf.writeln();
    }

    buf.writeln('## Locale Summary');
    buf.writeln();
    buf.writeln('| Locale | Passed | Failed | Overflows | ARB Issues |');
    buf.writeln('|--------|--------|--------|-----------|------------|');

    for (final entry in summary.byLocale.entries) {
      final results = entry.value;
      final p = results.where((r) => !r.hasIssues).length;
      final f = results.length - p;
      final o = results.fold(0, (sum, r) => sum + r.overflows.length);
      final a = results.fold(0, (sum, r) => sum + r.arbIssues.length);
      buf.writeln('| ${entry.key} | $p | $f | $o | $a |');
    }
    buf.writeln();

    return buf.toString();
  }

  /// Generates a self-contained HTML report with visual gallery.
  ///
  /// Screenshots are referenced by relative path. The report includes
  /// flow grouping, pass/fail badges, locale filters, and issue details.
  /// [screenshotBasePath] is stripped from screenshot paths to make them
  /// relative to the HTML file location.
  static String generateHtml(
    SweepRunSummary summary, {
    String screenshotBasePath = '',
  }) {
    final buf = StringBuffer();

    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="en">');
    buf.writeln('<head>');
    buf.writeln('<meta charset="UTF-8">');
    buf.writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
    );
    buf.writeln('<title>LocaleSweep Report</title>');
    buf.writeln('<style>');
    buf.writeln(_htmlStyles);
    buf.writeln('</style>');
    buf.writeln('</head>');
    buf.writeln('<body>');

    // Header
    buf.writeln('<header>');
    buf.writeln('<h1>LocaleSweep Report</h1>');
    buf.writeln(
      '<p class="timestamp">Generated ${summary.timestamp.toLocal()}</p>',
    );
    buf.writeln('</header>');

    // Summary cards
    buf.writeln('<section class="summary">');
    _htmlSummaryCard(buf, '${summary.total}', 'Total', 'total');
    _htmlSummaryCard(buf, '${summary.passed}', 'Passed', 'pass');
    _htmlSummaryCard(buf, '${summary.failed}', 'Failed', 'fail');
    _htmlSummaryCard(buf, '${summary.overflowCount}', 'Overflows', 'warn');
    _htmlSummaryCard(buf, '${summary.arbIssueCount}', 'ARB Issues', 'warn');
    buf.writeln('</section>');

    // Filters
    final locales = summary.byLocale.keys.toList()..sort();
    final flows = summary.byFlow.keys.toList()..sort();
    buf.writeln('<section class="filters">');
    buf.writeln('<div class="filter-group">');
    buf.writeln('<label>Status:</label>');
    buf.writeln(
      '<button class="filter-btn active" data-filter="status" data-value="all">All</button>',
    );
    buf.writeln(
      '<button class="filter-btn" data-filter="status" data-value="fail">Failed</button>',
    );
    buf.writeln(
      '<button class="filter-btn" data-filter="status" data-value="pass">Passed</button>',
    );
    buf.writeln('</div>');
    buf.writeln('<div class="filter-group">');
    buf.writeln('<label>Locale:</label>');
    buf.writeln(
      '<button class="filter-btn active" data-filter="locale" data-value="all">All</button>',
    );
    for (final locale in locales) {
      buf.writeln(
        '<button class="filter-btn" data-filter="locale" data-value="$locale">${locale.toUpperCase()}</button>',
      );
    }
    buf.writeln('</div>');
    if (flows.length > 1) {
      buf.writeln('<div class="filter-group">');
      buf.writeln('<label>Flow:</label>');
      buf.writeln(
        '<button class="filter-btn active" data-filter="flow" data-value="all">All</button>',
      );
      for (final flow in flows) {
        buf.writeln(
          '<button class="filter-btn" data-filter="flow" data-value="$flow">$flow</button>',
        );
      }
      buf.writeln('</div>');
    }
    buf.writeln('</section>');

    // Flow sections with cards
    for (final entry in summary.byFlow.entries) {
      final flowName = entry.key;
      final results = entry.value;

      buf.writeln('<section class="flow-section" data-flow="$flowName">');
      buf.writeln('<h2>$flowName</h2>');
      buf.writeln('<div class="card-grid">');

      for (final r in results) {
        final status = r.hasIssues ? 'fail' : 'pass';
        final locale = r.variant.locale;
        final brightness = r.variant.isDark ? 'dark' : 'light';

        buf.writeln(
          '<div class="card $status" data-locale="$locale" data-status="$status" data-brightness="$brightness">',
        );

        // Screenshot
        if (r.screenshotPath != null) {
          var imgPath = r.screenshotPath!;
          if (screenshotBasePath.isNotEmpty &&
              imgPath.startsWith(screenshotBasePath)) {
            imgPath = imgPath.substring(screenshotBasePath.length);
            if (imgPath.startsWith('/')) imgPath = imgPath.substring(1);
          }
          buf.writeln(
            '<div class="card-img"><img src="$imgPath" alt="${r.variant.displayLabel}" loading="lazy"></div>',
          );
        } else {
          buf.writeln(
            '<div class="card-img card-img-empty">No screenshot</div>',
          );
        }

        // Info
        buf.writeln('<div class="card-info">');
        buf.writeln(
          '<span class="badge badge-$status">${status == 'pass' ? 'PASS' : 'FAIL'}</span>',
        );
        if (r.variant.isDark) {
          buf.writeln('<span class="badge badge-dark">DARK</span>');
        }
        if (r.variant.isRtl) {
          buf.writeln('<span class="badge badge-rtl">RTL</span>');
        }
        buf.writeln(
          '<div class="card-label">${_htmlEscape(r.variant.displayLabel)}</div>',
        );

        // Issues
        if (r.hasIssues) {
          buf.writeln('<div class="card-issues">');
          for (final o in r.overflows) {
            buf.writeln(
              '<div class="issue overflow">Overflow${o.pixels != null ? ' (${o.pixels!.toStringAsFixed(0)}px)' : ''}</div>',
            );
          }
          for (final a in r.arbIssues) {
            buf.writeln(
              '<div class="issue arb">${_htmlEscape(a.type.name)}: ${_htmlEscape(a.key ?? a.detail)}</div>',
            );
          }
          if (r.errorMessage != null) {
            final msg = r.errorMessage!.length > 120
                ? '${r.errorMessage!.substring(0, 120)}...'
                : r.errorMessage!;
            buf.writeln('<div class="issue error">${_htmlEscape(msg)}</div>');
          }
          buf.writeln('</div>');
        }

        buf.writeln('</div>'); // card-info
        buf.writeln('</div>'); // card
      }

      buf.writeln('</div>'); // card-grid
      buf.writeln('</section>');
    }

    // Locale summary table
    buf.writeln('<section class="locale-table">');
    buf.writeln('<h2>Locale Summary</h2>');
    buf.writeln('<table>');
    buf.writeln(
      '<thead><tr><th>Locale</th><th>Passed</th><th>Failed</th><th>Overflows</th><th>ARB Issues</th></tr></thead>',
    );
    buf.writeln('<tbody>');
    for (final entry in summary.byLocale.entries) {
      final results = entry.value;
      final p = results.where((r) => !r.hasIssues).length;
      final f = results.length - p;
      final o = results.fold(0, (sum, r) => sum + r.overflows.length);
      final a = results.fold(0, (sum, r) => sum + r.arbIssues.length);
      final rowClass = f > 0 ? ' class="row-fail"' : '';
      buf.writeln(
        '<tr$rowClass><td>${entry.key.toUpperCase()}</td><td>$p</td><td>$f</td><td>$o</td><td>$a</td></tr>',
      );
    }
    buf.writeln('</tbody></table>');
    buf.writeln('</section>');

    // Footer
    buf.writeln('<footer>');
    buf.writeln(
      '<p>Generated by <a href="https://pub.dev/packages/locale_sweep">LocaleSweep</a></p>',
    );
    buf.writeln('</footer>');

    // Filter JS
    buf.writeln('<script>');
    buf.writeln(_htmlScript);
    buf.writeln('</script>');

    buf.writeln('</body>');
    buf.writeln('</html>');

    return buf.toString();
  }

  static String _htmlEscape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static void _htmlSummaryCard(
    StringBuffer buf,
    String value,
    String label,
    String type,
  ) {
    buf.writeln('<div class="summary-card summary-$type">');
    buf.writeln('<div class="summary-value">$value</div>');
    buf.writeln('<div class="summary-label">$label</div>');
    buf.writeln('</div>');
  }

  static const _htmlStyles = '''
:root {
  --bg: #0f1117;
  --surface: #1a1d27;
  --surface2: #242734;
  --border: #2e3142;
  --text: #e1e4ed;
  --text2: #8b8fa3;
  --pass: #34d399;
  --pass-bg: rgba(52, 211, 153, 0.1);
  --fail: #f87171;
  --fail-bg: rgba(248, 113, 113, 0.1);
  --warn: #fbbf24;
  --warn-bg: rgba(251, 191, 36, 0.1);
  --accent: #818cf8;
  --accent-bg: rgba(129, 140, 248, 0.1);
}

* { margin: 0; padding: 0; box-sizing: border-box; }

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  line-height: 1.5;
  padding: 2rem;
  max-width: 1400px;
  margin: 0 auto;
}

header { margin-bottom: 2rem; }
h1 { font-size: 1.75rem; font-weight: 700; }
h2 { font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem; color: var(--text); }
.timestamp { color: var(--text2); font-size: 0.85rem; margin-top: 0.25rem; }

.summary {
  display: flex;
  gap: 1rem;
  margin-bottom: 2rem;
  flex-wrap: wrap;
}

.summary-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 1rem 1.5rem;
  min-width: 120px;
  text-align: center;
}

.summary-value { font-size: 2rem; font-weight: 700; }
.summary-label { font-size: 0.8rem; color: var(--text2); text-transform: uppercase; letter-spacing: 0.05em; }
.summary-pass .summary-value { color: var(--pass); }
.summary-fail .summary-value { color: var(--fail); }
.summary-warn .summary-value { color: var(--warn); }
.summary-total .summary-value { color: var(--accent); }

.filters {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-bottom: 2rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 1rem 1.25rem;
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.filter-group label {
  font-size: 0.8rem;
  color: var(--text2);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  min-width: 60px;
}

.filter-btn {
  background: var(--surface2);
  border: 1px solid var(--border);
  color: var(--text2);
  padding: 0.3rem 0.75rem;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.8rem;
  transition: all 0.15s;
}

.filter-btn:hover { border-color: var(--accent); color: var(--text); }
.filter-btn.active { background: var(--accent-bg); border-color: var(--accent); color: var(--accent); }

.flow-section { margin-bottom: 2.5rem; }

.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 1rem;
}

.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
  transition: transform 0.15s, box-shadow 0.15s;
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}

.card.fail { border-color: rgba(248, 113, 113, 0.3); }
.card.pass { border-color: rgba(52, 211, 153, 0.15); }

.card-img {
  aspect-ratio: 9 / 16;
  overflow: hidden;
  background: var(--surface2);
  display: flex;
  align-items: center;
  justify-content: center;
}

.card-img img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.card-img-empty {
  color: var(--text2);
  font-size: 0.85rem;
}

.card-info { padding: 0.75rem; }

.badge {
  display: inline-block;
  padding: 0.15rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 600;
  letter-spacing: 0.05em;
  margin-right: 0.3rem;
  margin-bottom: 0.3rem;
}

.badge-pass { background: var(--pass-bg); color: var(--pass); }
.badge-fail { background: var(--fail-bg); color: var(--fail); }
.badge-dark { background: var(--surface2); color: var(--text2); }
.badge-rtl { background: var(--accent-bg); color: var(--accent); }

.card-label {
  font-size: 0.8rem;
  color: var(--text2);
  margin-top: 0.25rem;
}

.card-issues { margin-top: 0.5rem; }

.issue {
  font-size: 0.75rem;
  padding: 0.2rem 0.4rem;
  border-radius: 4px;
  margin-bottom: 0.25rem;
}

.issue.overflow { background: var(--fail-bg); color: var(--fail); }
.issue.arb { background: var(--warn-bg); color: var(--warn); }
.issue.error { background: var(--fail-bg); color: var(--fail); }

.locale-table {
  margin-bottom: 2rem;
}

table {
  width: 100%;
  border-collapse: collapse;
  background: var(--surface);
  border-radius: 10px;
  overflow: hidden;
}

th, td {
  padding: 0.6rem 1rem;
  text-align: left;
  border-bottom: 1px solid var(--border);
}

th {
  background: var(--surface2);
  font-size: 0.8rem;
  color: var(--text2);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-weight: 600;
}

td { font-size: 0.9rem; }
.row-fail { background: var(--fail-bg); }

footer {
  text-align: center;
  padding: 2rem 0;
  color: var(--text2);
  font-size: 0.8rem;
}

footer a { color: var(--accent); text-decoration: none; }

.hidden { display: none !important; }

@media (max-width: 768px) {
  body { padding: 1rem; }
  .summary { gap: 0.5rem; }
  .summary-card { min-width: 80px; padding: 0.75rem; }
  .summary-value { font-size: 1.5rem; }
  .card-grid { grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); }
}
''';

  static const _htmlScript = r'''
document.addEventListener('DOMContentLoaded', function() {
  const state = { status: 'all', locale: 'all', flow: 'all' };

  document.querySelectorAll('.filter-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      const filter = btn.dataset.filter;
      const value = btn.dataset.value;
      state[filter] = value;

      btn.closest('.filter-group').querySelectorAll('.filter-btn').forEach(function(b) {
        b.classList.remove('active');
      });
      btn.classList.add('active');

      applyFilters();
    });
  });

  function applyFilters() {
    document.querySelectorAll('.flow-section').forEach(function(section) {
      const flowMatch = state.flow === 'all' || section.dataset.flow === state.flow;
      section.classList.toggle('hidden', !flowMatch);
    });

    document.querySelectorAll('.card').forEach(function(card) {
      const statusMatch = state.status === 'all' || card.dataset.status === state.status;
      const localeMatch = state.locale === 'all' || card.dataset.locale === state.locale;
      card.classList.toggle('hidden', !statusMatch || !localeMatch);
    });

    document.querySelectorAll('.flow-section:not(.hidden)').forEach(function(section) {
      const visibleCards = section.querySelectorAll('.card:not(.hidden)');
      section.classList.toggle('hidden', visibleCards.length === 0);
    });
  }
});
''';

  /// Generates a machine-readable JSON report.
  static String generateJson(SweepRunSummary summary) {
    final data = {
      'timestamp': summary.timestamp.toIso8601String(),
      'total': summary.total,
      'passed': summary.passed,
      'failed': summary.failed,
      'overflows': summary.overflowCount,
      'arbIssues': summary.arbIssueCount,
      'results': summary.results.map((r) => r.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
