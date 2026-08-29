import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account/auth_repository.dart';
import '../calendar/calendar_screen.dart';
import '../calendar/reminder_service.dart';
import 'family_repository.dart';
import 'firestore_family_repository.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.reminders,
    this.autoOpenCalendar = false,
  });
  final AuthRepository? auth;
  final FamilyRepository? repository;
  final ReminderService? reminders;
  final bool autoOpenCalendar;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  static const _templates = ['Familie', 'Partnerschaft', 'Freunde', 'WG'];
  String _selectedTemplate = _templates.first;
  Family? _family;
  List<FamilyMember> _members = [];
  List<FamilyInvitation> _invitations = [];
  bool _started = false, _busy = false;
  bool _calendarOpened = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    if (widget.auth?.currentUser?.emailVerified == true) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    _started = true;
    await _run(() async {
      final family = await widget.repository!.loadFamily();
      final members = family == null
          ? <FamilyMember>[]
          : await widget.repository!.members(family);
      final invitations = family == null
          ? <FamilyInvitation>[]
          : await widget.repository!.invitations(family);
      if (mounted) {
        setState(() {
          _family = family;
          _members = members;
          _invitations = invitations;
        });
        if (family != null) _scheduleCalendarOpen();
      }
    });
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _message = success;
        _isError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = familyError(error);
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _create() => _run(
    () async {
      final name = _selectedTemplate == 'Sonstiges'
          ? _name.text
          : _selectedTemplate;
      final family = await widget.repository!.createFamily(name);
      final members = await widget.repository!.members(family);
      if (mounted) {
        setState(() {
          _family = family;
          _members = members;
          _name.clear();
        });
        _scheduleCalendarOpen();
      }
    },
    success:
        'Kalender erstellt. Du kannst jetzt einen Einladungscode erzeugen.',
  );

  void _join() => _run(() async {
    final family = await widget.repository!.joinFamily(_code.text);
    final members = await widget.repository!.members(family);
    if (mounted) {
      setState(() {
        _family = family;
        _members = members;
        _code.clear();
      });
      _scheduleCalendarOpen();
    }
  }, success: 'Du bist dem Kalender beigetreten.');

  void _scheduleCalendarOpen() {
    if (!widget.autoOpenCalendar || _calendarOpened || _family == null) return;
    _calendarOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _family != null) _openCalendar();
    });
  }

  void _openCalendar() {
    final calendar = widget.repository!.calendar(_family!);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalendarScreen(
          store: calendar,
          disposeStore: true,
          reminders: widget.reminders,
        ),
      ),
    );
  }

  void _invite() => _run(() async {
    final invitation = await widget.repository!.invite(_family!);
    if (mounted) setState(() => _invitations = [invitation]);
  }, success: 'Einmaligen Einladungscode erstellt.');

  Future<void> _revoke(FamilyInvitation invitation) async {
    await _run(() async {
      await widget.repository!.revokeInvitation(invitation.code);
      if (mounted) {
        setState(
          () =>
              _invitations.removeWhere((item) => item.code == invitation.code),
        );
      }
    }, success: 'Einladung widerrufen.');
  }

  Future<void> _leave() async {
    final family = _family!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kalender verlassen?'),
        content: Text(
          'Du verlässt „${family.name}“ und hast danach keinen Zugriff mehr '
          'auf den gemeinsamen Kalender.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kalender verlassen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.repository!.leaveFamily(family);
      if (mounted) {
        setState(() {
          _family = null;
          _members = [];
          _invitations = [];
          _calendarOpened = false;
        });
      }
    }, success: 'Du hast den Kalender verlassen.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _family == null ? 'Kalender einrichten' : 'Kalender verwalten',
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: StreamBuilder<AccountIdentity?>(
            stream: widget.auth?.userChanges,
            initialData: widget.auth?.currentUser,
            builder: (context, _) {
              final user = widget.auth?.currentUser;
              if (widget.repository == null || user == null) {
                return _accountRequired(
                  'Bitte melde dich an, um einen gemeinsamen Kalender zu verwenden.',
                );
              }
              if (!user.emailVerified) {
                return _accountRequired(
                  'Bitte bestätige zuerst deine E-Mail-Adresse und aktualisiere den Status unter Mein Konto.',
                );
              }
              if (!_started && !_busy) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_started) _load();
                });
              }
              return _body(user);
            },
          ),
        ),
      ),
    ),
  );

  Widget _accountRequired(String message) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.group_outlined, size: 48),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pushNamed('/account'),
          child: const Text('Mein Konto öffnen'),
        ),
      ],
    ),
  );

  Widget _body(AccountIdentity user) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Icon(Icons.group_outlined, size: 42),
      const SizedBox(height: 12),
      Text(
        _family?.name ?? 'Moonkeep',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(user.email, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      if (!_started || (_busy && _family == null))
        const LinearProgressIndicator(),
      if (_family == null && _started && !_busy) ..._setup(),
      if (_family != null) ..._familyContent(),
      if (_busy && _family != null) const LinearProgressIndicator(),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              style: TextStyle(
                color: _isError ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ),
        ),
      const SizedBox(height: 16),
      TextButton(
        onPressed: _busy ? null : _load,
        child: const Text('Aktualisieren'),
      ),
    ],
  );

  List<Widget> _setup() => [
    Text(
      'Wie möchtest du starten?',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: 8),
    const Text(
      'Erstelle einen neuen gemeinsamen Kalender oder tritt mit einem Einladungscode bei.',
    ),
    const SizedBox(height: 28),
    Text('Kalender erstellen', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final template in [..._templates, 'Sonstiges'])
          ChoiceChip(
            label: Text(template),
            selected: _selectedTemplate == template,
            onSelected: _busy
                ? null
                : (_) => setState(() => _selectedTemplate = template),
          ),
      ],
    ),
    if (_selectedTemplate == 'Sonstiges') ...[
      const SizedBox(height: 12),
      TextField(
        controller: _name,
        enabled: !_busy,
        maxLength: 80,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name des Kalenders'),
      ),
    ],
    const SizedBox(height: 16),
    FilledButton(
      onPressed: _busy ? null : _create,
      child: const Text('Kalender erstellen'),
    ),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(),
    ),
    Text(
      'Mit Einladung beitreten',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _code,
      enabled: !_busy,
      maxLength: 32,
      autocorrect: false,
      textCapitalization: TextCapitalization.none,
      decoration: const InputDecoration(
        labelText: 'Einladungscode',
        helperText: 'Füge den vollständigen Code des Besitzers ein.',
      ),
    ),
    FilledButton.tonal(
      onPressed: _busy ? null : _join,
      child: const Text('Mit Code beitreten'),
    ),
  ];

  List<Widget> _familyContent() => [
    FilledButton.icon(
      onPressed: _busy ? null : _openCalendar,
      icon: const Icon(Icons.calendar_month_outlined),
      label: const Text('Gemeinsamen Kalender öffnen'),
    ),
    const SizedBox(height: 28),
    Row(
      children: [
        Expanded(
          child: Text(
            'Mitglieder (${_members.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    if (_members.isEmpty)
      const Text('Noch keine Mitgliederdaten verfügbar.')
    else
      Card(
        child: Column(
          children: [
            for (var index = 0; index < _members.length; index++) ...[
              _memberTile(_members[index]),
              if (index < _members.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    if (widget.repository!.canInvite(_family!)) ...[
      const SizedBox(height: 28),
      Text('Einladung', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'Der Code ist einmal verwendbar und höchstens sechs Tage gültig. Teile ihn nur direkt mit der gewünschten Person.',
      ),
      if (_invitations.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: FilledButton.tonal(
            onPressed: _busy ? null : _invite,
            child: const Text('Einladungscode erzeugen'),
          ),
        ),
      for (final invitation in _invitations)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SelectableText(
                  invitation.code,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 17),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: invitation.code),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Einladungscode kopiert.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Kopieren'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _revoke(invitation),
                      child: const Text('Widerrufen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
    const SizedBox(height: 28),
    if (widget.repository!.canInvite(_family!))
      const Card(
        child: ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('Du besitzt diesen Kalender'),
          subtitle: Text(
            'Besitzerwechsel oder das Auflösen des Kalenders folgt in einem '
            'späteren Schritt.',
          ),
        ),
      )
    else
      OutlinedButton.icon(
        onPressed: _busy ? null : _leave,
        icon: const Icon(Icons.logout),
        label: const Text('Kalender verlassen'),
      ),
  ];

  Widget _memberTile(FamilyMember member) => ListTile(
    leading: CircleAvatar(
      child: Icon(
        member.isOwner ? Icons.shield_outlined : Icons.person_outline,
      ),
    ),
    title: Text(member.email),
    trailing: Chip(label: Text(member.isOwner ? 'Besitzer' : 'Mitglied')),
  );
}
