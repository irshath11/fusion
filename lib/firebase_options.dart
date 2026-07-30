import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        return android;
      case TargetPlatform.linux:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBx6RvC40VTfYiiTN3CfKBWqU9q18pKQiY',
    appId: '1:318619919615:web:9d05504d5977a3598b98ca',
    messagingSenderId: '318619919615',
    projectId: 'fusion-attendance',
    authDomain: 'fusion-attendance.firebaseapp.com',
    databaseURL: 'https://fusion-attendance-default-rtdb.firebaseio.com',
    storageBucket: 'fusion-attendance.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBx6RvC40VTfYiiTN3CfKBWqU9q18pKQiY',
    appId: '1:318619919615:android:9d05504d5977a3598b98ca',
    messagingSenderId: '318619919615',
    projectId: 'fusion-attendance',
    databaseURL: 'https://fusion-attendance-default-rtdb.firebaseio.com',
    storageBucket: 'fusion-attendance.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBx6RvC40VTfYiiTN3CfKBWqU9q18pKQiY',
    appId: '1:318619919615:ios:9d05504d5977a3598b98ca',
    messagingSenderId: '318619919615',
    projectId: 'fusion-attendance',
    databaseURL: 'https://fusion-attendance-default-rtdb.firebaseio.com',
    storageBucket: 'fusion-attendance.firebasestorage.app',
    iosBundleId: 'com.example.fusion_attendance',
  );
}
