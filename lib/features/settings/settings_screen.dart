import 'package:flutter/material.dart';

enum FamilySection { members, invitations, management }

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.calendarName});

  final String calendarName;

  void _openFamily(BuildContext context, FamilySection section) {
    Navigator.of(context).pushNamed('/family', arguments: section);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Einstellungen')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Kalender',
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Aktueller Kalender'),
                subtitle: Text(calendarName),
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Mitglieder'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFamily(context, FamilySection.members),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Einladungen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFamily(context, FamilySection.invitations),
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Kalenderverwaltung'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFamily(context, FamilySection.management),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Mein Profil',
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Profil und Konto'),
                subtitle: const Text('Anzeigename, E-Mail und Kontoverwaltung'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed('/account'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Section(
            title: 'Darstellung',
            children: [
              ListTile(
                enabled: false,
                leading: Icon(Icons.palette_outlined),
                title: Text('Design'),
                subtitle: Text('Demnächst'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Section(
            title: 'Benachrichtigungen',
            children: [
              ListTile(
                leading: Icon(Icons.notifications_outlined),
                title: Text('Erinnerungen'),
                subtitle: Text(
                  'Erinnerungen werden direkt beim Termin eingestellt.',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    ],
  );
}
