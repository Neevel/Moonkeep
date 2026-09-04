import 'package:firebase_auth/firebase_auth.dart';

import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth) {
    userChanges = _auth.userChanges().map(_identity);
  }

  final FirebaseAuth _auth;

  @override
  late final Stream<AccountIdentity?> userChanges;

  static AccountIdentity? _identity(User? user) => user == null
      ? null
      : AccountIdentity(
          email: user.email ?? '',
          emailVerified: user.emailVerified,
          displayName: user.displayName,
        );

  @override
  AccountIdentity? get currentUser => _identity(_auth.currentUser);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(authErrorMessage(error.code));
    }
  }

  @override
  Future<void> signIn(String email, String password) => _guard(() async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  });

  @override
  Future<void> register(String displayName, String email, String password) =>
      _guard(() async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await credential.user?.updateDisplayName(displayName);
      });

  @override
  Future<void> updateDisplayName(String displayName) =>
      _guard(() => _requireUser().updateDisplayName(displayName));

  @override
  Future<void> sendPasswordReset(String email) => _guard(() async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      // Keep the UI response neutral even for projects without enumeration protection.
      if (error.code != 'user-not-found') rethrow;
    }
  });

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Bitte melde dich erneut an.');
    return user;
  }

  @override
  Future<void> sendVerificationEmail() =>
      _guard(() => _requireUser().sendEmailVerification());

  @override
  Future<void> reloadUser() => _guard(() async {
    await _requireUser().reload();
    // Firestore rules evaluate email_verified from the ID token, not only from
    // the refreshed User object. Force a new token before opening family data.
    await _requireUser().getIdToken(true);
  });

  @override
  Future<void> signOut() => _guard(_auth.signOut);
}

String authErrorMessage(String code) => switch (code) {
  'invalid-email' => 'Bitte gib eine gültige E-Mail-Adresse ein.',
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'user-disabled' =>
    'Anmeldung fehlgeschlagen. Bitte prüfe deine Zugangsdaten.',
  'email-already-in-use' => 'Registrierung nicht möglich. Versuche die Anmeldung oder setze dein Passwort zurück.',
  'weak-password' => 'Das Passwort erfüllt die Anforderungen noch nicht.',
  'network-request-failed' =>
    'Keine Verbindung. Bitte prüfe deine Internetverbindung.',
  'too-many-requests' =>
    'Zu viele Versuche. Bitte warte etwas und versuche es erneut.',
  'operation-not-allowed' =>
    'Die Anmeldung per E-Mail ist im Projekt noch nicht freigeschaltet.',
  'requires-recent-login' ||
  'user-token-expired' ||
  'invalid-user-token' => 'Bitte melde dich erneut an.',
  _ => 'Die Anfrage ist fehlgeschlagen. Bitte versuche es erneut.',
};
