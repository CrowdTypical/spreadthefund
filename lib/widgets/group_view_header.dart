// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../models/group.dart';
import '../constants/theme_constants.dart';
import 'group_avatar.dart';

class GroupViewHeader extends StatelessWidget {
  final String groupId;
  final BillService billService;
  final VoidCallback onGroupOptions;
  final VoidCallback onInvitePartner;

  const GroupViewHeader({
    super.key,
    required this.groupId,
    required this.billService,
    required this.onGroupOptions,
    required this.onInvitePartner,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<Group>>(
      stream: billService.getUserGroupsStream(user.email!.toLowerCase()),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? [];
        final current = groups.where((g) => g.id == groupId).toList();
        final name = current.isNotEmpty ? current.first.name : '';
        final accent = current.isNotEmpty ? groupColor(current.first.color) : AppColors.accent;
        final iconKey = current.isNotEmpty ? current.first.icon : 'group';
        final customImage = current.isNotEmpty ? current.first.customImage : null;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: accent.withValues(alpha: 0.3)),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: accent,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onGroupOptions,
                    child: buildGroupAvatar(customImage, iconKey, accent, 28),
                  ),
                  GestureDetector(
                    onTap: onInvitePartner,
                    child: Icon(Icons.person_add, color: accent, size: 22),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
