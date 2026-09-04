import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

/// Result of comparing two golden screenshots pixel-by-pixel.
class DiffResult {
  /// Percentage of pixels that differ (0.0–100.0).
  final double diffPercent;

  /// Number of pixels that differ beyond the per-pixel threshold.
  final int changedPixels;

  /// Total number of pixels compared.
  final int totalPixels;

  /// Path to the generated side-by-side diff image, if any.
  final String? diffImagePath;

  const DiffResult({
    required this.diffPercent,
    required this.changedPixels,
    required this.totalPixels,
    this.diffImagePath,
  });

  DiffResult withDiffImagePath(String path) => DiffResult(
    diffPercent: diffPercent,
    changedPixels: changedPixels,
    totalPixels: totalPixels,
    diffImagePath: path,
  );

  Map<String, dynamic> toJson() => {
    'diffPercent': double.parse(diffPercent.toStringAsFixed(4)),
    'changedPixels': changedPixels,
    'totalPixels': totalPixels,
    if (diffImagePath != null) 'diffImagePath': diffImagePath,
  };

  factory DiffResult.fromJson(Map<String, dynamic> json) => DiffResult(
    diffPercent: (json['diffPercent'] as num).toDouble(),
    changedPixels: json['changedPixels'] as int? ?? 0,
    totalPixels: json['totalPixels'] as int? ?? 0,
    diffImagePath: json['diffImagePath'] as String?,
  );
}

/// Computes pixel-level diffs between golden screenshots and generates
/// side-by-side comparison images.
class GoldenDiffer {
  /// Per-channel threshold below which a pixel difference is ignored.
  /// Absorbs minor anti-aliasing and rendering jitter.
  static const _pixelThreshold = 2;

  /// Compares two PNG images pixel-by-pixel.
  ///
  /// Returns a [DiffResult] with the percentage of pixels that differ.
  /// If the images have different dimensions, returns 100% diff.
  static Future<DiffResult> computeDiff({
    required Uint8List actual,
    required Uint8List golden,
  }) async {
    final actualImage = await _decodeImage(actual);
    final goldenImage = await _decodeImage(golden);

    if (actualImage.width != goldenImage.width ||
        actualImage.height != goldenImage.height) {
      final total = actualImage.width * actualImage.height;
      return DiffResult(
        diffPercent: 100.0,
        changedPixels: total,
        totalPixels: total,
      );
    }

    final actualData = (await actualImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final goldenData = (await goldenImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;

    var changed = 0;
    final total = actualImage.width * actualImage.height;

    for (var i = 0; i < actualData.lengthInBytes; i += 4) {
      final dr = (actualData.getUint8(i) - goldenData.getUint8(i)).abs();
      final dg = (actualData.getUint8(i + 1) - goldenData.getUint8(i + 1))
          .abs();
      final db = (actualData.getUint8(i + 2) - goldenData.getUint8(i + 2))
          .abs();
      final da = (actualData.getUint8(i + 3) - goldenData.getUint8(i + 3))
          .abs();

      if (dr > _pixelThreshold ||
          dg > _pixelThreshold ||
          db > _pixelThreshold ||
          da > _pixelThreshold) {
        changed++;
      }
    }

    return DiffResult(
      diffPercent: total > 0 ? (changed / total) * 100 : 0.0,
      changedPixels: changed,
      totalPixels: total,
    );
  }

  /// Generates a 3-panel side-by-side image: Golden | Actual | Diff.
  ///
  /// In the diff panel, identical pixels are dimmed to 25% brightness
  /// and differing pixels are highlighted in magenta.
  /// Returns the PNG bytes of the composite image.
  static Future<Uint8List> generateDiffImage({
    required Uint8List actual,
    required Uint8List golden,
  }) async {
    final actualImage = await _decodeImage(actual);
    final goldenImage = await _decodeImage(golden);

    final width = goldenImage.width;
    final height = goldenImage.height;
    const gap = 2;
    final totalWidth = width * 3 + gap * 2;

    final actualData = (await actualImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final goldenData = (await goldenImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;

    // Build diff panel pixel data
    final diffBytes = Uint8List(width * height * 4);
    for (
      var i = 0;
      i < goldenData.lengthInBytes && i < actualData.lengthInBytes;
      i += 4
    ) {
      final dr = (actualData.getUint8(i) - goldenData.getUint8(i)).abs();
      final dg = (actualData.getUint8(i + 1) - goldenData.getUint8(i + 1))
          .abs();
      final db = (actualData.getUint8(i + 2) - goldenData.getUint8(i + 2))
          .abs();

      if (dr > _pixelThreshold ||
          dg > _pixelThreshold ||
          db > _pixelThreshold) {
        diffBytes[i] = 255;
        diffBytes[i + 1] = 50;
        diffBytes[i + 2] = 120;
        diffBytes[i + 3] = 255;
      } else {
        diffBytes[i] = goldenData.getUint8(i) ~/ 4;
        diffBytes[i + 1] = goldenData.getUint8(i + 1) ~/ 4;
        diffBytes[i + 2] = goldenData.getUint8(i + 2) ~/ 4;
        diffBytes[i + 3] = 255;
      }
    }

    final diffPanel = await _imageFromRgba(diffBytes, width, height);

    // Compose the 3-panel image
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, totalWidth.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF080808),
    );

    canvas.drawImage(goldenImage, ui.Offset.zero, ui.Paint());
    canvas.drawImage(
      actualImage,
      ui.Offset((width + gap).toDouble(), 0),
      ui.Paint(),
    );
    canvas.drawImage(
      diffPanel,
      ui.Offset((width * 2 + gap * 2).toDouble(), 0),
      ui.Paint(),
    );

    final picture = recorder.endRecording();
    final compositeImage = await picture.toImage(totalWidth, height);
    final pngData = await compositeImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return pngData!.buffer.asUint8List();
  }

  /// Saves a 3-panel diff image to disk. Returns the output path.
  static Future<String> saveDiffImage({
    required Uint8List actual,
    required Uint8List golden,
    required String outputPath,
  }) async {
    final pngBytes = await generateDiffImage(actual: actual, golden: golden);
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(pngBytes);
    return outputPath;
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<ui.Image> _imageFromRgba(
    Uint8List rgba,
    int width,
    int height,
  ) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

/// A golden file comparator that computes pixel diffs and applies tolerance.
///
/// Wraps the default comparator, computing a [DiffResult] for every
/// comparison. If the diff is within [tolerance], the test passes even
/// when pixels differ.
class SweepGoldenComparator implements GoldenFileComparator {
  final GoldenFileComparator _delegate;

  /// Maximum allowed diff percentage (0.0–100.0). Tests within this
  /// threshold pass even though pixels differ.
  final double tolerance;

  /// Directory where diff images are written.
  final String diffOutputDir;

  /// The result of the most recent [compare] call.
  DiffResult? lastDiffResult;

  SweepGoldenComparator({
    required GoldenFileComparator delegate,
    this.tolerance = 0.0,
    this.diffOutputDir = '.locale_sweep/diffs',
  }) : _delegate = delegate;

  File _resolveGoldenFile(Uri golden) {
    if (_delegate is LocalFileComparator) {
      final basedir = _delegate.basedir;
      return File(
        path.join(path.fromUri(basedir), path.fromUri(golden)),
      );
    }
    final resolved = _delegate.getTestUri(golden, null);
    if (resolved.scheme == 'file') return File.fromUri(resolved);
    return File(resolved.toFilePath());
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenFile = _resolveGoldenFile(golden);

    if (!goldenFile.existsSync()) {
      lastDiffResult = null;
      return _delegate.compare(imageBytes, golden);
    }

    final goldenBytes = Uint8List.fromList(goldenFile.readAsBytesSync());

    lastDiffResult = await GoldenDiffer.computeDiff(
      actual: imageBytes,
      golden: goldenBytes,
    );

    if (lastDiffResult!.diffPercent > 0) {
      final diffName = golden.pathSegments.last.replaceAll('.png', '_diff.png');
      final diffPath = await GoldenDiffer.saveDiffImage(
        actual: imageBytes,
        golden: goldenBytes,
        outputPath: '$diffOutputDir/$diffName',
      );
      lastDiffResult = lastDiffResult!.withDiffImagePath(diffPath);
    }

    if (lastDiffResult!.diffPercent <= tolerance) {
      return true;
    }

    return _delegate.compare(imageBytes, golden);
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      _delegate.update(golden, imageBytes);

  @override
  Uri getTestUri(Uri key, int? version) => _delegate.getTestUri(key, version);
}
