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
