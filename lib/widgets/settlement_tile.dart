// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/theme_constants.dart';

class SettlementTile extends StatelessWidget {
  final String settlementId;
  final double amount;
  final String from;
  final String to;
  final DateTime date;
  final double remainingBalance;
  final String paymentMethod;
  final String currentUserEmail;
  final VoidCallback onTap;

  const SettlementTile({
    super.key,
    required this.settlementId,
    required this.amount,
    required this.from,
    required this.to,
    required this.date,
    required this.remainingBalance,
    required this.currentUserEmail,
    required this.onTap,
    this.paymentMethod = '',
  });

  @override
  Widget build(BuildContext context) {
    final isYou = from == currentUserEmail;
    final who = isYou ? 'You' : 'They';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1A12),
          border: Border(
            left: BorderSide(color: Color(0xFF4CAF50), width: 3),
          ),
        ),
        child: Row(
          children: [
            // Settlement icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.handshake,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Settlement text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$who SETTLED UP',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    remainingBalance > 0.01
                        ? '\$${remainingBalance.toStringAsFixed(2)} remaining'
                        : 'All settled!',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: remainingBalance > 0.01
                          ? AppColors.danger
                          : const Color(0xFF4CAF50),
                    ),
                  ),
                  if (paymentMethod.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'via $paymentMethod',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Amount + date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, h:mm:ss a').format(date),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
