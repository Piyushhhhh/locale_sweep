/// A captured RenderFlex overflow error with optional pixel count.
class OverflowError {
  /// The full Flutter error message.
  final String message;

  /// The widget context where the overflow occurred, if available.
  final String? widget;

  /// The number of pixels that overflowed, parsed from the error message.
  final double? pixels;

  const OverflowError({required this.message, this.widget, this.pixels});

  Map<String, dynamic> toJson() => {
    'message': message,
    'widget': widget,
    'pixels': pixels,
  };

  factory OverflowError.fromJson(Map<String, dynamic> json) => OverflowError(
    message: json['message'] as String,
    widget: json['widget'] as String?,
    pixels: (json['pixels'] as num?)?.toDouble(),
  );

  @override
  String toString() {
    final parts = <String>['Overflow'];
    if (pixels != null) parts.add('(${pixels!.toStringAsFixed(1)}px)');
    if (widget != null) parts.add('in $widget');
    return parts.join(' ');
  }
}
