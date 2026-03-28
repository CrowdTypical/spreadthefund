// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../constants/theme_constants.dart';
import 'image_crop_dialog.dart';

void showCreateGroupDialog(
  BuildContext context, {
  required BillService billService,
  required void Function(String newGroupId) onGroupCreated,
}) {
  final nameController = TextEditingController();
  String selectedIcon = 'group';
  String selectedColor = '00E5CC';
  Uint8List? pendingImageBytes;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final accent = groupColor(selectedColor);
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text(
            'NEW GROUP',
            style: TextStyle(
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
                TextField(
                  controller: nameController,
                  autofocus: true,
                  maxLength: 50,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Group name',
                    hintStyle: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.textDim,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // â”€â”€ Group image â”€â”€
                const Text(
                  'GROUP IMAGE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: pendingImageBytes != null
                          ? Image.memory(
                              pendingImageBytes!,
                              fit: BoxFit.cover,
                              width: 48,
                              height: 48,
                              errorBuilder: (_, __, ___) =>
                                  Icon(groupIcon(selectedIcon), color: accent, size: 24),
                            )
                          : Icon(groupIcon(selectedIcon), color: accent, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final result = await pickAndCropImage(ctx, accent);
                              if (result != null) {
                                setDialogState(() {
                                  pendingImageBytes = result;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: accent),
                              ),
                              child: Text(
                                pendingImageBytes != null ? 'CHANGE IMAGE' : 'UPLOAD IMAGE',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  letterSpacing: 1,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                          if (pendingImageBytes != null) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => setDialogState(() => pendingImageBytes = null),
                              child: const Text(
                                'REMOVE',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  letterSpacing: 1,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'ICON',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Used when no image is set',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: AppColors.textDim,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: groupIcons.entries.map((e) {
                    final isSel = e.key == selectedIcon;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = e.key),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSel ? accent.withValues(alpha: 0.15) : Colors.transparent,
                          border: Border.all(
                            color: isSel ? accent : AppColors.border,
                          ),
                        ),
                        child: Icon(e.value, color: isSel ? accent : AppColors.textDim, size: 18),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'COLOR',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: groupColors.entries.map((e) {
                    final isSel = e.key == selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = e.key),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: e.value.withValues(alpha: 0.25),
                          border: Border.all(
                            color: isSel ? Colors.white : e.value.withValues(alpha: 0.4),
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: isSel
                            ? Icon(Icons.check, color: e.value, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
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
                  color: AppColors.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                final user = context.read<AuthService>().currentUser;
                if (user != null) {
                  final newId = await billService.createNamedGroup(
                    user.email!.toLowerCase(),
                    name,
                    icon: selectedIcon,
                    color: selectedColor,
                  );
                  if (newId != null) {
                    if (pendingImageBytes != null) {
                      final url = await billService.uploadGroupImage(newId, user.uid, pendingImageBytes!);
                      if (url != null) {
                        await billService.updateGroupAppearance(newId, customImage: url);
                      }
                    }
                    onGroupCreated(newId);
                  }
                }
              },
              child: Text(
                'CREATE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
