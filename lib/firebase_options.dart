import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCfulboLpYks5Ibz8IIaw5s8Gj2fjN46vE',
    appId: '1:977295278599:web:30641095d62171dc19a0a2',
    messagingSenderId: '977295278599',
    projectId: 'istachir12',
    authDomain: 'istachir12.firebaseapp.com',
    storageBucket: 'istachir12.firebasestorage.app',
    measurementId: 'G-9QBR6VQ4YS',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCXBGRuuclgykuGTMW5aYVlrgYWxCz1ym8',
    appId: '1:977295278599:android:6b8775c583af345b19a0a2',
    messagingSenderId: '977295278599',
    projectId: 'istachir12',
    storageBucket: 'istachir12.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBnEOuksYS-lDfRe0dHiEY6kMvvsKPxwx8',
    appId: '1:977295278599:ios:c4433b49aee8324b19a0a2',
    messagingSenderId: '977295278599',
    projectId: 'istachir12',
    storageBucket: 'istachir12.firebasestorage.app',
    iosClientId: '977295278599-v04egqc16gnhtod03kmt2qtm699qvnrk.apps.googleusercontent.com',
    iosBundleId: 'com.example.istachirnaApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR-MACOS-API-KEY',
    appId: 'YOUR-MACOS-APP-ID',
    messagingSenderId: 'YOUR-SENDER-ID',
    projectId: 'YOUR-PROJECT-ID',
    storageBucket: 'YOUR-STORAGE-BUCKET',
    iosClientId: 'YOUR-MACOS-CLIENT-ID',
    iosBundleId: 'YOUR-MACOS-BUNDLE-ID',
  );
} 