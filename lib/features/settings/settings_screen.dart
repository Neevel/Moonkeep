import 'package:flutter/material.dart';

import '../../theme/moonkeep_theme.dart';
import '../../theme/moonkeep_theme_controller.dart';

enum FamilySection { members, invitations, management }

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.calendarName});

  final String calendarName;

  void _openFamily(BuildContext context, FamilySection section) {
    Navigator.of(context).pushNamed('/family', arguments: section);
  }

  @override
  Widget build(BuildContext context) {
    final themes = MoonkeepThemeScope.of(context);
    return Scaffold(
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
                  subtitle: const Text(
                    'Anzeigename, E-Mail und Kontoverwaltung',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/account'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Darstellung',
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Design'),
                  subtitle: Text(themes.themeId.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DesignScreen()),
                  ),
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
}

class DesignScreen extends StatelessWidget {
  const DesignScreen({super.key});

  Future<void> _select(
    BuildContext context,
    MoonkeepThemeController controller,
    MoonkeepThemeId id,
  ) async {
    try {
      await controller.select(id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Das Design konnte nicht gespeichert werden. Bitte versuche es erneut.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = MoonkeepThemeScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Design')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Wähle den Look, der zu eurem gemeinsamen Kalender passt.',
            ),
            const SizedBox(height: 12),
            for (final id in MoonkeepThemeId.values)
              _ThemeChoiceCard(
                id: id,
                selected: controller.themeId == id,
                onTap: () => _select(context, controller, id),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final MoonkeepThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewTheme = MoonkeepThemes.themeFor(id);
    final previewColors = previewTheme.extension<MoonkeepThemeColors>()!;
    final currentColors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        key: ValueKey('theme-${id.name}'),
        clipBehavior: Clip.antiAlias,
        shape: selected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: currentColors.primary, width: 2),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _ThemePreview(theme: previewTheme, colors: previewColors),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        id.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(id.description),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected
                      ? currentColors.primary
                      : currentColors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme, required this.colors});

  final ThemeData theme;
  final MoonkeepThemeColors colors;

  @override
  Widget build(BuildContext context) => Container(
    width: 82,
    height: 62,
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: theme.scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: theme.colorScheme.outlineVariant),
    ),
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.calendarCell,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 6,
            width: 24,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Spacer(),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: colors.memberBackgrounds.first,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: colors.memberBackgrounds[1],
              borderRadius: BorderRadius.circular(3),
            ),
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
        color:
            Theme.of(context).extension<MoonkeepThemeColors>()?.settingsCard ??
            Theme.of(context).colorScheme.surfaceContainerLow,
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
