<!-- Copilot-specific instructions for developing the Bill Splitter app -->

This is "Spread the Funds" — a Flutter bill-splitting app with Firebase real-time database and Google Sign-In authentication.

## Getting Started

1. Run `flutter pub get` to install dependencies
2. Run `flutterfire configure` to set up Firebase credentials
3. Place `google-services.json` in `android/app/`
4. Run `flutter run` to start the app

## Key Technologies

- **Framework**: Flutter (Dart)
- **Backend**: Firebase (Firestore, Authentication)
- **Auth**: Google Sign-In
- **State Management**: Provider

## When Adding Features

- Keep UI responsive and mobile-first
- Use real-time Firestore streams for live updates
- Add proper error handling and user feedback
- Test on multiple screen sizes

## File Organization

- Models in `/lib/models/` - Data classes (Bill, Group, etc.)
- Services in `/lib/services/` - Firebase operations (AuthService, BillService)
- Screens in `/lib/screens/` - UI screens
- Main app logic in `/lib/main.dart`
