/// A text element that was silently truncated (ellipsis, clip, or fade).
class TruncationIssue {
  /// The full text content that was truncated.
  final String text;

  /// Which locale this occurred in.
  final String locale;

  /// The overflow mode that caused truncation.
  final String overflowMode;

  /// The available width from layout constraints.
  final double availableWidth;

  /// The width the text wanted (intrinsic width).
  final double desiredWidth;

  /// The maxLines setting, if any.
  final int? maxLines;

  const TruncationIssue({
    required this.text,
    required this.locale,
    required this.overflowMode,
    required this.availableWidth,
    required this.desiredWidth,
    this.maxLines,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'locale': locale,
    'overflowMode': overflowMode,
    'availableWidth': availableWidth,
    'desiredWidth': desiredWidth,
    if (maxLines != null) 'maxLines': maxLines,
  };

  factory TruncationIssue.fromJson(Map<String, dynamic> json) =>
      TruncationIssue(
        text: json['text'] as String,
        locale: json['locale'] as String,
        overflowMode: json['overflowMode'] as String,
        availableWidth: (json['availableWidth'] as num).toDouble(),
        desiredWidth: (json['desiredWidth'] as num).toDouble(),
        maxLines: json['maxLines'] as int?,
      );

  @override
  String toString() {
    final preview = text.length > 40 ? '${text.substring(0, 40)}...' : text;
    final excess = (desiredWidth - availableWidth).toStringAsFixed(0);
    final lines = maxLines != null ? ', maxLines: $maxLines' : '';
    return 'Truncated ($overflowMode$lines, +${excess}px): "$preview"';
  }
}
