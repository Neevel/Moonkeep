import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:moonkeep/firebase_configuration.dart';
import 'package:moonkeep/features/account/firebase_auth_repository.dart';

void main() {
  test('absent configuration keeps the app local', () {
    expect(
      const FirebaseConfiguration().optionsFor(TargetPlatform.android),
      isNull,
    );
    expect(
      const FirebaseConfiguration().optionsFor(TargetPlatform.iOS),
      isNull,
    );
  });

  test(
    'partial configuration fails instead of choosing a fallback project',
    () {
      expect(
        () =>
            const FirebaseConfiguration(projectId: 'test')
                .optionsFor(TargetPlatform.android),
        throwsFormatException,
      );
      expect(
        () =>
            const FirebaseConfiguration(authDomain: 'example.test')
                .optionsFor(TargetPlatform.android),
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
    ).optionsFor(TargetPlatform.android)!;
    expect(options.projectId, 'test-project');
    expect(options.appId, 'test-app');
    expect(options.apiKey, 'test-key');
    expect(options.messagingSenderId, '123');
    expect(options.authDomain, 'example.test');
    expect(options.iosBundleId, isNull);
  });

  test('complete iOS configuration includes the expected bundle id', () {
    final options = const FirebaseConfiguration(
      apiKey: 'test-key',
      appId: 'test-ios-app',
      messagingSenderId: '123',
      projectId: 'test-project',
      authDomain: 'example.test',
      iosBundleId: FirebaseConfiguration.iosBundleIdentifier,
    ).optionsFor(TargetPlatform.iOS)!;

    expect(options.projectId, 'test-project');
    expect(options.iosBundleId, 'dev.moonkeep.moonkeep');
  });

  test('iOS configuration requires auth domain and exact bundle id', () {
    const common = FirebaseConfiguration(
      apiKey: 'test-key',
      appId: 'test-ios-app',
      messagingSenderId: '123',
      projectId: 'test-project',
    );
    expect(() => common.optionsFor(TargetPlatform.iOS), throwsFormatException);
    expect(
      () => const FirebaseConfiguration(
        apiKey: 'test-key',
        appId: 'test-ios-app',
        messagingSenderId: '123',
        projectId: 'test-project',
        authDomain: 'example.test',
        iosBundleId: 'invalid.example',
      ).optionsFor(TargetPlatform.iOS),
      throwsFormatException,
    );
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
      expect(
        reauthenticationErrorMessage('wrong-password'),
        'Das Passwort ist nicht korrekt.',
      );
      expect(
        reauthenticationErrorMessage('network-request-failed'),
        'Keine Verbindung. Bitte prüfe deine Internetverbindung.',
      );
    },
  );
}
