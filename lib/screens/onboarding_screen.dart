// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../constants/theme_constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty) return;

    setState(() => _isLoading = true);

    final fullName = lastName.isEmpty ? firstName : '$firstName $lastName';
    final authService = context.read<AuthService>();
    await authService.updateUsername(fullName);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1520),
              AppColors.background,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    size: 48,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'WELCOME!',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppColors.accent,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Almost there — what should we call you?',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _firstNameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 50,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'FIRST NAME',
                    labelStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 50,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'LAST NAME',
                    labelStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            color: AppColors.surface,
                          ),
                          child: const Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                              ),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _saveAndContinue,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'CONTINUE',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
