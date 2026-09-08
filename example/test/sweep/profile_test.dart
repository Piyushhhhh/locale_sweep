import 'package:locale_sweep/locale_sweep.dart';
import 'package:taskflow_example/l10n/app_localizations.dart';
import 'package:taskflow_example/screens/profile_screen.dart';

void main() {
  // Tests the screen in isolation using localizationsDelegates —
  // no MaterialApp wrapper needed.
  sweepTest(
    'profile',
    builder: () => const ProfileScreen(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locales: ['en', 'de', 'ar', 'ja', 'ko', 'he', 'th', 'hi'],
    textScales: [1.0, 2.0],
    viewports: [ViewportPreset.phone, ViewportPreset.tablet],
    darkMode: true,
    arbDir: 'lib/l10n',
  );
}
