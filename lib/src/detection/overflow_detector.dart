import 'package:flutter/foundation.dart';

class OverflowDetector {
  final List<OverflowError> errors = [];
  FlutterExceptionHandler? _previousHandler;

  void install() {
    _previousHandler = FlutterError.onError;
    FlutterError.onError = _handleError;
  }

  void uninstall() {
    FlutterError.onError = _previousHandler;
    _previousHandler = null;
  }

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

class OverflowError {
  final String message;
  final String? widget;
  final double? pixels;

  const OverflowError({required this.message, this.widget, this.pixels});

  @override
  String toString() {
    final parts = <String>['Overflow'];
    if (pixels != null) parts.add('(${pixels!.toStringAsFixed(1)}px)');
    if (widget != null) parts.add('in $widget');
    return parts.join(' ');
  }
}
