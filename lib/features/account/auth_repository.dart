class AccountIdentity {
  const AccountIdentity({
    required this.email,
    required this.emailVerified,
    this.displayName,
  });

  final String email;
  final bool emailVerified;
  final String? displayName;

  String get displayLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final at = email.indexOf('@');
    if (at > 0) return email.substring(0, at);
    return email.trim().isEmpty ? 'Mitglied' : email;
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

abstract interface class AuthRepository {
  AccountIdentity? get currentUser;
  Stream<AccountIdentity?> get userChanges;

  Future<void> signIn(String email, String password);
  Future<void> register(String displayName, String email, String password);
  Future<void> updateDisplayName(String displayName);
  Future<void> sendPasswordReset(String email);
  Future<void> sendVerificationEmail();
  Future<void> reloadUser();
  Future<void> signOut();
}
