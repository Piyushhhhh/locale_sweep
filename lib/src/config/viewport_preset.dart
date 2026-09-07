import 'dart:ui';

/// A named viewport size used to simulate layout dimensions in tests.
///
/// These are not device emulations — they set the Flutter test view's
/// physical size and pixel ratio. Native fonts, keyboard behavior,
/// safe-area insets, and platform plugins are not reproduced.
class ViewportPreset {
  /// Human-readable name for this preset, typically `WIDTHxHEIGHT`.
  final String name;

  /// Logical width in pixels.
  final double width;

  /// Logical height in pixels.
  final double height;

  /// Creates a custom viewport preset.
  const ViewportPreset({
    required this.name,
    required this.width,
    required this.height,
  });

  /// Returns the viewport as a [Size].
  Size get size => Size(width, height);

  /// 375x667 — compact phone (e.g. iPhone SE).
  static const phoneSmall = ViewportPreset(
    name: '375x667',
    width: 375,
    height: 667,
  );

  /// 393x852 — standard phone.
  static const phone = ViewportPreset(name: '393x852', width: 393, height: 852);

  /// 412x915 — tall phone.
  static const phoneWide = ViewportPreset(
    name: '412x915',
    width: 412,
    height: 915,
  );

  /// 768x1024 — tablet.
  static const tablet = ViewportPreset(
    name: '768x1024',
    width: 768,
    height: 1024,
  );

  /// 667x375 — compact phone in landscape.
  static const phoneSmallLandscape = ViewportPreset(
    name: '667x375',
    width: 667,
    height: 375,
  );

  /// 852x393 — standard phone in landscape.
  static const phoneLandscape = ViewportPreset(
    name: '852x393',
    width: 852,
    height: 393,
  );

  /// 915x412 — tall phone in landscape.
  static const phoneWideLandscape = ViewportPreset(
    name: '915x412',
    width: 915,
    height: 412,
  );

  /// 1024x768 — tablet in landscape.
  static const tabletLandscape = ViewportPreset(
    name: '1024x768',
    width: 1024,
    height: 768,
  );

  @override
  String toString() => name;
}
