// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../models/group.dart';
import '../constants/theme_constants.dart';
import 'group_avatar.dart';

class GroupDrawer extends StatelessWidget {
  final BillService billService;
  final String? selectedGroupId;
  final bool reorderMode;
  final List<String> groupOrder;
  final VoidCallback onEditUsername;
  final VoidCallback onCreateGroup;
  final VoidCallback onToggleReorderMode;
  final void Function(List<String> newOrder) onReorder;
  final void Function(String groupId) onGroupSelected;
  final void Function(Group group) onGroupLongPress;
  final Future<void> Function() onRefreshInvites;
  final VoidCallback onFeedback;
  final VoidCallback onLogout;
  final VoidCallback onAbout;

  const GroupDrawer({
    super.key,
    required this.billService,
    required this.selectedGroupId,
    required this.reorderMode,
    required this.groupOrder,
    required this.onEditUsername,
    required this.onCreateGroup,
    required this.onToggleReorderMode,
    required this.onReorder,
    required this.onGroupSelected,
    required this.onGroupLongPress,
    required this.onRefreshInvites,
    required this.onFeedback,
    required this.onLogout,
    required this.onAbout,
  });

  List<Group> _sortedGroups(List<Group> groups) {
    if (groupOrder.isEmpty) return groups;
    final ordered = <Group>[];
    for (final id in groupOrder) {
      final match = groups.where((g) => g.id == id);
      if (match.isNotEmpty) ordered.add(match.first);
    }
    for (final g in groups) {
      if (!groupOrder.contains(g.id)) ordered.add(g);
    }
    return ordered;
  }

  Widget _buildGroupBalanceWidget(String groupId, String email) {
    return StreamBuilder<double>(
      stream: billService.getGroupBalanceStream(groupId, email),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.abs() < 0.01) {
          return const SizedBox.shrink();
        }
        final balance = snapshot.data!;
        final youOwe = balance > 0;
        final color = youOwe ? const Color(0xFFEF5350) : const Color(0xFF66BB6A);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${youOwe ? '-' : '+'}\$${balance.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    final userEmail = user?.email?.toLowerCase() ?? '';

    return Drawer(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          // Account Info Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar â€” tappable to edit username
                GestureDetector(
                  onTap: onEditUsername,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                    child: user?.photoURL != null
                        ? Image.network(user!.photoURL!, fit: BoxFit.cover)
                        : const Icon(Icons.person, color: AppColors.accent, size: 32),
                  ),
                ),
                const SizedBox(height: 14),
                // Show username from Firestore (live)
                StreamBuilder<DocumentSnapshot>(
                  stream: context.read<AuthService>().userDocStream,
                  builder: (context, snap) {
                    String displayName = (user?.displayName ?? 'USER').toUpperCase();
                    if (snap.hasData && snap.data!.exists) {
                      final data = snap.data!.data() as Map<String, dynamic>?;
                      final username = data?['username'] as String?;
                      if (username != null && username.isNotEmpty) {
                        displayName = username.toUpperCase();
                      }
                    }
                    return Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppColors.textPrimary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Groups Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Text(
                  'GROUPS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                if (!reorderMode)
                  GestureDetector(
                    onTap: onCreateGroup,
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: AppColors.accent, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'NEW',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!reorderMode) const SizedBox(width: 12),
                GestureDetector(
                  onTap: onToggleReorderMode,
                  child: Row(
                    children: [
                      Icon(
                        reorderMode ? Icons.check : Icons.swap_vert,
                        color: reorderMode ? AppColors.accent : AppColors.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        reorderMode ? 'DONE' : 'SORT',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: reorderMode ? AppColors.accent : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pull-to-refresh hint
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_downward, color: AppColors.textDim, size: 12),
                SizedBox(width: 6),
                Text(
                  'PULL TO CHECK INVITES',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    letterSpacing: 1,
                    color: AppColors.textDim,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_downward, color: AppColors.textDim, size: 12),
              ],
            ),
          ),

          // Groups List
          Expanded(
            child: user == null
                ? const SizedBox.shrink()
                : StreamBuilder<List<Group>>(
                    stream: billService.getUserGroupsStream(user.email!.toLowerCase()),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        );
                      }

                      final groups = snapshot.data ?? [];

                      if (groups.isEmpty) {
                        return const Center(
                          child: Text(
                            'NO GROUPS',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppColors.textDim,
                            ),
                          ),
                        );
                      }

                      final sortedGroups = _sortedGroups(groups);

                      if (reorderMode) {
                        return ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: sortedGroups.length,
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              color: AppColors.surface,
                              elevation: 4,
                              child: child,
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex--;
                            final reordered = List<Group>.from(sortedGroups);
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, item);
                            onReorder(reordered.map((g) => g.id).toList());
                          },
                          itemBuilder: (context, index) {
                            final group = sortedGroups[index];
                            final accent = groupColor(group.color);
                            return Container(
                              key: ValueKey(group.id),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1117),
                                border: Border(
                                  left: BorderSide(color: accent, width: 3),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: buildGroupAvatar(
                                  group.customImage,
                                  group.icon,
                                  accent,
                                  20,
                                ),
                                title: Text(
                                  group.name.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    color: accent,
                                  ),
                                ),
                                subtitle: Text(
                                  '${group.members.length} member${group.members.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: AppColors.textDim,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildGroupBalanceWidget(group.id, userEmail),
                                    const SizedBox(width: 4),
                                    Icon(Icons.drag_handle, color: accent.withValues(alpha: 0.5), size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }

                      return RefreshIndicator(
                        color: AppColors.accent,
                        backgroundColor: AppColors.surface,
                        onRefresh: onRefreshInvites,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: sortedGroups.length,
                          itemBuilder: (context, index) {
                            final group = sortedGroups[index];
                            final isSelected = group.id == selectedGroupId;
                            final accent = groupColor(group.color);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accent.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected
                                        ? accent
                                        : accent.withValues(alpha: 0.3),
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: buildGroupAvatar(
                                  group.customImage,
                                  group.icon,
                                  accent,
                                  20,
                                ),
                                title: Text(
                                  group.name.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    color: isSelected
                                        ? accent
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${group.members.length} member${group.members.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: AppColors.textDim,
                                  ),
                                ),
                                trailing: _buildGroupBalanceWidget(group.id, userEmail),
                                onTap: () {
                                  onGroupSelected(group.id);
                                  Navigator.pop(context);
                                },
                                onLongPress: () {
                                  Navigator.pop(context); // close drawer
                                  onGroupLongPress(group);
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Section
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.feedback_outlined, color: AppColors.accent, size: 20),
                  title: const Text(
                    'SEND FEEDBACK',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: AppColors.accent,
                    ),
                  ),
                  onTap: onFeedback,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.textMuted, size: 20),
                  title: const Text(
                    'SIGN OUT',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  onTap: onLogout,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GestureDetector(
              onTap: onAbout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.textDim, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'ABOUT THIS APP',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 1,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
