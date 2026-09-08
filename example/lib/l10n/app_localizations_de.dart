// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'TaskFlow';

  @override
  String get welcomeHeading => 'Willkommen bei TaskFlow';

  @override
  String get welcomeSubtitle => 'Organisieren Sie Ihre Arbeit, auf Ihre Weise';

  @override
  String get settingsTitle => 'Benachrichtigungseinstellungen';

  @override
  String get settingsEmailLabel => 'E-Mail-Benachrichtigungen';

  @override
  String settingsEmailDesc(Object time) {
    return 'Tägliche Zusammenfassung um $time erhalten';
  }

  @override
  String get settingsPushLabel => 'Push-Benachrichtigungen';

  @override
  String settingsPushDesc(Object category) {
    return 'Sofortige Benachrichtigungen für Aktualisierungen erhalten';
  }

  @override
  String taskCount(Object count) {
    return '$count Aufgaben verbleibend';
  }

  @override
  String profileGreeting(Object userName) {
    return 'Hallo, $userName!';
  }

  @override
  String profileLastLogin(Object date) {
    return 'Letzter Login: $date';
  }

  @override
  String get logoutButton => 'Abmelden';

  @override
  String get deleteAccount => 'Konto unwiderruflich löschen';

  @override
  String get upgradePrompt => 'Upgraden Sie auf Pro für unbegrenzte Projekte';
}
