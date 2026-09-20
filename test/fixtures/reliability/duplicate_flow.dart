import 'package:flutter/widgets.dart';
import 'package:locale_sweep/locale_sweep.dart';

void main() {
  for (var index = 0; index < 2; index++) {
    sweepTest(
      'same_flow',
      builder: () => Text('Variant $index'),
      locales: const ['en'],
      textScales: const [1.0],
      captureScreenshots: false,
    );
  }
}
