import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfIsOqdqE9XNdvdKTQgg3ZDz_bmHRT144',
    appId: '1:385760154944:android:3d7b609158f3e6e25e96a5',
    messagingSenderId: '385760154944',
    projectId: 'billsplitter-b201a',
    storageBucket: 'billsplitter-b201a.firebasestorage.app',
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