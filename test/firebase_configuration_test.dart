import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/firebase_configuration.dart';
import 'package:moonkeep/features/account/firebase_auth_repository.dart';

void main() {
  test('absent configuration keeps the app local', () {
    expect(const FirebaseConfiguration().options, isNull);
  });

  test(
    'partial configuration fails instead of choosing a fallback project',
    () {
      expect(
        () => const FirebaseConfiguration(projectId: 'test').options,
        throwsFormatException,
      );
      expect(
        () => const FirebaseConfiguration(authDomain: 'example.test').options,
        throwsFormatException,
      );
    },
  );

  test('complete configuration maps explicitly to Firebase options', () {
    final options = const FirebaseConfiguration(
      apiKey: 'test-key',
      appId: 'test-app',
      messagingSenderId: '123',
      projectId: 'test-project',
      authDomain: 'example.test',
    ).options!;
    expect(options.projectId, 'test-project');
    expect(options.appId, 'test-app');
    expect(options.apiKey, 'test-key');
    expect(options.messagingSenderId, '123');
    expect(options.authDomain, 'example.test');
    expect(options.iosBundleId, isNull);
  });

  test(
    'login failures do not distinguish unknown accounts from bad passwords',
    () {
      expect(
        authErrorMessage('user-not-found'),
        authErrorMessage('wrong-password'),
      );
      expect(
        authErrorMessage('invalid-credential'),
        authErrorMessage('wrong-password'),
      );
      expect(
        authErrorMessage('unknown-internal-details'),
        'Die Anfrage ist fehlgeschlagen. Bitte versuche es erneut.',
      );
    },
  );
}
