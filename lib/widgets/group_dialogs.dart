// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../models/group.dart';
import 'change_appearance_dialog.dart';
import '../constants/theme_constants.dart';

void showEditUsernameDialog(BuildContext context) {
  final controller = TextEditingController();
  final authService = context.read<AuthService>();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: const Text(
        'SET USERNAME',
        style: TextStyle(
          fontFamily: 'monospace',
          letterSpacing: 2,
          color: AppColors.textPrimary,
        ),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 50,
        style: const TextStyle(
          fontFamily: 'monospace',
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          hintText: 'Enter username',
          hintStyle: TextStyle(
            fontFamily: 'monospace',
            color: AppColors.textDim,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
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
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            final success = await authService.updateUsername(name);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surface,
                  content: Text(
                    success ? 'Username updated!' : 'Error updating username',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: success
                          ? AppColors.accent
                          : AppColors.danger,
                    ),
                  ),
                ),
              );
            }
          },
          child: const Text(
            'SAVE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    ),
  );
}

void showGroupOptionsDialog(
  BuildContext context, {
  required String groupId,
  required BillService billService,
  required void Function(String? newGroupId) onGroupChanged,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: const Text(
        'GROUP OPTIONS',
        style: TextStyle(
          fontFamily: 'monospace',
          letterSpacing: 2,
          color: AppColors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.palette, color: AppColors.accent, size: 20),
            title: const Text(
              'CHANGE APPEARANCE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                letterSpacing: 1,
                color: AppColors.textPrimary,
              ),
            ),
            onTap: () {
              Navigator.pop(ctx);
              showChangeAppearanceDialog(context, groupId: groupId, billService: billService);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: AppColors.accent, size: 20),
            title: const Text(
              'RENAME GROUP',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                letterSpacing: 1,
                color: AppColors.textPrimary,
              ),
            ),
            onTap: () {
              Navigator.pop(ctx);
              showRenameGroupDialog(context, groupId: groupId, billService: billService);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: AppColors.danger, size: 20),
            title: const Text(
              'DELETE GROUP',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                letterSpacing: 1,
                color: AppColors.danger,
              ),
            ),
            onTap: () {
              Navigator.pop(ctx);
              showDeleteGroupConfirmation(
                context,
                targetGroupId: groupId,
                name: null,
                billService: billService,
                currentGroupId: groupId,
                onGroupChanged: onGroupChanged,
              );
            },
          ),
        ],
      ),
    ),
  );
}

void showDeleteGroupConfirmation(
  BuildContext context, {
  required String targetGroupId,
  required String? name,
  required BillService billService,
  required String? currentGroupId,
  required void Function(String? newGroupId) onGroupChanged,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: const Text(
        'DELETE GROUP?',
        style: TextStyle(
          fontFamily: 'monospace',
          letterSpacing: 1,
          color: AppColors.danger,
        ),
      ),
      content: Text(
        name != null
            ? 'This will permanently delete "$name" and all its bills and settlements.'
            : 'This will permanently delete this group and all its bills and settlements.',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppColors.textMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
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
            Navigator.pop(ctx);
            final success = await billService.deleteGroup(targetGroupId);
            if (!context.mounted) return;
            if (success) {
              if (currentGroupId == targetGroupId) {
              final user = context.read<AuthService>().currentUser;
                if (user != null) {
                  final groups = await billService.getUserGroupsStream(user.email!.toLowerCase()).first;
                  onGroupChanged(groups.isNotEmpty ? groups.first.id : null);
                }
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.surface,
                  content: Text(
                    'Group deleted',
                    style: TextStyle(fontFamily: 'monospace', color: AppColors.accent),
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.surface,
                  content: Text(
                    'Error deleting group',
                    style: TextStyle(fontFamily: 'monospace', color: AppColors.danger),
                  ),
                ),
              );
            }
          },
          child: const Text(
            'DELETE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: AppColors.danger,
            ),
          ),
        ),
      ],
    ),
  );
}

void showRenameGroupDialog(
  BuildContext context, {
  required String groupId,
  required BillService billService,
}) {
  final nameController = TextEditingController();
  final user = context.read<AuthService>().currentUser;
  if (user == null) return;

  showDialog(
    context: context,
    builder: (ctx) {
      return StreamBuilder<List<Group>>(
        stream: billService.getUserGroupsStream(user.email!.toLowerCase()),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? [];
          final currentGroup = groups.where((g) => g.id == groupId).toList();
          if (currentGroup.isNotEmpty && nameController.text.isEmpty) {
            nameController.text = currentGroup.first.name;
          }
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: const Text(
              'RENAME GROUP',
              style: TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 2,
                color: AppColors.textPrimary,
              ),
            ),
            content: TextField(
              controller: nameController,
              autofocus: true,
              maxLength: 50,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'New group name',
                hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.textDim,
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
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);
                  await billService.renameGroup(groupId, name);
                },
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void showGroupLimitDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: const Text(
        'GROUP LIMIT REACHED',
        style: TextStyle(
          fontFamily: 'monospace',
          letterSpacing: 2,
          color: Color(0xFFFFA726),
        ),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Groups are currently limited to 2 members.',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Want more? Press below to automatically submit feedback and let us know!',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'CLOSE',
            style: TextStyle(fontFamily: 'monospace', color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            _submitGroupLimitFeedback(context);
          },
          child: const Text(
            'SUBMIT FEEDBACK',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _submitGroupLimitFeedback(BuildContext context) async {
  final user = context.read<AuthService>().currentUser;
  try {
    await FirebaseFirestore.instance.collection('feedback').add({
      'type': 'feature_request',
      'title': 'More than 2 members per group',
      'message': 'I would like to have more than 2 members per group.',
      'userEmail': user?.email ?? 'unknown',
      'userId': user?.uid ?? 'unknown',
      'submittedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Feedback submitted \u2014 thank you!',
            style: TextStyle(fontFamily: 'monospace', color: AppColors.accent),
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Failed to submit feedback. Please try again.',
            style: TextStyle(fontFamily: 'monospace', color: AppColors.danger),
          ),
        ),
      );
    }
  }
}
