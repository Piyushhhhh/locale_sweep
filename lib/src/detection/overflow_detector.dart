import 'package:flutter/foundation.dart';

/// Intercepts [FlutterError.onError] to capture RenderFlex overflow errors.
///
/// Call [install] before pumping a widget and [uninstall] after the test.
/// Non-overflow errors are forwarded to the previous handler.
class OverflowDetector {
  /// Captured overflow errors since [install] was called.
  final List<OverflowError> errors = [];
  FlutterExceptionHandler? _previousHandler;

  /// Hooks into [FlutterError.onError] to capture overflows.
  void install() {
    _previousHandler = FlutterError.onError;
    FlutterError.onError = _handleError;
  }

  /// Restores the previous [FlutterError.onError] handler.
  void uninstall() {
    FlutterError.onError = _previousHandler;
    _previousHandler = null;
  }

  /// Clears captured errors.
  void reset() => errors.clear();

  void _handleError(FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    if (message.contains('overflowed') || message.contains('OVERFLOW')) {
      errors.add(
        OverflowError(
          message: message,
          widget: _extractWidgetName(details),
          pixels: _extractOverflowPixels(message),
        ),
      );
      return;
    }
    _previousHandler?.call(details);
  }

  static String? _extractWidgetName(FlutterErrorDetails details) {
    final context = details.context;
    if (context == null) return null;
    return context.toString();
  }

  static double? _extractOverflowPixels(String message) {
    final match = RegExp(r'(\d+\.?\d*)\s*pixels').firstMatch(message);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }
}

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
