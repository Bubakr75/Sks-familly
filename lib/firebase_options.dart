// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web non configuré.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Plateforme non configurée.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCexnX9sfdMXTxQiRAlsQT98Qizs40bKfE',
    appId: '1:1033903328737:android:0265992569b69916b2d6a0',
    messagingSenderId: '1033903328737',
    projectId: 'sks-familly-3f205',
    storageBucket: 'sks-familly-3f205.firebasestorage.app',
  );
}
