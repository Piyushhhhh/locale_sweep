// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'TaskFlow';

  @override
  String get welcomeHeading => 'مرحباً بك في TaskFlow';

  @override
  String get welcomeSubtitle => 'نظّم عملك، بطريقتك';

  @override
  String get settingsTitle => 'إعدادات الإشعارات';

  @override
  String get settingsEmailLabel => 'إشعارات البريد الإلكتروني';

  @override
  String settingsEmailDesc(Object time) {
    return 'استلام الملخص اليومي في $time';
  }

  @override
  String get settingsPushLabel => 'الإشعارات الفورية';

  @override
  String settingsPushDesc(Object category) {
    return 'احصل على تنبيهات فورية لتحديثات';
  }

  @override
  String taskCount(Object count) {
    return '$count مهام متبقية';
  }

  @override
  String profileGreeting(Object userName) {
    return 'مرحباً، $userName!';
  }

  @override
  String profileLastLogin(Object date) {
    return 'Last login: $date';
  }

  @override
  String get logoutButton => 'تسجيل الخروج';

  @override
  String get deleteAccount => 'Delete account permanently';

  @override
  String get upgradePrompt => 'Upgrade to Pro for unlimited projects';
}
