// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../models/group.dart';
import '../constants/theme_constants.dart';
import 'group_avatar.dart';
import 'invite_detail_sheet.dart';

class GroupDrawer extends StatefulWidget {
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

  @override
  State<GroupDrawer> createState() => _GroupDrawerState();
}

class _GroupDrawerState extends State<GroupDrawer>
    with SingleTickerProviderStateMixin {
  bool _pendingExpanded = false;

  List<Group> _sortedGroups(List<Group> groups) {
    if (widget.groupOrder.isEmpty) return groups;
    final ordered = <Group>[];
    for (final id in widget.groupOrder) {
      final match = groups.where((g) => g.id == id);
      if (match.isNotEmpty) ordered.add(match.first);
    }
    for (final g in groups) {
      if (!widget.groupOrder.contains(g.id)) ordered.add(g);
    }
    return ordered;
  }

  Widget _buildUnseenDot(String groupId, String? uid) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: widget.billService.hasUnseenActivity(groupId, uid),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildGroupBalanceWidget(String groupId, String email) {
    return StreamBuilder<double>(
      stream: widget.billService.getGroupBalanceStream(groupId, email),
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

  Widget _buildInviteAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSentInviteDetail(
      BuildContext context, Map<String, dynamic> invite, Group group) {
    final inviteeEmail = invite['inviteeEmail'] as String? ?? '';
    final createdAt = invite['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('MMM d, yyyy · h:mm a').format(createdAt.toDate())
        : 'Unknown';
    final accent = groupColor(group.color);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: Color(0xFFFFB74D), width: 2),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        color: Color(0xFFFFB74D), size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'PENDING INVITE',
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
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sentDetailRow('GROUP', group.name.toUpperCase()),
                const SizedBox(height: 14),
                _sentDetailRow('SENT TO', inviteeEmail),
                const SizedBox(height: 14),
                _sentDetailRow('SENT', dateStr),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFFFB74D).withValues(alpha: 0.15),
                        border: Border.all(
                            color: const Color(0xFFFFB74D)
                                .withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule,
                              color: Color(0xFFFFB74D), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'AWAITING RESPONSE',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: Color(0xFFFFB74D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // close drawer
                    widget.onGroupLongPress(group);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: accent.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'VIEW GROUP DETAILS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sentDetailRow(String label, String value) {
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
                // Avatar — tappable to edit username
                GestureDetector(
                  onTap: widget.onEditUsername,
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

          // Pending invites section (only visible when invites exist)
          if (user != null)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.billService
                  .getReceivedPendingInvitesStream(user.email!.toLowerCase()),
              builder: (context, receivedSnap) {
                final pendingInvites = receivedSnap.data ?? [];
                if (pendingInvites.isEmpty) {
                  // Reset expanded state when invites are cleared
                  if (_pendingExpanded) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _pendingExpanded = false);
                    });
                  }
                  return const SizedBox.shrink();
                }

                // Build a map of groupId → invite for later
                final invitesByGroup = <String, Map<String, dynamic>>{};
                for (final inv in pendingInvites) {
                  invitesByGroup[inv['groupId'] as String] = inv;
                }

                return Column(
                  children: [
                    // Tappable header bar
                    GestureDetector(
                      onTap: () =>
                          setState(() => _pendingExpanded = !_pendingExpanded),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A1F2E),
                          border: Border(
                            bottom:
                                BorderSide(color: AppColors.border, width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFB74D),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'NEW GROUP REQUEST${pendingInvites.length > 1 ? 'S' : ''}!',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: Color(0xFFFFB74D),
                                ),
                              ),
                            ),
                            Text(
                              '${pendingInvites.length}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFB74D),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedRotation(
                              turns: _pendingExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFFFFB74D),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable invite cards
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF111722),
                          border: Border(
                            bottom:
                                BorderSide(color: AppColors.border, width: 1),
                          ),
                        ),
                        child: Column(
                          children: pendingInvites.map((invite) {
                            final groupName =
                                invite['groupName'] as String? ?? 'Group';
                            final inviterName =
                                invite['inviterName'] as String? ?? 'Someone';
                            final inviteId = invite['id'] as String;
                            final inviteGroupId =
                                invite['groupId'] as String;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: GestureDetector(
                                onTap: () {
                                  showInviteDetailSheet(
                                    context: context,
                                    invite: invite,
                                    billService: widget.billService,
                                    userEmail: userEmail,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border.all(
                                      color: const Color(0xFFFFB74D)
                                          .withValues(alpha: 0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.group_add,
                                            color: Color(0xFFFFB74D),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text.rich(
                                              TextSpan(
                                                style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textMuted,
                                                ),
                                                children: [
                                                  const TextSpan(
                                                      text:
                                                          'New Invitation to '),
                                                  TextSpan(
                                                    text:
                                                        '"$groupName"',
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .textPrimary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const TextSpan(
                                                      text: ' by '),
                                                  TextSpan(
                                                    text:
                                                        '"$inviterName"',
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .textPrimary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: AppColors.textDim,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildInviteAction(
                                              label: 'ACCEPT',
                                              icon: Icons.check,
                                              color: AppColors.accent,
                                              onTap: () {
                                                widget.billService
                                                    .acceptInvite(
                                                        inviteId);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildInviteAction(
                                              label: 'DECLINE',
                                              icon: Icons.close,
                                              color: const Color(
                                                  0xFFEF5350),
                                              onTap: () {
                                                widget.billService
                                                    .declineInvite(
                                                  inviteId,
                                                  inviteGroupId,
                                                  userEmail,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      crossFadeState: _pendingExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                    ),
                  ],
                );
              },
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
                if (!widget.reorderMode)
                  GestureDetector(
                    onTap: widget.onCreateGroup,
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
                if (!widget.reorderMode) const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onToggleReorderMode,
                  child: Row(
                    children: [
                      Icon(
                        widget.reorderMode ? Icons.check : Icons.swap_vert,
                        color: widget.reorderMode
                            ? AppColors.accent
                            : AppColors.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.reorderMode ? 'DONE' : 'SORT',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: widget.reorderMode
                              ? AppColors.accent
                              : AppColors.textMuted,
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
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: widget.billService
                        .getReceivedPendingInvitesStream(
                            user.email!.toLowerCase()),
                    builder: (context, receivedSnap) {
                      // Groups with pending received invites are hidden from main list
                      final pendingGroupIds = <String>{};
                      for (final inv in receivedSnap.data ?? []) {
                        pendingGroupIds.add(inv['groupId'] as String);
                      }

                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: widget.billService
                            .getSentPendingInvitesStream(user.uid),
                        builder: (context, sentSnap) {
                          final sentByGroup =
                              <String, Map<String, dynamic>>{};
                          for (final inv in sentSnap.data ?? []) {
                            sentByGroup[inv['groupId'] as String] = inv;
                          }

                          return StreamBuilder<List<Group>>(
                            stream: widget.billService.getUserGroupsStream(
                                user.email!.toLowerCase()),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accent,
                                  ),
                                );
                              }

                              final allGroups = snapshot.data ?? [];
                              // Filter out groups with pending received invites
                              final groups = allGroups
                                  .where((g) =>
                                      !pendingGroupIds.contains(g.id))
                                  .toList();

                              if (groups.isEmpty && pendingGroupIds.isEmpty) {
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

                              if (widget.reorderMode) {
                                return ReorderableListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  itemCount: sortedGroups.length,
                                  proxyDecorator:
                                      (child, index, animation) {
                                    return Material(
                                      color: AppColors.surface,
                                      elevation: 4,
                                      child: child,
                                    );
                                  },
                                  onReorder: (oldIndex, newIndex) {
                                    if (newIndex > oldIndex) newIndex--;
                                    final reordered =
                                        List<Group>.from(sortedGroups);
                                    final item =
                                        reordered.removeAt(oldIndex);
                                    reordered.insert(newIndex, item);
                                    widget.onReorder(reordered
                                        .map((g) => g.id)
                                        .toList());
                                  },
                                  itemBuilder: (context, index) {
                                    final group = sortedGroups[index];
                                    final accent =
                                        groupColor(group.color);
                                    return Container(
                                      key: ValueKey(group.id),
                                      margin: const EdgeInsets.only(
                                          bottom: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D1117),
                                        border: Border(
                                          left: BorderSide(
                                              color: accent, width: 3),
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
                                            _buildGroupBalanceWidget(
                                                group.id, userEmail),
                                            const SizedBox(width: 4),
                                            Icon(Icons.drag_handle,
                                                color: accent.withValues(
                                                    alpha: 0.5),
                                                size: 20),
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
                                onRefresh: widget.onRefreshInvites,
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  itemCount: sortedGroups.length,
                                  itemBuilder: (context, index) {
                                    final group = sortedGroups[index];
                                    final isSelected = group.id ==
                                        widget.selectedGroupId;
                                    final accent =
                                        groupColor(group.color);
                                    final sentInvite =
                                        sentByGroup[group.id];

                                    // Always show member count as subtitle
                                    final subtitleWidget = Text(
                                      '${group.members.length} member${group.members.length != 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                        color: AppColors.textDim,
                                      ),
                                    );

                                    return Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accent.withValues(
                                                alpha: 0.1)
                                            : Colors.transparent,
                                        border: Border(
                                          left: BorderSide(
                                            color: isSelected
                                                ? accent
                                                : accent.withValues(
                                                    alpha: 0.3),
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
                                        subtitle: subtitleWidget,
                                        trailing: Wrap(
                                          spacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            _buildGroupBalanceWidget(
                                                group.id, userEmail),
                                            _buildUnseenDot(
                                                group.id, user.uid),
                                            if (sentInvite != null)
                                              const Icon(
                                                Icons.schedule,
                                                color:
                                                    Color(0xFFFFB74D),
                                                size: 16,
                                              ),
                                          ],
                                        ),
                                        onTap: () {
                                          widget.onGroupSelected(
                                              group.id);
                                          Navigator.pop(context);
                                        },
                                        onLongPress: () {
                                          if (sentInvite != null) {
                                            _showSentInviteDetail(
                                                context, sentInvite, group);
                                          } else {
                                            Navigator.pop(context);
                                            widget.onGroupLongPress(group);
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
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
                  leading: const Icon(Icons.feedback_outlined,
                      color: AppColors.accent, size: 20),
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
                  onTap: widget.onFeedback,
                ),
                ListTile(
                  leading: const Icon(Icons.logout,
                      color: AppColors.textMuted, size: 20),
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
                  onTap: widget.onLogout,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GestureDetector(
              onTap: widget.onAbout,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.textDim, size: 14),
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
