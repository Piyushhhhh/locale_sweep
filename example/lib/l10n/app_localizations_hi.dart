// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'TaskFlow';

  @override
  String get welcomeHeading => 'TaskFlow में आपका स्वागत है';

  @override
  String get welcomeSubtitle => 'अपने काम को अपने तरीके से व्यवस्थित करें';

  @override
  String get settingsTitle => 'सूचना सेटिंग्स';

  @override
  String get settingsEmailLabel => 'ईमेल सूचनाएं';

  @override
  String settingsEmailDesc(Object time) {
    return '$time पर दैनिक सारांश प्राप्त करें';
  }

  @override
  String get settingsPushLabel => 'पुश सूचनाएं';

  @override
  String settingsPushDesc(Object category) {
    return 'अपडेट के लिए तुरंत अलर्ट प्राप्त करें';
  }

  @override
  String taskCount(Object count) {
    return '$count कार्य शेष';
  }

  @override
  String profileGreeting(Object userName) {
    return 'नमस्ते, $userName!';
  }

  @override
  String profileLastLogin(Object date) {
    return 'अंतिम लॉगिन: $date';
  }

  @override
  String get logoutButton => 'लॉग आउट';

  @override
  String get deleteAccount => 'खाता स्थायी रूप से हटाएं';

  @override
  String get upgradePrompt => 'Upgrade to Pro for unlimited projects';
}
