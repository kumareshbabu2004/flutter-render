import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for Back My Bracket.
/// Generated from google-services.json + Firebase Console web config.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // ── Web configuration ──
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCVIyREqZNFsa025kL0BrTAMsZtWssxK2k',
    appId: '1:535647737009:web:9d24f75fc6b64bf0823e90',
    messagingSenderId: '535647737009',
    projectId: 'back-my-bracket-41250',
    authDomain: 'back-my-bracket-41250.firebaseapp.com',
    storageBucket: 'back-my-bracket-41250.firebasestorage.app',
    measurementId: 'G-E5K3B2GZQT',
  );

  // ── Android configuration ──
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDp9awTWSTuIIGKh0xxlZR7M4ivFwlED_0',
    appId: '1:535647737009:android:c2ec37288452d3e9823e90',
    messagingSenderId: '535647737009',
    projectId: 'back-my-bracket-41250',
    storageBucket: 'back-my-bracket-41250.firebasestorage.app',
  );

  // BUG #9 FIX: iOS placeholder clearly marked. When iOS app is registered
  // in Firebase Console, replace these values with the actual iOS config.
  // Currently throws if someone tries to use iOS in production without setup.
  static FirebaseOptions get ios {
    assert(false,
      'iOS Firebase configuration not set up. Register your iOS app in '
      'Firebase Console and replace the placeholder values in firebase_options.dart');
    return const FirebaseOptions(
      apiKey: 'IOS_API_KEY_NOT_CONFIGURED',
      appId: 'IOS_APP_ID_NOT_CONFIGURED',
      messagingSenderId: '535647737009',
      projectId: 'back-my-bracket-41250',
      storageBucket: 'back-my-bracket-41250.firebasestorage.app',
      iosBundleId: 'com.backmybracket.mobile',
    );
  }
}
