class AccountIdentity {
  const AccountIdentity({required this.email, required this.emailVerified});

  final String email;
  final bool emailVerified;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

abstract interface class AuthRepository {
  AccountIdentity? get currentUser;
  Stream<AccountIdentity?> get userChanges;

  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> sendVerificationEmail();
  Future<void> reloadUser();
  Future<void> signOut();
}
