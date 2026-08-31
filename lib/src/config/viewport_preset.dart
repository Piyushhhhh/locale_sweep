import 'dart:ui';

class ViewportPreset {
  final String name;
  final double width;
  final double height;

  const ViewportPreset({
    required this.name,
    required this.width,
    required this.height,
  });

  Size get size => Size(width, height);

  static const phoneSmall = ViewportPreset(
    name: '375x667',
    width: 375,
    height: 667,
  );

  static const phone = ViewportPreset(name: '393x852', width: 393, height: 852);

  static const phoneWide = ViewportPreset(
    name: '412x915',
    width: 412,
    height: 915,
  );

  static const tablet = ViewportPreset(
    name: '768x1024',
    width: 768,
    height: 1024,
  );

  @override
  String toString() => name;
}
