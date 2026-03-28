// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../constants/theme_constants.dart';

class BillTile extends StatelessWidget {
  final Bill bill;
  final String currentUserEmail;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const BillTile({
    super.key,
    required this.bill,
    required this.currentUserEmail,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isYourBill = bill.paidBy == currentUserEmail;
    final accentColor = isYourBill ? AppColors.accent : AppColors.danger;
    final catColor = colorForCategory(bill.category.isNotEmpty ? bill.category : bill.description);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Row(
          children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                border: Border.all(color: catColor.withValues(alpha: 0.3)),
              ),
              child: Icon(
                iconForCategory(bill.category.isNotEmpty ? bill.category : bill.description),
                color: catColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Description + split info (left)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.description.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((bill.splitPercent - 50).abs() > 1) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Split ${bill.splitPercent.round()}/${(100 - bill.splitPercent).round()}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                  if (bill.notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      bill.notes,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Color(0xFF667788),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Amount + owed + date (right)
            Builder(builder: (_) {
              final owed = isYourBill
                  ? bill.amount * (100 - bill.splitPercent) / 100
                  : bill.amount * bill.splitPercent / 100;
              final owedLabel = isYourBill ? "You're owed:" : 'You owe:';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${bill.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$owedLabel ',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '\$${owed.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, h:mm:ss a').format(bill.createdAt),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
