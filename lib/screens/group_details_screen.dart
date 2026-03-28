// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../constants/theme_constants.dart';
import '../models/group.dart';
import '../widgets/image_crop_dialog.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late final BillService _billService;
  List<Map<String, String>> _members = [];
  Group? _group;
  bool _loading = true;
  bool _showMeta = false;

  @override
  void initState() {
    super.initState();
    _billService = context.read<BillService>();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final groups = await _billService.getUserGroupsStream(user.email!.toLowerCase()).first;
    final match = groups.where((g) => g.id == widget.groupId).toList();
    final members = await _billService.getGroupMembers(widget.groupId);

    if (mounted) {
      setState(() {
        _group = match.isNotEmpty ? match.first : null;
        _members = members;
        _loading = false;
      });
    }
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _group?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          controller: controller,
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
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _billService.renameGroup(widget.groupId, name);
              _loadData();
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

  void _showRemoveMemberDialog(Map<String, String> member) {
    final name = member['name'] ?? member['email'] ?? 'this member';
    final email = member['email'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'REMOVE MEMBER?',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 1,
            color: AppColors.danger,
          ),
        ),
        content: Text(
          'Remove "$name" from this group?',
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
              style: TextStyle(fontFamily: 'monospace', color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _billService.removeMemberFromGroup(
                widget.groupId,
                email,
              );
              if (success) {
                _loadData();
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surface,
                    content: Text(
                      success ? 'Member removed' : 'Failed to remove member',
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
              'REMOVE',
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

  IconData _groupIcon(String key) => groupIcons[key] ?? Icons.group;
  Color _groupColor(String hex) => groupColors[hex] ?? AppColors.accent;

  void _showAppearanceDialog() {
    if (_group == null) return;
    var selectedIcon = _group!.icon;
    var selectedColor = _group!.color;
    String? pendingImage = _group!.customImage;
    Uint8List? pendingImageBytes;
    var clearImage = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final accent = _groupColor(selectedColor);
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: const Text(
              'CHANGE APPEARANCE',
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
                                    Icon(_groupIcon(selectedIcon), color: accent, size: 24),
                              )
                            : pendingImage != null && pendingImage!.isNotEmpty
                              ? buildImagePreview(pendingImage!, selectedIcon, accent)
                              : Icon(_groupIcon(selectedIcon), color: accent, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final result = await pickAndCropImage(context, accent);
                                if (result != null) {
                                  setDialogState(() {
                                    pendingImageBytes = result;
                                    clearImage = false;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: accent),
                                ),
                                child: Text(
                                  pendingImage != null && pendingImage!.isNotEmpty && !clearImage || pendingImageBytes != null
                                      ? 'CHANGE IMAGE'
                                      : 'UPLOAD IMAGE',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    letterSpacing: 1,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                            if ((pendingImage != null && pendingImage!.isNotEmpty && !clearImage) || pendingImageBytes != null) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => setDialogState(() {
                                  pendingImage = null;
                                  pendingImageBytes = null;
                                  clearImage = true;
                                }),
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
                  Navigator.pop(ctx);
                  String? imageUrl;
                  if (pendingImageBytes != null) {
                    imageUrl = await _billService.uploadGroupImage(widget.groupId, context.read<AuthService>().currentUser!.uid, pendingImageBytes!);
                  }
                  final success = await _billService.updateGroupAppearance(
                    widget.groupId,
                    icon: selectedIcon,
                    color: selectedColor,
                    customImage: pendingImageBytes != null ? imageUrl : (pendingImage != null && !clearImage) ? pendingImage : null,
                    clearImage: clearImage,
                  );
                  if (mounted && success) {
                    _loadData(); // Refresh to show changes
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surface,
                        content: Text(
                          success ? 'Appearance updated' : 'Error updating appearance',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: success ? AppColors.accent : AppColors.danger,
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

  void _showDeleteConfirmation() {
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
          'This will permanently delete "${_group?.name ?? 'this group'}" and all its bills and settlements.',
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
              style: TextStyle(fontFamily: 'monospace', color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _billService.deleteGroup(widget.groupId);
              if (mounted) {
                Navigator.pop(context, success ? 'deleted' : null);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'GROUP DETAILS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _group == null
              ? const Center(
                  child: Text(
                    'GROUP NOT FOUND',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // â”€â”€ GROUP NAME â”€â”€
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NAME',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 2,
                              color: AppColors.textDim,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _group!.name.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // â”€â”€ MEMBERS â”€â”€
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MEMBERS (${_members.length})',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 2,
                              color: AppColors.textDim,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._members.map((m) {
                            final isOwner = m['email'] == _group!.createdBy;
                            final currentUser = context.read<AuthService>().currentUser?.email?.toLowerCase();
                            final isSelf = m['email']?.toLowerCase() == currentUser;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.person, color: AppColors.accent, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['name']!.toUpperCase(),
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (m['email']!.isNotEmpty &&
                                            m['email'] != m['name'])
                                          Text(
                                            m['email']!,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 10,
                                              color: AppColors.textDim,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: AppColors.accent
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: const Text(
                                        'OWNER',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9,
                                          letterSpacing: 1,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  if (!isOwner && !isSelf)
                                    IconButton(
                                      icon: const Icon(Icons.person_remove,
                                          color: AppColors.danger, size: 18),
                                      tooltip: 'Remove member',
                                      onPressed: () => _showRemoveMemberDialog(m),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // â”€â”€ DEBUG / METADATA â”€â”€
                    GestureDetector(
                      onTap: () => setState(() => _showMeta = !_showMeta),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bug_report,
                                color: AppColors.textDim, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'DEBUG / METADATA',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                letterSpacing: 1,
                                color: AppColors.textDim,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _showMeta
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: AppColors.textDim,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showMeta)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'GROUP ID  ',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    color: AppColors.textDim,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.groupId,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: AppColors.textMuted, size: 14),
                                  tooltip: 'Copy ID',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: widget.groupId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AppColors.surface,
                                        content: Text(
                                          'Group ID copied',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'CREATED BY  ${_group!.createdBy}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: AppColors.textDim,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'CREATED AT  ${_group!.createdAt.toIso8601String()}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // â”€â”€ ACTIONS â”€â”€
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showAppearanceDialog,
                        icon: const Icon(Icons.palette, size: 18),
                        label: const Text(
                          'CHANGE APPEARANCE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showRenameDialog,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text(
                          'RENAME GROUP',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showDeleteConfirmation,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text(
                          'DELETE GROUP',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
