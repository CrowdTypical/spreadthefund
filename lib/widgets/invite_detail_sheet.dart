// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/theme_constants.dart';
import '../services/bill_service.dart';

void showInviteDetailSheet({
  required BuildContext context,
  required Map<String, dynamic> invite,
  required BillService billService,
  required String userEmail,
}) {
  final inviteId = invite['id'] as String;
  final groupId = invite['groupId'] as String;
  final groupName = invite['groupName'] as String? ?? 'Group';
  final inviterName = invite['inviterName'] as String? ?? 'Someone';
  final inviterEmail = invite['inviterEmail'] as String? ?? '';
  final createdAt = invite['createdAt'] as Timestamp?;
  final dateStr = createdAt != null
      ? DateFormat('MMM d, yyyy · h:mm a').format(createdAt.toDate())
      : 'Unknown';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.group_add, color: Color(0xFFFFB74D), size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'GROUP INVITATION',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Group name
              _buildDetailRow('GROUP', groupName.toUpperCase()),
              const SizedBox(height: 14),

              // Inviter name
              _buildDetailRow('INVITED BY', inviterName),
              const SizedBox(height: 14),

              // Inviter email
              if (inviterEmail.isNotEmpty) ...[
                _buildDetailRow('EMAIL', inviterEmail),
                const SizedBox(height: 14),
              ],

              // Date
              _buildDetailRow('SENT', dateStr),

              const SizedBox(height: 24),

              // Accept / Decline buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        billService.acceptInvite(inviteId);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, color: AppColors.accent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ACCEPT',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        billService.declineInvite(inviteId, groupId, userEmail);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350).withValues(alpha: 0.1),
                          border: Border.all(
                              color: const Color(0xFFEF5350).withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, color: Color(0xFFEF5350), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'DECLINE',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Color(0xFFEF5350),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildDetailRow(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          color: AppColors.textMuted,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}
