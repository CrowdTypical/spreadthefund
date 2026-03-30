// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _showEmailForm = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _showForgotPassword = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent, width: 1),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'SPREAD THE FUNDS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'SPLIT BILLS IN REAL-TIME',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                if (_showForgotPassword)
                  _buildForgotPasswordForm()
                else if (_showEmailForm)
                  _buildEmailForm()
                else
                  _buildAuthButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButtons() {
    return Column(
      children: [
        _buildGoogleSignInButton(),
        const SizedBox(height: 16),
        _buildDividerRow(),
        const SizedBox(height: 16),
        _buildEmailSignInButton(),
      ],
    );
  }

  Widget _buildDividerRow() {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 2,
              color: AppColors.textDim,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
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
          : OutlinedButton(
              onPressed: _signInWithGoogle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.accent, width: 1),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: const Text(
                'SIGN IN WITH GOOGLE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
    );
  }

  Widget _buildEmailSignInButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => setState(() => _showEmailForm = true),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.border, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: const Text(
          'SIGN IN WITH EMAIL',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Text(
            _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            maxLength: 254,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              labelText: 'EMAIL',
              labelStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 1,
                color: AppColors.textMuted,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.accent),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.danger),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!isValidEmail(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'PASSWORD',
              labelStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 1,
                color: AppColors.textMuted,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.accent),
              ),
              errorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.danger),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.danger),
              ),
              filled: true,
              fillColor: AppColors.surface,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textDim,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (_isSignUp) {
                final authService = context.read<AuthService>();
                return authService.validatePassword(value);
              }
              return null;
            },
          ),
          if (_isSignUp) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                labelText: 'CONFIRM PASSWORD',
                labelStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 1,
                  color: AppColors.textMuted,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.accent),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.danger),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.danger),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
          if (_isSignUp)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Min 8 chars, 1 number, 1 special character',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: AppColors.textDim,
                ),
              ),
            ),
          const SizedBox(height: 24),
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
                : OutlinedButton(
                    onPressed: _submitEmailForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.accent, width: 1),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: Text(
                      _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (!_isSignUp)
            GestureDetector(
              onTap: () => setState(() {
                _showForgotPassword = true;
                _resetEmailController.text = _emailController.text;
              }),
              child: const Text(
                'FORGOT PASSWORD?',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  letterSpacing: 1,
                  color: AppColors.textMuted,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textMuted,
                ),
              ),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() {
              _isSignUp = !_isSignUp;
              _confirmPasswordController.clear();
            }),
            child: Text(
              _isSignUp ? 'ALREADY HAVE AN ACCOUNT? SIGN IN' : 'NO ACCOUNT? CREATE ONE',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 1,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => setState(() {
              _showEmailForm = false;
              _isSignUp = false;
              _emailController.clear();
              _passwordController.clear();
              _confirmPasswordController.clear();
            }),
            child: const Text(
              'â† BACK',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 1,
                color: AppColors.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordForm() {
    return Column(
      children: [
        const Text(
          'RESET PASSWORD',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter your email and we\'ll send a reset link if an account exists.',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            letterSpacing: 0.5,
            color: AppColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _resetEmailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          maxLength: 254,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            labelText: 'EMAIL',
            labelStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.accent),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
        const SizedBox(height: 24),
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
              : OutlinedButton(
                  onPressed: _sendPasswordReset,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.accent, width: 1),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: const Text(
                    'SEND RESET LINK',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => _showForgotPassword = false),
          child: const Text(
            '\u2190 BACK TO SIGN IN',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              letterSpacing: 1,
              color: AppColors.textDim,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final result = await authService.signInWithGoogle();

      // Only show "cancelled" if the user explicitly dismissed the Google picker
      // and Firebase auth didn't already sign them in via the stream.
      if (result == null && mounted && authService.currentUser == null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Sign-in cancelled')),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitEmailForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final Map<String, dynamic> result;

      if (_isSignUp) {
        result = await authService.signUpWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        result = await authService.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      }

      if (!result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'An error occurred')),
        );
      } else if (result['success'] && _isSignUp && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please check your email to verify your account.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.sendPasswordReset(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('If this email exists, a reset link has been sent.'),
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _showForgotPassword = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
