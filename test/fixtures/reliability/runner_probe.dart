import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  final mode = Platform.environment['SWEEP_PROBE_MODE'] ?? 'clean';
  sweepTest(
    'probe',
    builder: () => const Center(child: Text('Hello')),
    captureScreenshots: mode == 'golden',
    locales: mode == 'override' ? ['ja'] : null,
    textScales: mode == 'override' ? [1.5] : null,
    darkMode: mode == 'override' ? false : null,
    setUp: mode == 'setup'
        ? () async => throw StateError('setup failed')
        : null,
    body: mode == 'callback'
        ? (_) async => throw StateError('callback failed')
        : null,
  );
  if (mode == 'teardown') {
    tearDownAll(() => throw StateError('teardown failed'));
  }
}
