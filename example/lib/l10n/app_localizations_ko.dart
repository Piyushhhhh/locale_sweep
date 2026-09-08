// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'TaskFlow';

  @override
  String get welcomeHeading => 'TaskFlow에 오신 것을 환영합니다';

  @override
  String get welcomeSubtitle => '당신만의 방식으로 업무를 정리하세요';

  @override
  String get settingsTitle => '알림 설정';

  @override
  String get settingsEmailLabel => '이메일 알림';

  @override
  String settingsEmailDesc(Object time) {
    return '$time에 일일 요약 수신';
  }

  @override
  String get settingsPushLabel => '푸시 알림';

  @override
  String settingsPushDesc(Object category) {
    return '$category 업데이트에 대한 즉시 알림 받기';
  }

  @override
  String taskCount(Object count) {
    return '남은 작업 $count개';
  }

  @override
  String profileGreeting(Object userName) {
    return '안녕하세요, $userName님!';
  }

  @override
  String profileLastLogin(Object date) {
    return '마지막 로그인: $date';
  }

  @override
  String get logoutButton => '로그아웃';

  @override
  String get deleteAccount => '계정 영구 삭제';

  @override
  String get upgradePrompt => '무제한 프로젝트를 위해 Pro로 업그레이드하세요';
}
