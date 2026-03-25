# Bill Splitter App

A Flutter app for splitting bills with your partner in real-time using Firebase.

## Features

✅ **Real-time bill updates** - When you or your partner adds a bill, it appears instantly  
✅ **Google Sign-In** - Easy authentication with Google accounts  
✅ **Balance tracking** - See who owes whom at a glance  
✅ **Responsive design** - Works great on different Android phone sizes  
✅ **Bill management** - Add, view, and delete bills  
✅ **Equal splits** - Automatically splits bills 50/50 between you and your partner  

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Android device or emulator
- Firebase account (free tier works)
- Google Cloud account for Google Sign-In setup

## Setup Instructions

### 1. Clone and Navigate to Project

```bash
cd path/to/your/project
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a new project"
3. Give it a name (e.g., "BillSplitter")
4. Enable Google Analytics (optional)
5. Click "Create Project"

### 4. Configure Android for Firebase

1. In Firebase Console, click "Add app" and select "Android"
2. Fill in the app details:
   - **Package name**: `com.example.bill_splitter`
   - **App nickname**: Bill Splitter (optional)
   - **SHA-1 certificate**: Run `./gradlew signingReport` in the android folder to get this
3. Download the `google-services.json` file
4. Place it in `android/app/` directory

### 5. Set Up Google Sign-In

1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Google** sign-in method
3. Go to **Settings** (⚙️) → **Project settings**
4. Under the **SERVICE ACCOUNTS** tab, create a new key
5. Note your **Web Client ID** (you may need this for OAuth configuration)

### 6. Update Firebase Options

1. Install the FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

2. Run the configuration command:
```bash
flutterfire configure
```

This will automatically update `lib/firebase_options.dart` with your Firebase credentials.

### 7. Update Android Manifest

1. Open `android/app/src/main/AndroidManifest.xml`
2. Add these permissions inside the `<manifest>` tag:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 8. Run the App

```bash
flutter run
```

Or for debug build:
```bash
flutter run --debug
```

For release build:
```bash
flutter run --release
```

## How to Use

### First Time Setup

1. **Launch the app** and tap "Sign in with Google"
2. **Sign in** with your Google account
3. **Enter your partner's email** on the setup screen
4. Your partner should do the same and enter your email

### Adding Bills

1. Tap the **+ button** on the home screen
2. Fill in:
   - **Description**: What the bill is for
   - **Amount**: How much was spent
   - **Who paid**: Select who paid for it
3. Tap **Add Bill** - your partner will see it instantly!

### Checking Balance

- The **Balance card** at the top shows who owes whom
- If you see "You owe $X", you need to pay your partner that amount
- If it says "They owe you $X", they owe you that amount

### Deleting Bills

- **Long press** on any bill to delete it (both users see the deletion instantly)

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── models/
│   ├── bill.dart              # Bill data model
│   └── group.dart             # Group data model
├── services/
│   ├── auth_service.dart      # Authentication logic
│   └── bill_service.dart      # Firestore operations
└── screens/
    ├── login_screen.dart      # Google Sign-In screen
    ├── home_screen.dart       # Main bill list screen
    ├── add_bill_screen.dart   # Add new bill screen
    └── partner_setup_screen.dart  # Partner email setup
```

## Firestore Database Structure

```
groups/
├── {groupId}
│   ├── members: [userId1, partnerEmail]
│   ├── createdAt: timestamp
│   └── createdBy: userId
│   └── bills/
│       └── {billId}
│           ├── paidBy: userId
│           ├── amount: number
│           ├── description: string
│           ├── createdAt: timestamp
│           └── settled: boolean

users/
├── {userId}
│   ├── uid: string
│   ├── email: string
│   ├── displayName: string
│   ├── photoUrl: string
│   └── createdAt: timestamp
```

## Firebase Rules

Add these Firestore Security Rules to allow data sharing between partners:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Allow group members to read/write group and bills
    match /groups/{groupId} {
      allow read: if request.auth.uid in resource.data.members;
      allow write: if request.auth.uid == resource.data.createdBy;
      
      match /bills/{billId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
        allow create: if request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
        allow delete: if request.auth.uid == resource.data.paidBy;
      }
      
      match /settlements/{settlementId} {
        allow read: if request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
        allow create: if request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
      }
    }
  }
}
```

## Troubleshooting

### App won't start / Firebase not initialized
- Make sure `google-services.json` is in the correct location
- Run `flutter pub get` again
- Clean build: `flutter clean && flutter pub get`

### Sign-in not working
- Verify your SHA-1 in Firebase matches the actual app
- Check that Google Sign-In is enabled in Firebase Console
- Make sure `google-services.json` is properly configured

### Bills not syncing between phones
- Ensure both phones are signed in with valid accounts
- Check internet connectivity on both devices
- Verify Firestore Rules are correctly set

### Build errors
- Run `flutter doctor -v` to check your environment
- Update Flutter: `flutter upgrade`
- Clean build: `flutter clean`

## Future Features

- 💰 Settlement tracking (record payments)
- 👥 Multiple partners/bill groups
- 📊 Expense statistics and charts
- 🔔 Notifications for new bills
- 💳 Venmo/PayPal integration
- 🌙 Dark mode

## License

This project is open source and available under the MIT License.

## Support

For issues or questions, please create an issue on GitHub or contact the developer.
