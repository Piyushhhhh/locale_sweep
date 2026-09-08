import 'package:flutter/material.dart';

class AppStrings {
  final String welcomeTitle;
  final String settingsTitle;

  const AppStrings({required this.welcomeTitle, required this.settingsTitle});

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  static const _translations = {
    'en': AppStrings(welcomeTitle: 'Welcome', settingsTitle: 'Settings'),
    'de': AppStrings(
      welcomeTitle: 'Willkommen',
      settingsTitle: 'Einstellungen',
    ),
    'ar': AppStrings(welcomeTitle: 'مرحباً', settingsTitle: 'الإعدادات'),
    'ja': AppStrings(welcomeTitle: 'ようこそ', settingsTitle: '設定'),
    'fr': AppStrings(welcomeTitle: 'Bienvenue', settingsTitle: 'Paramètres'),
  };

  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      _translations.containsKey(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async =>
      _translations[locale.languageCode] ?? _translations['en']!;

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}

Widget localizedWidget() {
  return Builder(
    builder: (context) {
      final strings = AppStrings.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.welcomeTitle, key: const Key('welcome')),
            Text(strings.settingsTitle, key: const Key('settings')),
          ],
        ),
      );
    },
  );
}
