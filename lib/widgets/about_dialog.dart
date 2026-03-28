// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../constants/theme_constants.dart';
import 'glitch_dollar_icon.dart';

void showAboutApp(
  BuildContext context, {
  required BillService billService,
  required AuthService authService,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GlitchDollarIcon(size: 80),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.accent, Color(0xFF42A5F5)],
              ).createShader(bounds),
              child: const Text(
                'SPREAD\nTHE FUNDS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  letterSpacing: 4,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              appVersion,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'A bill-splitting app',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Developer section
            const Text(
              'This app is a passion project\ndeveloped by Jason Green',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://github.com/CrowdTypical'), mode: LaunchMode.externalApplication),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.code, color: AppColors.accent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'github.com/CrowdTypical',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.accent,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Donate section
            const Text(
              'SUPPORT THE PROJECT',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 2,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://buymeacoffee.com/crowdtypical'), mode: LaunchMode.externalApplication),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFA726)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.coffee, color: Color(0xFFFFA726), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'BUY ME A COFFEE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Color(0xFFFFA726),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Privacy Policy
            const Text(
              'PRIVACY POLICY',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 2,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Spread the Funds collects only the data '
              'necessary to provide its core bill-splitting '
              'functionality:\n\n'
              '\u2022 Google account info (name, email, photo) '
              'for authentication\n'
              '\u2022 Group and bill data you create within the app\n'
              '\u2022 Feedback you voluntarily submit\n\n'
              'Your data is stored securely in Firebase and is '
              'never sold or shared with third parties.',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.5,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Terms and Conditions
            const Text(
              'TERMS & CONDITIONS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 2,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'By using Spread the Funds, you agree to the '
              'following terms:\n\n'
              '\u2022 You must be at least 13 years old to use this app.\n'
              '\u2022 You are responsible for the accuracy of the bills '
              'and data you enter.\n'
              '\u2022 This app is provided "as is" without warranties '
              'of any kind, express or implied.\n'
              '\u2022 We are not liable for any financial disputes '
              'arising from the use of this app.\n'
              '\u2022 You may not use this app to compete with '
              'Spread the Funds or its developer.\n'
              '\u2022 Your data is stored in Firebase and handled '
              'according to our Privacy Policy.\n'
              '\u2022 We reserve the right to modify or discontinue '
              'the app at any time.\n'
              '\u2022 Misuse of the app, including fraudulent activity, '
              'may result in account termination.\n\n'
              'This app is licensed under the PolyForm Shield '
              'License 1.0.0. Full license details are available '
              'at polyformproject.org/licenses/shield/1.0.0/',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.5,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Delete data section
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteDataDialog(context, billService: billService, authService: authService);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_forever, color: Color(0xFFEF5350), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'DELETE MY DATA',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Color(0xFFEF5350),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'CLOSE',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    ),
  );
}

void _showDeleteDataDialog(
  BuildContext context, {
  required BillService billService,
  required AuthService authService,
}) {
  final confirmController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final confirmed = confirmController.text.trim().toUpperCase() == 'DELETE';
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text(
            'DELETE ALL DATA',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Color(0xFFEF5350),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete:',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'â€¢ Your account & profile\n'
                'â€¢ All groups where you are the only member\n'
                'â€¢ Your membership in shared groups\n'
                'â€¢ All invites you sent or received\n'
                'â€¢ All feedback you submitted',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'THIS CANNOT BE UNDONE.',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF5350),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Type DELETE to confirm:',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                autofocus: true,
                maxLength: 6,
                onChanged: (_) => setDialogState(() {}),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF5350),
                ),
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF333D47),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Color(0xFFEF5350)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: confirmed
                  ? () => _executeDeleteAllData(
                        ctx,
                        context,
                        billService: billService,
                        authService: authService,
                      )
                  : null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: confirmed
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF333D47),
                ),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(
                'DELETE EVERYTHING',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: confirmed
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF333D47),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _executeDeleteAllData(
  BuildContext dialogContext,
  BuildContext parentContext, {
  required BillService billService,
  required AuthService authService,
}) async {
  Navigator.pop(dialogContext);
  Navigator.pop(parentContext); // close drawer

  final user = authService.currentUser;
  if (user == null || user.email == null) return;

  final messenger = ScaffoldMessenger.of(parentContext);
  final email = user.email!;
  final uid = user.uid;

  // Show loading indicator
  messenger.showSnackBar(
    const SnackBar(
      backgroundColor: AppColors.surface,
      duration: Duration(seconds: 10),
      content: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFEF5350),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Deleting all data...',
            style: TextStyle(fontFamily: 'monospace', color: Color(0xFFEF5350)),
          ),
        ],
      ),
    ),
  );

  // Re-authenticate FIRST while the UI is stable
  if (authService.isEmailPasswordUser) {
    // Email/password users need to provide their password
    final password = await _showPasswordPrompt(parentContext);
    if (password == null) {
      messenger.clearSnackBars();
      return;
    }
    final reauthed = await authService.reauthenticate(password: password);
    if (!reauthed) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Incorrect password. Deletion cancelled.',
            style: TextStyle(fontFamily: 'monospace', color: AppColors.danger),
          ),
        ),
      );
      return;
    }
  } else {
    await authService.reauthenticate();
  }

  // Delete all Firestore data first — only proceed to auth deletion if successful
  final dataDeleted = await billService.deleteAllUserData(email, uid);

  messenger.clearSnackBars();

  if (!dataDeleted) {
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'Some data could not be deleted. Please try again.',
          style: TextStyle(fontFamily: 'monospace', color: AppColors.danger),
        ),
      ),
    );
    return;
  }

  // Delete the Firebase Auth account only after Firestore cleanup succeeded
  final authDeleted = await authService.deleteAccount();

  if (!authDeleted) {
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'Could not delete auth account. Please try again.',
          style: TextStyle(fontFamily: 'monospace', color: AppColors.danger),
        ),
      ),
    );
    return;
  }

  // Sign out to fully clear Google/provider session
  await authService.signOut();
}

/// Shows a dialog prompting the email/password user for their current password.
/// Returns the entered password, or null if the user cancelled.
Future<String?> _showPasswordPrompt(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: const Text(
        'CONFIRM PASSWORD',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          color: Color(0xFFEF5350),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your password to confirm account deletion.',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF333D47),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Color(0xFFEF5350)),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text(
            'CANCEL',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () {
            final pw = controller.text;
            if (pw.isNotEmpty) Navigator.pop(ctx, pw);
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEF5350)),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          child: const Text(
            'CONFIRM',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Color(0xFFEF5350),
            ),
          ),
        ),
      ],
    ),
  );
}
