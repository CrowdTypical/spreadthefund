// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/bill_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/email_verification_screen.dart';
import 'services/auth_service.dart';
import 'constants/theme_constants.dart';

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
        Provider<BillService>(create: (_) => BillService()),
        Provider<AuthService>(create: (context) => AuthService(context.read<BillService>())),
      ],
      child: MaterialApp(
        title: 'Spread the Funds',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.accent,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            secondary: AppColors.accent,
            surface: AppColors.surface,
            onPrimary: AppColors.background,
            onSurface: AppColors.textPrimary,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: Color(0xFF0F1419),
            foregroundColor: AppColors.textPrimary,
            titleTextStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
          cardTheme: const CardThemeData(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
          ),
          iconTheme: const IconThemeData(color: AppColors.textMuted),
          dividerColor: AppColors.border,
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: AppColors.surface,
            contentTextStyle: TextStyle(color: AppColors.textPrimary),
          ),
        ),
        home: Builder(
          builder: (context) {
            final authService = context.read<AuthService>();
            return StreamBuilder(
              stream: authService.authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  final user = snapshot.data;
                  if (user != null) {
                    // If email/password user hasn't verified email, show verification screen
                    final isEmailProvider = user.providerData.any(
                      (info) => info.providerId == 'password',
                    );
                    if (isEmailProvider && !user.emailVerified) {
                      return const EmailVerificationScreen();
                    }
                    // Listen to user doc for onboarding status
                    return StreamBuilder(
                      stream: authService.userDocStream,
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final data = userSnap.data!.data() as Map<String, dynamic>?;
                        final username = data?['username'] as String?;
                        if (username == null || username.isEmpty) {
                          return const OnboardingScreen();
                        }
                        return const HomeScreen();
                      },
                    );
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
