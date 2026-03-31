// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../constants/theme_constants.dart';

const _paymentMethods = ['PayPal', 'Venmo', 'Direct Deposit', 'Cash', 'Zelle', 'Other'];
const _forgiveReasons = ['They Paid Me Back', 'Gift', 'Splitting Evenly', 'Other'];

Future<String> _loadPreferredPaymentMethod(String? uid) async {
  if (uid == null) return _paymentMethods.first;
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final method = doc.data()?['preferredPaymentMethod'] as String?;
    if (method != null && _paymentMethods.contains(method)) return method;
  } catch (_) {}
  return _paymentMethods.first;
}

Future<void> _savePreferredPaymentMethod(String? uid, String method) async {
  if (uid == null) return;
  await FirebaseFirestore.instance.collection('users').doc(uid).set(
    {'preferredPaymentMethod': method},
    SetOptions(merge: true),
  );
}

void showSettleUpDialog(
  BuildContext context, {
  required double suggestedAmount,
  required String partnerEmail,
  required bool youOwe,
  required String? groupId,
  required BillService billService,
  VoidCallback? onSettled,
}) {
  final amountController = TextEditingController(
    text: suggestedAmount.toStringAsFixed(2),
  );
  final user = context.read<AuthService>().currentUser;
  if (user == null || groupId == null) return;

  final currentEmail = user.email!.toLowerCase();

  // State managed inside the dialog
  String selectedPayer = currentEmail;
  String selectedMethod = _paymentMethods.first;
  bool loadingMethod = true;
  List<Map<String, String>> members = [];
  bool loadingMembers = true;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        // Load preferred method once (skip for forgive flow)
        if (loadingMethod) {
          loadingMethod = false;
          if (!youOwe) {
            selectedMethod = _forgiveReasons.first;
          } else {
            _loadPreferredPaymentMethod(user.uid).then((method) {
              if (ctx.mounted) {
                setDialogState(() => selectedMethod = method);
              }
            });
          }
        }
        // Load group members once
        if (loadingMembers) {
          loadingMembers = false;
          billService.getGroupMembers(groupId).then((m) {
            if (ctx.mounted) {
              setDialogState(() => members = m);
            }
          });
        }

        // Build payer dropdown items from group members
        final payerItems = <DropdownMenuItem<String>>[];
        if (members.isEmpty) {
          // Fallback while loading
          payerItems.add(DropdownMenuItem(
            value: currentEmail,
            child: Text(
              '${user.displayName ?? currentEmail.split('@').first} (You)',
              style: const TextStyle(fontFamily: 'monospace', color: AppColors.accent),
            ),
          ));
        } else {
          for (final m in members) {
            final email = m['email'] ?? '';
            final name = m['name'] ?? email.split('@').first;
            final isYou = email == currentEmail;
            payerItems.add(DropdownMenuItem(
              value: email,
              child: Text(
                isYou ? '$name (You)' : name,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: isYou ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ));
          }
          // Ensure selectedPayer is valid
          if (!members.any((m) => m['email'] == selectedPayer)) {
            selectedPayer = currentEmail;
          }
        }

        final isForgiving = !youOwe;
        final dialogTitle = isForgiving ? 'FORGIVE DEBT' : 'SETTLE UP';
        final amountLabel = isForgiving ? 'AMOUNT TO FORGIVE' : 'AMOUNT';
        final payerLabel = isForgiving ? 'WHO\'S FORGIVING' : 'WHO\'S PAYING';
        final methodLabel = isForgiving ? 'REASON' : 'METHOD OF PAYMENT';
        final confirmLabel = isForgiving ? 'FORGIVE' : 'SETTLE';

        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            dialogTitle,
            style: const TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: AppColors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // â”€â”€ AMOUNT â”€â”€
                Text(
                  amountLabel,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 12,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // —— WHO'S PAYING / FORGIVING ——
                Text(
                  payerLabel,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                if (isForgiving)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${user.displayName ?? currentEmail.split('@').first} (You)',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppColors.accent,
                      ),
                    ),
                  )
                else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPayer,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppColors.accent,
                      ),
                      items: payerItems,
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedPayer = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // â"€â"€ WHO ARE YOU PAYING â"€â"€
                if (!isForgiving) ...[
                  const Text(
                    'WHO ARE YOU PAYING',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      () {
                        final payee = selectedPayer == currentEmail ? partnerEmail : currentEmail;
                        for (final m in members) {
                          if (m['email'] == payee) return m['name'] ?? payee.split('@').first;
                        }
                        return payee.split('@').first;
                      }(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // â”€â”€ PAYMENT METHOD â”€â”€
                Text(
                  methodLabel,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMethod,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppColors.accent,
                      ),
                      items: (isForgiving ? _forgiveReasons : _paymentMethods).map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m, style: const TextStyle(fontFamily: 'monospace', color: AppColors.textPrimary)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedMethod = val);
                      },
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
                'CANCEL',
                style: TextStyle(fontFamily: 'monospace', color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) return;
                Navigator.pop(ctx);

                await billService.settleUp(
                  groupId: groupId,
                  from: isForgiving
                      ? () {
                          // Derive partner email from members
                          final partner = members
                              .map((m) => m['email'] ?? '')
                              .where((e) => e.isNotEmpty && e != currentEmail)
                              .firstOrNull ?? partnerEmail;
                          return partner;
                        }()
                      : selectedPayer,
                  to: isForgiving
                      ? currentEmail
                      : (selectedPayer == currentEmail ? partnerEmail : currentEmail),
                  amount: amount,
                  paymentMethod: selectedMethod,
                );

                // Save preferred payment method
                _savePreferredPaymentMethod(user.uid, selectedMethod);

                onSettled?.call();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.surface,
                      content: Text(
                        isForgiving
                            ? 'Forgave \$${amount.toStringAsFixed(2)}'
                            : 'Settled \$${amount.toStringAsFixed(2)} via $selectedMethod',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
