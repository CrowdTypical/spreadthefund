import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfIsOqdqE9XNdvdKTQgg3ZDz_bmHRT144',
    appId: '1:385760154944:android:e397370075daf91e5e96a5',
    messagingSenderId: '385760154944',
    projectId: 'billsplitter-b201a',
    storageBucket: 'billsplitter-b201a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCfIsOqdqE9XNdvdKTQgg3ZDz_bmHRT144',
    appId: '1:385760154944:ios:e397370075daf91e5e96a5',
    messagingSenderId: '385760154944',
    projectId: 'billsplitter-b201a',
    storageBucket: 'billsplitter-b201a.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCfIsOqdqE9XNdvdKTQgg3ZDz_bmHRT144',
    appId: '1:385760154944:macos:e397370075daf91e5e96a5',
    messagingSenderId: '385760154944',
    projectId: 'billsplitter-b201a',
    storageBucket: 'billsplitter-b201a.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCfIsOqdqE9XNdvdKTQgg3ZDz_bmHRT144',
    appId: '1:385760154944:windows:e397370075daf91e5e96a5',
    messagingSenderId: '385760154944',
    projectId: 'billsplitter-b201a',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCfIsOqdqE9XNdvdKTQgg3ZDz_bmHRT144',
    appId: '1:385760154944:web:e397370075daf91e5e96a5',
    messagingSenderId: '385760154944',
    projectId: 'billsplitter-b201a',
    authDomain: 'billsplitter-b201a.firebaseapp.com',
    storageBucket: 'billsplitter-b201a.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform {
    return android;
  }
}