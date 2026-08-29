import 'package:flutter/material.dart';

import 'auth_repository.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.auth, this.setupError});

  final AuthRepository? auth;
  final String? setupError;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final Stream<AccountIdentity?>? _users = widget.auth?.userChanges;
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Bitte gib eine gültige E-Mail-Adresse ein.';

  Future<void> _run(
    Future<void> Function() action, {
    String? success,
    bool notify = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _message = notify ? null : success;
        _isError = false;
        _showPassword = false;
        if (widget.auth!.currentUser == null) _register = false;
      });
      if (notify && success != null) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error is AuthFailure
            ? error.message
            : 'Die Anfrage ist fehlgeschlagen. Bitte versuche es erneut.';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final auth = widget.auth!;
    final email = _email.text.trim();
    final password = _password.text;
    _run(
      () => _register
          ? auth.register(email, password)
          : auth.signIn(email, password),
      success: _register
          ? 'Konto erstellt. Bitte bestätige als Nächstes deine E-Mail-Adresse.'
          : 'Du bist jetzt angemeldet.',
      notify: !_register,
    );
  }

  void _resetPassword() {
    final error = _validateEmail(_email.text);
    if (error != null) {
      setState(() {
        _message = error;
        _isError = true;
      });
      return;
    }
    _run(
      () => widget.auth!.sendPasswordReset(_email.text.trim()),
      success: 'Falls ein passendes Konto existiert, erhältst du eine E-Mail zum Zurücksetzen.',
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Mein Konto')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.nightlight_round, size: 40),
                const SizedBox(height: 16),
                Text(
                  'Ein Zuhause für eure Pläne.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Melde dich an, um einen gemeinsamen Kalender zu erstellen '
                  'oder mit einem Einladungscode beizutreten.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (widget.auth == null)
                  _setupNotice(context)
                else
                  StreamBuilder<AccountIdentity?>(
                    stream: _users,
                    initialData: widget.auth!.currentUser,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          'Der Kontostatus konnte nicht geladen werden. '
                          'Bitte starte die App erneut.',
                        );
                      }
                      // Stream events trigger rebuilds for external changes;
                      // completed actions also rebuild this widget. Read the
                      // current session so a late event cannot leave stale UI.
                      final user = widget.auth!.currentUser;
                      return user == null ? _authForm() : _signedIn(user);
                    },
                  ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(
                    semanticsLabel: 'Anfrage läuft',
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isError
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _setupNotice(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Konten sind noch nicht freigeschaltet',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      Text(
        widget.setupError ??
            'Für Anmeldung und Registrierung muss Moonkeep zuerst '
                'mit einem Firebase-Projekt verbunden werden.',
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Zurück'),
      ),
    ],
  );

  Widget _authForm() => Form(
    key: _formKey,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _register ? 'Konto erstellen' : 'Anmelden',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'E-Mail-Adresse'),
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            enabled: !_busy,
            obscureText: !_showPassword,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: [
              _register ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: InputDecoration(
              labelText: 'Passwort',
              helperText: _register
                  ? 'Mindestens 8 Zeichen; weitere Projektregeln können gelten.'
                  : null,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? 'Passwort verbergen'
                    : 'Passwort anzeigen',
                onPressed: _busy
                    ? null
                    : () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Bitte gib dein Passwort ein.';
              }
              if (_register && value.length < 8) {
                return 'Bitte verwende mindestens 8 Zeichen.';
              }
              return null;
            },
          ),
          if (_register) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmation,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Passwort wiederholen',
              ),
              validator: (value) => value != _password.text
                  ? 'Die Passwörter stimmen nicht überein.'
                  : null,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_register ? 'Registrieren' : 'Anmelden'),
          ),
          if (!_register)
            TextButton(
              onPressed: _busy ? null : _resetPassword,
              child: const Text('Passwort vergessen?'),
            ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _register = !_register;
                    _password.clear();
                    _confirmation.clear();
                    _showPassword = false;
                    _message = null;
                    _formKey.currentState?.reset();
                  }),
            child: Text(
              _register
                  ? 'Ich habe bereits ein Konto'
                  : 'Neues Konto erstellen',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _signedIn(AccountIdentity user) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Angemeldet', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(user.email),
      const SizedBox(height: 16),
      Text(
        user.emailVerified
            ? 'E-Mail-Adresse bestätigt'
            : 'E-Mail-Adresse noch nicht bestätigt',
      ),
      if (!user.emailVerified) ...[
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(
                  widget.auth!.sendVerificationEmail,
                  success: 'Bestätigungsmail gesendet. Öffne den Link in deinem Postfach und aktualisiere danach den Status.',
                ),
          child: const Text('Bestätigungsmail senden'),
        ),
        TextButton(
          onPressed: _busy ? null : () => _run(widget.auth!.reloadUser),
          child: const Text('Status aktualisieren'),
        ),
      ],
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () => _run(
                widget.auth!.signOut,
                success: 'Du bist jetzt abgemeldet.',
                notify: true,
              ),
        child: const Text('Abmelden'),
      ),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        onPressed: _busy
            ? null
            : () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushNamed('/family');
                }
              },
        icon: const Icon(Icons.group_outlined),
        label: Text(
          user.emailVerified
              ? 'Weiter zur Kalenderauswahl'
              : 'Kalender einrichten',
        ),
      ),
    ],
  );
}
