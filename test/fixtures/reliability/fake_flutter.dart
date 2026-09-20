import 'dart:convert';
import 'dart:io';

// A process boundary fixture: models Flutter output and the result protocol,
// allowing CLI execution, filtering, and monorepo tests without SDK startups.
void main(List<String> args) {
  final env = Platform.environment;
  final root = Directory.current.path;
  File('$root/invocation.json').writeAsStringSync(
    jsonEncode({
      'args': args,
      'config': env['LOCALE_SWEEP_CONFIG'],
      'results': env['LOCALE_SWEEP_RESULTS_DIR'],
      'managed': env['LOCALE_SWEEP_MANAGED_RUN'],
    }),
  );
  final mode = env['SWEEP_FAKE_MODE'] ?? 'clean';
  final result = <String, dynamic>{
    'flow': 'current',
    'locale': 'de',
    'textScale': 1.0,
    'viewportName': 'phone',
    'viewportWidth': 393,
    'viewportHeight': 852,
    'brightness': 'light',
    'passed': true,
    'overflows': [],
    'arbIssues': [],
    'durationMs': 0,
  };
  if (mode == 'arb') {
    // Legacy passed:true deliberately verifies normalization during loading.
    result['arbIssues'] = [
      {
        'type': 'missingKey',
        'locale': 'de',
        'key': 'title',
        'detail': 'Missing title',
      },
    ];
  }
  if (mode == 'golden') {
    result['passed'] = false;
    result['error'] = 'Golden mismatch';
    result['failureKind'] = 'golden';
  }
  if (mode == 'overflow') {
    result['passed'] = false;
    result['overflows'] = [
      {'message': 'overflowed by 10 pixels'},
    ];
  }
  if (mode != 'empty' && mode != 'compile') {
    final dir = Directory(env['LOCALE_SWEEP_RESULTS_DIR']!)
      ..createSync(recursive: true);
    File('${dir.path}/current.json').writeAsStringSync(jsonEncode([result]));
    if (mode == 'corrupt') {
      File('${dir.path}/broken.json').writeAsStringSync('{');
    }
  }
  if (mode != 'incomplete') {
    print(
      jsonEncode({
        'type': 'done',
        'success': mode != 'compile' && mode != 'partial',
      }),
    );
  }
  if (mode == 'compile' || mode == 'partial') {
    stderr.writeln('Compilation failed');
    exitCode = 1;
  }
}
