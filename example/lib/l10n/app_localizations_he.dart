// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'TaskFlow';

  @override
  String get welcomeHeading => 'ברוכים הבאים ל-TaskFlow';

  @override
  String get welcomeSubtitle => 'ארגנו את העבודה שלכם, בדרך שלכם';

  @override
  String get settingsTitle => 'הגדרות התראות';

  @override
  String get settingsEmailLabel => 'התראות דוא\"ל';

  @override
  String settingsEmailDesc(Object time) {
    return 'קבלת סיכום יומי בשעה $time';
  }

  @override
  String get settingsPushLabel => 'התראות פוש';

  @override
  String settingsPushDesc(Object category) {
    return 'קבלת התראות מיידיות על עדכוני $category';
  }

  @override
  String taskCount(Object count) {
    return '$count משימות נותרו';
  }

  @override
  String profileGreeting(Object userName) {
    return 'שלום, $userName!';
  }

  @override
  String profileLastLogin(Object date) {
    return 'Last login: $date';
  }

  @override
  String get logoutButton => 'התנתקות';

  @override
  String get deleteAccount => 'Delete account permanently';

  @override
  String get upgradePrompt => 'שדרגו ל-Pro לפרויקטים ללא הגבלה';
}
