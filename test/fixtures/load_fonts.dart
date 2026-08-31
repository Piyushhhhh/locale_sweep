import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadTestFonts() async {
  final fontDir = '${Directory.current.path}/test/fixtures/fonts';

  await _loadFont('Roboto', [
    '$fontDir/Roboto-Regular.ttf',
    '$fontDir/Roboto-Bold.ttf',
    '$fontDir/Roboto-Medium.ttf',
  ]);

  await _loadFont('MaterialIcons', [
    '$fontDir/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _loadFont(String family, List<String> paths) async {
  final fontLoader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
  }
  await fontLoader.load();
}
