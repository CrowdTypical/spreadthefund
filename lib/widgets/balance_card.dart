// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import '../constants/theme_constants.dart';

class BalanceCard extends StatelessWidget {
  final double youOwe;
  final double theyOwe;
  final VoidCallback? onSettle;

  const BalanceCard({
    super.key,
    required this.youOwe,
    required this.theyOwe,
    this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    final difference = youOwe - theyOwe;
    final bool hasBalance = difference.abs() >= 0.01;

    if (!hasBalance) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        ),
        child: const Center(
          child: Text(
            'SETTLED UP',
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

    final bool youOweMore = difference > 0;
    final label = youOweMore ? 'You Owe' : 'They Owe You';
    final amount = '\$${difference.abs().toStringAsFixed(2)}';
    final accentColor = youOweMore ? AppColors.danger : AppColors.accent;
    final buttonLabel = youOweMore ? 'SETTLE' : 'FORGIVE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: accentColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSettle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A3D33),
                border: Border.all(color: const Color(0xFF00E5CC), width: 1.5),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Color(0xFF00E5CC),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
