---
description: Flutter and Dart development patterns, architecture, and best practices
applyTo: "**/*.dart,**/pubspec.yaml,**/pubspec.lock,**/analysis_options.yaml"
---

# Flutter & Dart Standards

When working on Flutter/Dart projects (Spread The Funds), follow these patterns in addition to
the universal coding style.

---

## Architecture

### Feature-First + MVVM

```
lib/
├── core/                    # Shared infrastructure
│   ├── constants/           # App-wide constants
│   ├── extensions/          # Dart extension methods
│   ├── services/            # Firebase, auth, navigation
│   ├── theme/               # ThemeData, colors, text styles
│   ├── utils/               # Pure utility functions
│   └── widgets/             # Shared reusable widgets
├── features/                # Feature modules
│   ├── auth/
│   │   ├── models/          # Data models for auth
│   │   ├── screens/         # Auth screens (login, register)
│   │   ├── services/        # Auth-specific services
│   │   ├── view_models/     # Auth state management
│   │   └── widgets/         # Auth-specific widgets
│   ├── debt_list/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── view_models/
│   │   └── widgets/
│   └── home/
├── main.dart
└── app.dart                 # MaterialApp / root widget
```

**Rules:**
- **Feature folders** group related code — screens, models, view models, widgets for one feature stay together
- **Core** holds shared infrastructure used across features
- **No circular dependencies** between features — if two features need the same thing, it goes in `core/`
- **Co-locate tests** — mirror the `lib/` structure under `test/`

---

## State Management

### Recommended: Provider / Riverpod / ChangeNotifier

Use whatever the project already has. For new code, prefer simplicity:

```dart
// ✅ ChangeNotifier for straightforward state
class DebtListViewModel extends ChangeNotifier {
  List<DebtItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<DebtItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadItems(String listId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _debtService.getItems(listId);
    } catch (e) {
      _errorMessage = 'Failed to load items: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

**Rules:**
- **Never expose mutable state directly** — use getters that return unmodifiable views
- **Single source of truth** — one ViewModel per screen/feature
- **Keep widgets dumb** — business logic lives in ViewModels/services, not in `build()` methods
- **Dispose resources** — cancel subscriptions, close streams in `dispose()`

---

## Widget Patterns

### Stateless Over Stateful

```dart
// ✅ Prefer StatelessWidget — receives data, emits events
class DebtItemCard extends StatelessWidget {
  const DebtItemCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final DebtItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Widget tree here
  }
}
```

```dart
// ✅ Use StatefulWidget only when you need local UI state
// (animations, text controllers, focus nodes)
class SearchBar extends StatefulWidget {
  const SearchBar({required this.onSearch, super.key});

  final ValueChanged<String> onSearch;

  @override
  State<SearchBar> createState() => _SearchBarState();
}
```

**Rules:**
- **`const` constructors everywhere possible** — enables widget caching
- **Use `super.key`** — not `Key? key` in the constructor (Dart 3 style)
- **Extract widgets into classes** — not helper methods that return widgets (breaks rebuild optimization)
- **Keep `build()` methods focused** — extract sub-trees into separate widgets when they grow past ~50 lines

### Widget Extraction vs Helper Methods

```dart
// ❌ Helper method — always rebuilds, can't be const, no lifecycle
Widget _buildHeader() {
  return Text('Header');
}

// ✅ Separate widget — can be const, has proper lifecycle
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Text('Header');
  }
}
```

---

## Dart Patterns

### Null Safety

```dart
// ❌ Don't use ! unless you've verified the value exists
final name = user!.name;

// ✅ Use null-aware operators
final name = user?.name ?? 'Unknown';

// ✅ Early return for null checks
final user = getUser();
if (user == null) return;
// user is now non-null for the rest of the function
```

- **Never use `!` (bang operator) without a clear preceding null check** — it's a crash waiting to happen
- **Use `??` for defaults**, `?.` for chaining, `?..` for cascades
- **Null means "absent"** — use custom result types or exceptions for errors

### Collections

```dart
// ✅ Use collection literals
final items = <String>[];           // Not List<String>()
final lookup = <String, int>{};     // Not Map<String, int>()
final unique = <String>{};          // Not Set<String>()

// ✅ Use collection-if and collection-for
final widgets = [
  const Header(),
  if (showSubtitle) const Subtitle(),
  for (final item in items) ItemCard(item: item),
];
```

### Async/Await

```dart
// ✅ Always handle errors in async code
Future<void> saveItem(DebtItem item) async {
  try {
    await _firestore.collection('items').doc(item.id).set(item.toMap());
  } on FirebaseException catch (e) {
    throw DataException('Failed to save item "${item.title}": ${e.message}');
  }
}

// ✅ Use FutureBuilder / StreamBuilder in widgets
StreamBuilder<List<DebtItem>>(
  stream: debtService.watchItems(listId),
  builder: (context, snapshot) {
    if (snapshot.hasError) return ErrorDisplay(error: snapshot.error!);
    if (!snapshot.hasData) return const LoadingIndicator();
    return DebtList(items: snapshot.data!);
  },
)
```

---

## Firebase Patterns

### Firestore Structure

```dart
// ✅ Name collections as plural nouns
// users/{userId}/lists/{listId}/items/{itemId}

// ✅ Service class abstracts Firestore
class DebtService {
  final FirebaseFirestore _firestore;

  DebtService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<DebtItem>> watchItems(String listId) {
    return _firestore
        .collection('lists')
        .doc(listId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => DebtItem.fromFirestore(doc)).toList());
  }
}
```

**Rules:**
- **Never put Firestore calls directly in widgets** — always go through a service class
- **Use streams for real-time data** — Firestore's `snapshots()` is powerful, use it
- **Security rules are mandatory** — never rely on client-side validation alone
- **Keep documents small** — don't embed unbounded lists in documents

### Firebase Auth

```dart
// ✅ Centralized auth service
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    }
  }
}
```

---

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Files | `snake_case.dart` | `debt_list_screen.dart` |
| Classes | `PascalCase` | `DebtListViewModel` |
| Variables / Functions | `camelCase` | `loadItems()`, `isLoading` |
| Constants | `camelCase` (Dart convention) | `defaultPadding`, `maxRetries` |
| Private | Prefix with `_` | `_items`, `_handleTap()` |
| Enums | `PascalCase` values | `DebtStatus.pending` |

---

## Project Configuration

### analysis_options.yaml

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - avoid_print
    - avoid_unnecessary_containers
    - sized_box_for_whitespace
    - use_key_in_widget_constructors
    - prefer_single_quotes
    - require_trailing_commas

analyzer:
  errors:
    missing_return: error
    dead_code: warning
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
```

### Pre-Commit Checklist

```bash
# Run before every commit
dart analyze                          # Static analysis
dart format --set-exit-if-changed .   # Formatting check
flutter test                          # Unit tests (when you have them)
flutter build apk --debug             # Verify it compiles
```

Start with just `dart analyze` and `dart format`. Add `flutter test` once you have tests.

---

## Testing

### Getting Started (Adopt Incrementally)

Don't try to test everything at once. Start here:

1. **Test pure functions first** — utility functions, formatters, validators
2. **Then test ViewModels** — state transitions, error handling
3. **Then test services** — with mocked Firebase (use `fake_cloud_firestore`)
4. **Skip widget tests initially** — they have the worst effort-to-value ratio for solo devs

```dart
// test/features/debt_list/debt_item_test.dart
import 'package:test/test.dart';

void main() {
  group('DebtItem', () {
    test('calculates total correctly', () {
      final item = DebtItem(
        title: 'Dinner',
        amount: 50.0,
        splitCount: 2,
      );

      expect(item.perPersonAmount, equals(25.0));
    });

    test('handles zero split count gracefully', () {
      final item = DebtItem(
        title: 'Dinner',
        amount: 50.0,
        splitCount: 0,
      );

      expect(item.perPersonAmount, equals(0.0));
    });
  });
}
```

### Test File Naming

- `debt_item_test.dart` — mirrors `debt_item.dart`
- Place in `test/` directory mirroring `lib/` structure

---

## Common Anti-Patterns

| ❌ Avoid | ✅ Prefer |
|----------|-----------|
| `!` (bang) without null check | Safe access `?.`, `??`, early return |
| Business logic in `build()` | Move to ViewModel or service |
| `setState()` for complex state | ChangeNotifier / Provider / Riverpod |
| `dynamic` type | Proper typed parameters |
| Firestore calls in widgets | Service classes |
| Helper methods returning widgets | Extract to separate widget classes |
| `print()` for debugging | `debugPrint()` or proper logging |
| Hardcoded strings in UI | Extract to constants or localization |
| Ignoring `dart analyze` warnings | Fix them — they're usually right |
| Giant `build()` methods (100+ lines) | Extract sub-widgets |
