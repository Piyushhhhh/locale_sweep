// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TaskFlow';

  @override
  String get welcomeHeading => 'Welcome to TaskFlow';

  @override
  String get welcomeSubtitle => 'Organize your work, your way';

  @override
  String get settingsTitle => 'Notification Settings';

  @override
  String get settingsEmailLabel => 'Email notifications';

  @override
  String settingsEmailDesc(Object time) {
    return 'Receive daily digest at $time';
  }

  @override
  String get settingsPushLabel => 'Push notifications';

  @override
  String settingsPushDesc(Object category) {
    return 'Get instant alerts for $category updates';
  }

  @override
  String taskCount(Object count) {
    return '$count tasks remaining';
  }

  @override
  String profileGreeting(Object userName) {
    return 'Hello, $userName!';
  }

  @override
  String profileLastLogin(Object date) {
    return 'Last login: $date';
  }

  @override
  String get logoutButton => 'Log out';

  @override
  String get deleteAccount => 'Delete account permanently';

  @override
  String get upgradePrompt => 'Upgrade to Pro for unlimited projects';
}
