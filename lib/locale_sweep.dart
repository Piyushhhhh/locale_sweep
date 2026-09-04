/// Localization release QA for Flutter.
///
/// Runs app flows across every locale, viewport size, text scale, and
/// RTL mode, then reports broken screens with screenshot proof.
library;

export 'src/config/sweep_config.dart';
export 'src/config/viewport_preset.dart';
export 'src/runner/sweep_test.dart';
export 'src/runner/sweep_variant.dart';
export 'src/detection/overflow_detector.dart';
export 'src/detection/arb_analyzer.dart';
export 'src/detection/golden_diff.dart';
export 'src/report/sweep_result.dart';
export 'src/report/report_generator.dart';
