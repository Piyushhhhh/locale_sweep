import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.email, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.settingsEmailLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(value: true, onChanged: (_) {}),
              ],
            ),
            const Divider(),
            // BUG: No Expanded — overflows in German at 2x text scale.
            Row(
              children: [
                const Icon(Icons.notifications, size: 24),
                const SizedBox(width: 12),
                Text(
                  l10n.settingsPushLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Switch(value: false, onChanged: (_) {}),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            // BUG: Fixed-width container — fits English at 1x but
            // overflows at 2x text scale or in German.
            SizedBox(
              width: 360,
              child: Text(
                l10n.upgradePrompt,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
