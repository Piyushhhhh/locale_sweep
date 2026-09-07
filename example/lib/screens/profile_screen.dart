import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        // BUG: Hardcoded left padding — breaks RTL layout for Arabic/Hebrew.
        // Should use EdgeInsetsDirectional.only(start: 24, end: 16).
        padding: const EdgeInsets.only(left: 24, right: 16, top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 48)),
            const SizedBox(height: 16),
            Text(
              'Hello, Sarah!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Last login: September 3, 2026',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            // BUG: Row with no Flexible — fits in English at 1x but
            // overflows in German "Konto unwiderruflich löschen" at 2x scale.
            Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Delete account',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.red),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Icon(Icons.logout, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Log out',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
