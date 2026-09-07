import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Client configuration is supplied per platform at build time. No fallback
/// project is chosen, so an unconfigured build never sends account data.
class FirebaseConfiguration {
  static const iosBundleIdentifier = 'dev.moonkeep.moonkeep';

  const FirebaseConfiguration({
    this.apiKey = '',
    this.appId = '',
    this.messagingSenderId = '',
    this.projectId = '',
    this.authDomain = '',
    this.iosBundleId = '',
  });

  const FirebaseConfiguration.fromEnvironment()
    : apiKey = const String.fromEnvironment('FIREBASE_API_KEY'),
      appId = const String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId = const String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
      ),
      projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      authDomain = const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      iosBundleId = const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String authDomain;
  final String iosBundleId;

  FirebaseOptions? optionsFor(TargetPlatform platform) {
    final requiredValues = [apiKey, appId, messagingSenderId, projectId];
    if ([
      ...requiredValues,
      authDomain,
      iosBundleId,
    ].every((value) => value.isEmpty)) {
      return null;
    }
    if (requiredValues.any((value) => value.trim().isEmpty)) {
      throw const FormatException('Unvollständige Firebase-Konfiguration.');
    }
    if (platform == TargetPlatform.iOS) {
      if (authDomain.trim().isEmpty || iosBundleId.trim().isEmpty) {
        throw const FormatException('Unvollständige iOS-Konfiguration.');
      }
      if (iosBundleId != iosBundleIdentifier) {
        throw const FormatException('Unerwartete iOS-Bundle-ID.');
      }
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      iosBundleId: platform == TargetPlatform.iOS ? iosBundleId : null,
    );
  }
}
