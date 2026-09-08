// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'TaskFlow';

  @override
  String get welcomeHeading => 'ยินดีต้อนรับสู่ TaskFlow';

  @override
  String get welcomeSubtitle => 'จัดระเบียบงานของคุณในแบบของคุณ';

  @override
  String get settingsTitle => 'ตั้งค่าการแจ้งเตือน';

  @override
  String get settingsEmailLabel => 'การแจ้งเตือนทางอีเมล';

  @override
  String settingsEmailDesc(Object time) {
    return 'รับสรุปประจำวันเวลา $time';
  }

  @override
  String get settingsPushLabel => 'การแจ้งเตือนแบบพุช';

  @override
  String settingsPushDesc(Object category) {
    return 'รับการแจ้งเตือนทันทีสำหรับการอัปเดต';
  }

  @override
  String taskCount(Object count) {
    return 'งานที่เหลือ $count รายการ';
  }

  @override
  String profileGreeting(Object userName) {
    return 'สวัสดี $userName!';
  }

  @override
  String profileLastLogin(Object date) {
    return 'เข้าสู่ระบบล่าสุด: $date';
  }

  @override
  String get logoutButton => 'ออกจากระบบ';

  @override
  String get deleteAccount => 'Delete account permanently';

  @override
  String get upgradePrompt => 'Upgrade to Pro for unlimited projects';
}
