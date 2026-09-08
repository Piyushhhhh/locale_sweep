// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'TaskFlow';

  @override
  String get welcomeHeading => 'TaskFlowへようこそ';

  @override
  String get welcomeSubtitle => 'Organize your work, your way';

  @override
  String get settingsTitle => '通知設定';

  @override
  String get settingsEmailLabel => 'メール通知';

  @override
  String settingsEmailDesc(Object time) {
    return 'Receive daily digest at $time';
  }

  @override
  String get settingsPushLabel => 'プッシュ通知';

  @override
  String settingsPushDesc(Object category) {
    return 'Get instant alerts for $category updates';
  }

  @override
  String taskCount(Object count) {
    return '$count タスク残り';
  }

  @override
  String profileGreeting(Object userName) {
    return 'こんにちは、$userNameさん！';
  }

  @override
  String profileLastLogin(Object date) {
    return 'Last login: $date';
  }

  @override
  String get logoutButton => 'ログアウト';

  @override
  String get deleteAccount => 'Delete account permanently';

  @override
  String get upgradePrompt => 'Upgrade to Pro for unlimited projects';
}
