import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/app.dart';
import 'package:moonkeep/features/account/auth_repository.dart';
import 'package:moonkeep/features/account/account_screen.dart';
import 'package:moonkeep/features/family/family_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final _changes = StreamController<AccountIdentity?>.broadcast();
  AccountIdentity? user;
  String? lastEmail;
  String? lastDisplayName;
  int signInCalls = 0;
  int registerCalls = 0;
  int resetCalls = 0;
  int verificationCalls = 0;
  int reauthenticateCalls = 0;
  int deleteCalls = 0;
  String? lastPassword;
  AuthFailure? failure;
  AuthFailure? reauthenticateFailure;
  AuthFailure? deleteFailure;
  final operationLog = <String>[];
  Completer<void>? pendingSignIn;
  bool emitChanges = true;

  void publishUser() => _changes.add(user);

  @override
  AccountIdentity? get currentUser => user;
  @override
  Stream<AccountIdentity?> get userChanges => _changes.stream;

  void _signIn(String email) {
    lastEmail = email;
    user = AccountIdentity(email: email, emailVerified: false);
    if (emitChanges) publishUser();
  }

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    if (pendingSignIn != null) await pendingSignIn!.future;
    if (failure != null) throw failure!;
    _signIn(email);
  }

  @override
  Future<void> register(
    String displayName,
    String email,
    String password,
  ) async {
    registerCalls++;
    lastDisplayName = displayName;
    _signIn(email);
    user = AccountIdentity(
      email: email,
      emailVerified: false,
      displayName: displayName,
    );
    if (emitChanges) publishUser();
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    lastDisplayName = displayName;
    user = AccountIdentity(
      email: user!.email,
      emailVerified: user!.emailVerified,
      displayName: displayName,
    );
    if (emitChanges) publishUser();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetCalls++;
    lastEmail = email;
  }

  @override
  Future<void> sendVerificationEmail() async => verificationCalls++;

  @override
  Future<void> reloadUser() async {
    user = AccountIdentity(
      email: user!.email,
      emailVerified: true,
      displayName: user!.displayName,
    );
    if (emitChanges) publishUser();
  }

  @override
  Future<void> reauthenticate(String password) async {
    reauthenticateCalls++;
    lastPassword = password;
    operationLog.add('reauthenticate');
    if (reauthenticateFailure != null) throw reauthenticateFailure!;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    operationLog.add('delete-auth');
    if (deleteFailure != null) throw deleteFailure!;
    if (failure != null) throw failure!;
    user = null;
    if (emitChanges) publishUser();
  }

  @override
  Future<void> signOut() async {
    if (failure != null) throw failure!;
    user = null;
    if (emitChanges) publishUser();
  }

  Future<void> dispose() => _changes.close();
}

void main() {
  Future<void> pumpSignedAccount(
    WidgetTester tester,
    FakeAuthRepository auth, {
    required Future<AccountDeletionPlan> Function() plan,
    required Future<void> Function() cleanup,
  }) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/family': (_) => const Scaffold(body: Text('Kalenderauswahl')),
        },
        home: AccountScreen(
          auth: auth,
          accountDeletionPlan: plan,
          cleanupForAccountDeletion: cleanup,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Konto löschen'),
    );
  }

  Future<void> confirmAccountDeletion(
    WidgetTester tester, {
    String password = 'password-test',
  }) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Konto löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Konto löschen'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-account-password')),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Endgültig löschen'));
    await tester.pumpAndSettle();
  }

  Future<void> openAccount(
    WidgetTester tester, {
    FakeAuthRepository? auth,
    String? setupError,
  }) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (auth != null) addTearDown(auth.dispose);
    await tester.pumpWidget(
      MoonkeepApp(auth: auth, accountSetupError: setupError),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mein Konto öffnen'));
    await tester.pumpAndSettle();
  }

  Future<void> fillLogin(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-Mail-Adresse'),
      ' test@example.test ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passwort'),
      'password-test',
    );
  }

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  testWidgets('unconfigured account never asks for credentials', (
    tester,
  ) async {
    await openAccount(tester);
    expect(find.text('Konten sind noch nicht freigeschaltet'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Zurück'));
    await tester.pumpAndSettle();
    expect(find.text('Mein Konto öffnen'), findsOneWidget);
  });

  testWidgets('initialization failure remains recoverable', (tester) async {
    await openAccount(tester, setupError: 'Einrichtung prüfen');
    expect(find.text('Einrichtung prüfen'), findsOneWidget);
    await tester.tap(find.text('Zurück'));
    await tester.pumpAndSettle();
    expect(find.text('Mein Konto öffnen'), findsOneWidget);
  });

  testWidgets('validates credentials, signs in and signs out', (tester) async {
    final auth = FakeAuthRepository();
    await openAccount(tester, auth: auth);
    await tester.tap(button('Anmelden'));
    await tester.pumpAndSettle();
    expect(auth.signInCalls, 0);
    expect(
      find.text('Bitte gib eine gültige E-Mail-Adresse ein.'),
      findsOneWidget,
    );
    await fillLogin(tester);
    await tester.tap(button('Anmelden'));
    await tester.pumpAndSettle();
    expect(auth.lastEmail, 'test@example.test');
    expect(find.text('Angemeldet'), findsOneWidget);
    expect(find.text('Du bist jetzt angemeldet.'), findsOneWidget);
    expect(find.textContaining('gemeinsamen Kalender'), findsOneWidget);
    await tester.tap(find.text('Abmelden'));
    await tester.pumpAndSettle();
    expect(button('Anmelden'), findsOneWidget);
    expect(find.text('Du bist jetzt abgemeldet.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Passwort'))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets(
    'registration checks confirmation and supports email verification',
    (tester) async {
      final auth = FakeAuthRepository();
      await openAccount(tester, auth: auth);
      await tester.tap(find.text('Neues Konto erstellen'));
      await tester.pumpAndSettle();
      await fillLogin(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Passwort wiederholen'),
        'wrong',
      );
      await tester.tap(button('Registrieren'));
      await tester.pumpAndSettle();
      expect(auth.registerCalls, 0);
      expect(find.text('Bitte gib deinen Namen ein.'), findsOneWidget);
      expect(
        find.text('Die Passwörter stimmen nicht überein.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Passwort wiederholen'),
        'password-test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('registration-display-name')),
        '  Marcel  ',
      );
      await tester.tap(button('Registrieren'));
      await tester.pumpAndSettle();
      expect(auth.registerCalls, 1);
      expect(auth.lastDisplayName, 'Marcel');
      expect(
        find.text(
          'Konto erstellt. Bitte bestätige als Nächstes deine E-Mail-Adresse.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Bestätigungsmail senden'));
      await tester.pumpAndSettle();
      expect(auth.verificationCalls, 1);
      expect(find.textContaining('Bestätigungsmail gesendet.'), findsOneWidget);
      await tester.tap(find.text('Status aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text('E-Mail-Adresse bestätigt'), findsOneWidget);
      expect(find.text('Bestätigungsmail senden'), findsNothing);
    },
  );

  testWidgets('shows and changes a trimmed display name', (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = FakeAuthRepository()
      ..user = const AccountIdentity(
        email: 'marcel.jeske@example.test',
        emailVerified: true,
      );
    addTearDown(auth.dispose);
    String? synchronizedName;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          auth: auth,
          syncDisplayName: (name) async => synchronizedName = name,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('marcel.jeske'), findsOneWidget);
    await tester.tap(find.text('Ändern'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('display-name-dialog-field')),
      '   ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte gib deinen Namen ein.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('display-name-dialog-field')),
      '  Marcel  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(auth.lastDisplayName, 'Marcel');
    expect(synchronizedName, 'Marcel');
    expect(find.text('Anzeigename gespeichert.'), findsOneWidget);
    expect(find.text('Marcel'), findsOneWidget);
  });

  testWidgets('password reset validates email and gives a neutral response', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await openAccount(tester, auth: auth);
    await tester.tap(find.text('Passwort vergessen?'));
    await tester.pumpAndSettle();
    expect(auth.resetCalls, 0);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-Mail-Adresse'),
      'test@example.test',
    );
    await tester.tap(find.text('Passwort vergessen?'));
    await tester.pumpAndSettle();
    expect(auth.resetCalls, 1);
    expect(
      find.textContaining('Falls ein passendes Konto existiert'),
      findsOneWidget,
    );
  });

  testWidgets('failed login shows safe error and allows retry', (tester) async {
    final auth = FakeAuthRepository()
      ..failure = const AuthFailure('Keine Verbindung.');
    await openAccount(tester, auth: auth);
    await fillLogin(tester);
    await tester.tap(button('Anmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Keine Verbindung.'), findsOneWidget);
    auth.failure = null;
    await tester.tap(button('Anmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Angemeldet'), findsOneWidget);
  });

  testWidgets('pending login disables duplicate submissions', (tester) async {
    final auth = FakeAuthRepository()..pendingSignIn = Completer<void>();
    await openAccount(tester, auth: auth);
    await fillLogin(tester);
    await tester.tap(button('Anmelden'));
    await tester.pump();
    expect(tester.widget<FilledButton>(button('Anmelden')).onPressed, isNull);
    expect(auth.signInCalls, 1);
    auth.pendingSignIn!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Angemeldet'), findsOneWidget);
  });

  testWidgets(
    'completed login and logout update without a stream notification',
    (tester) async {
      final auth = FakeAuthRepository()..emitChanges = false;
      await openAccount(tester, auth: auth);
      await fillLogin(tester);
      await tester.tap(button('Anmelden'));
      await tester.pumpAndSettle();
      expect(find.text('Angemeldet'), findsOneWidget);
      expect(find.text('Du bist jetzt angemeldet.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      expect(button('Anmelden'), findsOneWidget);
      expect(find.text('Du bist jetzt abgemeldet.'), findsOneWidget);
      expect(find.text('Angemeldet'), findsNothing);
    },
  );

  testWidgets('account keeps following external session changes', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await openAccount(tester, auth: auth);
    auth.user = const AccountIdentity(
      email: 'test@example.test',
      emailVerified: true,
    );
    auth.publishUser();
    await tester.pumpAndSettle();
    expect(find.text('E-Mail-Adresse bestätigt'), findsOneWidget);
    auth.user = null;
    auth.publishUser();
    await tester.pumpAndSettle();
    expect(button('Anmelden'), findsOneWidget);
  });

  testWidgets(
    'failed logout keeps the account visible without a success notice',
    (tester) async {
      final auth = FakeAuthRepository()
        ..user = const AccountIdentity(
          email: 'test@example.test',
          emailVerified: true,
        )
        ..failure = const AuthFailure('Abmeldung fehlgeschlagen.');
      await openAccount(tester, auth: auth);
      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      expect(find.text('Angemeldet'), findsOneWidget);
      expect(find.text('Abmeldung fehlgeschlagen.'), findsOneWidget);
      expect(find.text('Du bist jetzt abgemeldet.'), findsNothing);
      auth.failure = null;
      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      expect(button('Anmelden'), findsOneWidget);
      expect(find.text('Du bist jetzt abgemeldet.'), findsOneWidget);
    },
  );

  testWidgets(
    'member cleanup runs after reauthentication and before auth delete',
    (tester) async {
      final auth = FakeAuthRepository()
        ..user = const AccountIdentity(
          email: 'member@example.test',
          emailVerified: true,
        );
      await pumpSignedAccount(
        tester,
        auth,
        plan: () async => AccountDeletionPlan.member,
        cleanup: () async => auth.operationLog.add('cleanup-member'),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Konto löschen'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('verlässt den gemeinsamen Kalender'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Konto löschen'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('delete-account-password')),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('delete-account-password')),
        'password-test',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Endgültig löschen'));
      await tester.pumpAndSettle();

      expect(auth.lastPassword, 'password-test');
      expect(auth.operationLog, [
        'reauthenticate',
        'cleanup-member',
        'delete-auth',
      ]);
      expect(find.widgetWithText(FilledButton, 'Anmelden'), findsOneWidget);
    },
  );

  testWidgets('owner with other members is blocked before reauthentication', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..user = const AccountIdentity(
        email: 'owner@example.test',
        emailVerified: true,
      );
    var cleaned = false;
    await pumpSignedAccount(
      tester,
      auth,
      plan: () async => AccountDeletionPlan.transferOwnershipRequired,
      cleanup: () async => cleaned = true,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Konto löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Besitz zuerst übertragen'), findsOneWidget);
    expect(find.text('Besitzer übertragen'), findsOneWidget);
    expect(auth.reauthenticateCalls, 0);
    expect(cleaned, isFalse);
  });

  testWidgets('owner can retry as member after ownership transfer', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..user = const AccountIdentity(
        email: 'owner@example.test',
        emailVerified: true,
      );
    var plan = AccountDeletionPlan.transferOwnershipRequired;
    await pumpSignedAccount(
      tester,
      auth,
      plan: () async => plan,
      cleanup: () async => auth.operationLog.add('cleanup-member'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Konto löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    plan = AccountDeletionPlan.member;
    await confirmAccountDeletion(tester);
    expect(auth.deleteCalls, 1);
  });

  testWidgets('sole owner dissolves calendar before deleting auth account', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..user = const AccountIdentity(
        email: 'owner@example.test',
        emailVerified: true,
      );
    await pumpSignedAccount(
      tester,
      auth,
      plan: () async => AccountDeletionPlan.soleOwner,
      cleanup: () async => auth.operationLog.add('dissolve-owner'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Konto löschen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kalender wird aufgelöst'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Konto löschen'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-account-password')),
      'password-test',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Endgültig löschen'));
    await tester.pumpAndSettle();
    expect(auth.operationLog, [
      'reauthenticate',
      'dissolve-owner',
      'delete-auth',
    ]);
  });

  testWidgets('account without membership deletes auth account directly', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..user = const AccountIdentity(
        email: 'solo@example.test',
        emailVerified: true,
      );
    var cleanupCalls = 0;
    await pumpSignedAccount(
      tester,
      auth,
      plan: () async => AccountDeletionPlan.noMembership,
      cleanup: () async => cleanupCalls++,
    );
    await confirmAccountDeletion(tester);
    expect(cleanupCalls, 1);
    expect(auth.deleteCalls, 1);
  });

  testWidgets('wrong password keeps account and permits retry', (tester) async {
    final auth = FakeAuthRepository()
      ..user = const AccountIdentity(
        email: 'member@example.test',
        emailVerified: true,
      )
      ..reauthenticateFailure = const AuthFailure(
        'Das Passwort ist nicht korrekt.',
      );
    var cleanupCalls = 0;
    await pumpSignedAccount(
      tester,
      auth,
      plan: () async => AccountDeletionPlan.member,
      cleanup: () async => cleanupCalls++,
    );
    await confirmAccountDeletion(tester, password: 'wrong');
    expect(find.text('Das Passwort ist nicht korrekt.'), findsOneWidget);
    expect(cleanupCalls, 0);
    expect(auth.deleteCalls, 0);
    expect(find.text('Angemeldet'), findsOneWidget);

    auth.reauthenticateFailure = null;
    await confirmAccountDeletion(tester);
    expect(auth.deleteCalls, 1);
  });

  testWidgets('auth deletion failure after cleanup is clear and retryable', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..user = const AccountIdentity(
        email: 'member@example.test',
        emailVerified: true,
      )
      ..deleteFailure = const AuthFailure('Bitte melde dich erneut an.');
    var plan = AccountDeletionPlan.member;
    var cleanupCalls = 0;
    await pumpSignedAccount(
      tester,
      auth,
      plan: () async => plan,
      cleanup: () async {
        cleanupCalls++;
        plan = AccountDeletionPlan.noMembership;
      },
    );
    await confirmAccountDeletion(tester);
    expect(cleanupCalls, 1);
    expect(
      find.textContaining('Kalenderzuordnung wurde bereits entfernt'),
      findsOneWidget,
    );
    expect(find.text('Angemeldet'), findsOneWidget);

    auth.deleteFailure = null;
    await confirmAccountDeletion(tester);
    expect(auth.deleteCalls, 2);
    expect(cleanupCalls, 2);
  });
}
