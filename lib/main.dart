import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SpreadTheFundApp());
}

class SpreadTheFundApp extends StatelessWidget {
  const SpreadTheFundApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Spread the Fund',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0E14),
          primaryColor: const Color(0xFF00E5CC),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5CC),
            secondary: Color(0xFF00E5CC),
            surface: Color(0xFF141A22),
            onPrimary: Color(0xFF0A0E14),
            onSurface: Color(0xFFE0E0E0),
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: Color(0xFF0F1419),
            foregroundColor: Color(0xFFE0E0E0),
            titleTextStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Color(0xFFE0E0E0),
            ),
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF141A22),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: Color(0xFF1E2A35), width: 1),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF00E5CC),
            foregroundColor: Color(0xFF0A0E14),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF8899AA)),
          dividerColor: const Color(0xFF1E2A35),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF141A22),
            contentTextStyle: TextStyle(color: Color(0xFFE0E0E0)),
          ),
        ),
        home: Builder(
          builder: (context) {
            final authService = context.read<AuthService>();
            return StreamBuilder(
              stream: authService.authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  if (snapshot.data != null) {
                    return const HomeScreen();
                  } else {
                    return const LoginScreen();
                  }
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            );
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
