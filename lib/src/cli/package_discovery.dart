import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

List<String> discoverPackages(String root, {String testDir = 'test/sweep'}) {
  final rootDir = Directory(root);
  if (!rootDir.existsSync()) return [];

  final melosFile = File(p.join(rootDir.path, 'melos.yaml'));
  if (melosFile.existsSync()) {
    return _discoverFromMelos(melosFile, testDir: testDir);
  }

  final packages = <String>[];
  _scanForPackages(rootDir, packages, testDir: testDir);
  return packages;
}

List<String> _discoverFromMelos(File melosFile, {required String testDir}) {
  try {
    final content = loadYaml(melosFile.readAsStringSync());
    if (content is! YamlMap) return [];

    final packageGlobs = content['packages'];
    if (packageGlobs is! YamlList) return [];

    final root = p.dirname(melosFile.path);
    final packages = <String>[];

    for (final glob in packageGlobs) {
      final pattern = glob.toString().replaceAll('**', '*');
      final dir = Directory(p.join(root, p.dirname(pattern)));
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync()) {
        if (entity is! Directory) continue;
        if (!File(p.join(entity.path, 'pubspec.yaml')).existsSync()) continue;
        if (!Directory(p.join(entity.path, testDir)).existsSync()) continue;
        packages.add(p.relative(entity.path, from: root));
      }
    }

    return packages..sort();
  } catch (_) {
    return [];
  }
}

void _scanForPackages(
  Directory dir,
  List<String> packages, {
  required String testDir,
  int depth = 0,
}) {
  if (depth > 4) return;

  final basename = p.basename(dir.path);
  if (basename.startsWith('.') ||
      basename == 'build' ||
      basename == 'node_modules') {
    return;
  }

  if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() &&
      Directory(p.join(dir.path, testDir)).existsSync()) {
    packages.add(dir.path);
  }

  if (depth == 0 || !File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
    for (final entity in dir.listSync()) {
      if (entity is Directory) {
        _scanForPackages(entity, packages, testDir: testDir, depth: depth + 1);
      }
    }
  }
}
