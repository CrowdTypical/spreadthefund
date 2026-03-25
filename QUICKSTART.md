# Quick Start Guide - Bill Splitter App

## ⚡ 5-Minute Setup

### Step 1: Prepare Your Environment
```bash
# Make sure Flutter is installed
flutter --version

# Get dependencies
flutter pub get
```

### Step 2: Firebase Setup (2 minutes)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project called "BillSplitter"
3. Add an Android app with package name: `com.example.bill_splitter`
4. Download `google-services.json` and place in `android/app/`

### Step 3: Configure Firebase Credentials
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Auto-configure Firebase
flutterfire configure
```

### Step 4: Run the App!
```bash
flutter run
```

---

## 🔑 Firebase Essentials

**Enable Google Sign-In:**
- Firebase Console → Authentication → Sign-in method → Google → Enable

**Set Firestore Rules:**
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /groups/{groupId} {
      allow read: if request.auth.uid in resource.data.members;
      allow write: if request.auth.uid == resource.data.createdBy;
      match /bills/{billId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
        allow create, delete: if request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
      }
    }
  }
}
```

---

## 🚀 How to Use

1. **Sign in** with Google on both phones
2. **Partner A** enters Partner B's email → creates group
3. **Partner B** signs in, enters Partner A's email → joins same group
4. Start adding bills and watch them sync instantly!

---

## 📱 Testing Locally

```bash
# Run with Hot Reload (for development)
flutter run

# Build APK for installation
flutter build apk

# Release build
flutter build apk --release
```

---

## ❓ Common Issues

| Problem | Solution |
|---------|----------|
| Firebase not initializing | Delete `google-services.json` and run `flutterfire configure` again |
| Sign-in fails | Ensure Gmail is enabled on your Google account |
| Bills not syncing | Check internet connection and Firestore Rules |
| Build errors | Run `flutter clean && flutter pub get` |

---

For detailed setup and troubleshooting, see [README.md](README.md)
