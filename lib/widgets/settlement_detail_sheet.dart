// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../constants/theme_constants.dart';

Widget _settlementDetailRow(String label, String value, Color valueColor) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: AppColors.textMuted,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: valueColor,
        ),
      ),
    ],
  );
}

void showSettlementDetailSheet(
  BuildContext context, {
  required String settlementId,
  required double amount,
  required String from,
  required String to,
  required DateTime date,
  required double remainingBalance,
  String paymentMethod = '',
  required String? groupId,
  required BillService billService,
  VoidCallback? onChanged,
}) {
  final currentUser = context.read<AuthService>().currentUser!.email!.toLowerCase();
  final isYou = from == currentUser;
  const accent = Color(0xFF4CAF50);

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
    ),
    builder: (sheetContext) {
      bool isEditing = false;
      final amountController = TextEditingController(text: amount.toStringAsFixed(2));
      final methodController = TextEditingController(text: paymentMethod);

      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header: icon + title + amount
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            border: Border.all(color: accent.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.handshake, color: accent, size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isEditing ? 'EDIT SETTLEMENT' : 'SETTLEMENT',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isEditing)
                          SizedBox(
                            width: 160,
                            child: TextField(
                              controller: amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              maxLength: 12,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                              decoration: InputDecoration(
                                prefixText: '\$ ',
                                prefixStyle: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: accent.withValues(alpha: 0.5)),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: accent),
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy â€” h:mm a').format(date),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DETAILS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            letterSpacing: 1,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _settlementDetailRow('Paid by', isYou ? 'You' : from, accent),
                        const SizedBox(height: 8),
                        _settlementDetailRow('Paid to', isYou ? from : 'You', accent),
                        if (isEditing) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'METHOD',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              letterSpacing: 1,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: methodController,
                            maxLength: 50,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Cash, Venmo...',
                              hintStyle: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: AppColors.textDim,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: accent),
                              ),
                            ),
                          ),
                        ] else if (paymentMethod.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _settlementDetailRow('Method', paymentMethod, AppColors.textPrimary),
                        ],
                        if (!isEditing) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            color: remainingBalance > 0.01
                                ? AppColors.danger.withValues(alpha: 0.08)
                                : accent.withValues(alpha: 0.08),
                            child: Text(
                              remainingBalance > 0.01
                                  ? '\$${remainingBalance.toStringAsFixed(2)} remaining after this'
                                  : 'All settled!',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: remainingBalance > 0.01
                                    ? AppColors.danger
                                    : accent,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Edit / Delete buttons (or Save / Cancel when editing)
                  if (isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() => isEditing = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Text(
                                'CANCEL',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final newAmount = double.tryParse(amountController.text);
                              if (newAmount == null || newAmount <= 0) return;
                              final success = await billService.updateSettlement(
                                groupId: groupId!,
                                settlementId: settlementId,
                                amount: newAmount,
                                paymentMethod: methodController.text.trim(),
                              );
                              if (success) {
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                onChanged?.call();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                border: Border.all(color: accent.withValues(alpha: 0.5)),
                              ),
                              child: const Text(
                                'SAVE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() => isEditing = true);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.08),
                                border: Border.all(color: accent.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit, color: accent, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'EDIT',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  title: const Text(
                                    'DELETE SETTLEMENT?',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      letterSpacing: 1,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  content: Text(
                                    'Settlement of \$${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text(
                                        'CANCEL',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final success = await billService.deleteSettlement(
                                          groupId: groupId!,
                                          settlementId: settlementId,
                                        );
                                        if (success) {
                                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                                          onChanged?.call();
                                        }
                                      },
                                      child: const Text(
                                        'DELETE',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline, color: AppColors.danger, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'DELETE',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      );
    },
  );
}
