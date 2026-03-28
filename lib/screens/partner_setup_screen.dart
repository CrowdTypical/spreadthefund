// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../services/email_service.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';

class PartnerSetupScreen extends StatefulWidget {
  final Function(String) onGroupCreated;
  final String? groupId;

  const PartnerSetupScreen({Key? key, required this.onGroupCreated, this.groupId}) : super(key: key);

  @override
  State<PartnerSetupScreen> createState() => _PartnerSetupScreenState();
}

class _PartnerSetupScreenState extends State<PartnerSetupScreen> {
  final _emailController = TextEditingController();
  late BillService _billService;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _billService = context.read<BillService>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('INVITE PARTNER'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 1),
              ),
              child: const Icon(
                Icons.person_add,
                size: 48,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ADD A PARTNER',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter their email to start splitting bills',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              maxLength: 254,
              style: const TextStyle(fontFamily: 'monospace', color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'EMAIL',
                labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1, color: AppColors.textMuted),
                hintText: 'partner@example.com',
                hintStyle: const TextStyle(fontFamily: 'monospace', color: Color(0xFF455566)),
                prefixIcon: const Icon(Icons.email, color: AppColors.textMuted),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.accent),
                ),
                errorBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.danger),
                ),
                filled: true,
                fillColor: AppColors.surface,
                errorText: _errorMessage,
                errorStyle: const TextStyle(fontFamily: 'monospace', color: AppColors.danger),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.accent),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      )
                    : const Text(
                        'INVITE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppColors.accent,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter an email');
      return;
    }

    if (!isValidEmail(email)) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return;
    }

    final currentUser = context.read<AuthService>().currentUser!;
    if (email.toLowerCase() == currentUser.email?.toLowerCase()) {
      setState(() => _errorMessage = 'You cannot invite yourself');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String targetGroupId;
      String groupName;

      if (widget.groupId != null) {
        targetGroupId = widget.groupId!;
        // Check member limit before proceeding
        final groupDoc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(targetGroupId)
            .get();
        final members = (groupDoc.data()?['members'] as List?) ?? [];
        if (members.length >= BillService.maxGroupMembers) {
          setState(() => _errorMessage = 'This group already has ${BillService.maxGroupMembers} members');
          return;
        }
        // Get the group name for the invite
        groupName = 'Spread the Funds Group';
      } else {
        // Create a new group first
        final newGroupId = await _billService.createNamedGroup(
          currentUser.email!.toLowerCase(),
          'Shared Group',
        );
        if (newGroupId == null) {
          setState(() => _errorMessage = 'Failed to create group');
          return;
        }
        targetGroupId = newGroupId;
        groupName = 'Shared Group';
        widget.onGroupCreated(newGroupId);
      }

      // Always add by email â€” no UID lookup needed
      await _billService.addMemberToGroup(
        targetGroupId,
        email.toLowerCase(),
      );

      // Always store a pending invite (tracks the invitation)
      await _billService.createInvite(
        groupId: targetGroupId,
        groupName: groupName,
        inviterUid: currentUser.uid,
        inviterName: currentUser.displayName ?? 'Someone',
        inviteeEmail: email,
      );

      // Send the invite email silently
      final emailSent = await EmailService.sendInviteEmail(
        toEmail: email,
        inviterName: currentUser.displayName ?? 'Someone',
        groupName: groupName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              emailSent
                  ? 'Invite email sent to $email!'
                  : 'Invite saved! Email failed to send.',
              style: const TextStyle(fontFamily: 'monospace', color: AppColors.accent),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
