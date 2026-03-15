import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyABGqJErNqh4xr2jIyf4PHQzxX4jYHgQ0I',
    appId: '1:1033903328737:web:5e7ac00165d5edf8b2d6a0',
    messagingSenderId: '1033903328737',
    projectId: 'sks-familly-3f205',
    storageBucket: 'sks-familly-3f205.firebasestorage.app',
    authDomain: 'sks-familly-3f205.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCexnX9sfdMXTxQiRAlsQT98Qizs40bKfE',
    appId: '1:1033903328737:android:0265992569b69916b2d6a0',
    messagingSenderId: '1033903328737',
    projectId: 'sks-familly-3f205',
    storageBucket: 'sks-familly-3f205.firebasestorage.app',
  );
}
