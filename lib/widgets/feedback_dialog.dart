// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';

Widget _feedbackTypeChip(String value, String label, String current, ValueChanged<String> onTap) {
  final isActive = current == value;
  return GestureDetector(
    onTap: () => onTap(value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.accent.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border.all(
          color: isActive
              ? AppColors.accent
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive
              ? AppColors.accent
              : AppColors.textMuted,
        ),
      ),
    ),
  );
}

Future<void> _submitFeedback(BuildContext context, String type, String body) async {
  final user = context.read<AuthService>().currentUser;
  await FirebaseFirestore.instance.collection('feedback').add({
    'type': type,
    'body': body,
    'email': user?.email,
    'appVersion': appVersion,
    'createdAt': FieldValue.serverTimestamp(),
  });

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'Feedback sent â€” thank you!',
          style: TextStyle(fontFamily: 'monospace', color: AppColors.accent),
        ),
      ),
    );
  }
}

void showFeedbackDialog(BuildContext context) {
  final feedbackController = TextEditingController();
  String feedbackType = 'suggestion';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'SEND FEEDBACK',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppColors.accent,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TYPE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  letterSpacing: 1,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _feedbackTypeChip('suggestion', 'SUGGESTION', feedbackType, (val) {
                    setDialogState(() => feedbackType = val);
                  }),
                  const SizedBox(width: 8),
                  _feedbackTypeChip('bug', 'BUG', feedbackType, (val) {
                    setDialogState(() => feedbackType = val);
                  }),
                  const SizedBox(width: 8),
                  _feedbackTypeChip('other', 'OTHER', feedbackType, (val) {
                    setDialogState(() => feedbackType = val);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                maxLines: 5,
                minLines: 3,
                maxLength: 1000,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Describe your feedback...',
                  hintStyle: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF455566),
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
                  fillColor: Color(0xFF0D1117),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
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
            onPressed: () {
              final text = feedbackController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              _submitFeedback(context, feedbackType, text);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accent),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: const Text(
              'SEND',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
