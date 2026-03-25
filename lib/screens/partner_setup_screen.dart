import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/bill_service.dart';
import '../services/email_service.dart';

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
    _billService = BillService();
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
                border: Border.all(color: const Color(0xFF00E5CC), width: 1),
              ),
              child: const Icon(
                Icons.person_add,
                size: 48,
                color: Color(0xFF00E5CC),
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
                color: Color(0xFFE0E0E0),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter their email to start splitting bills',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF8899AA),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE0E0E0)),
              decoration: InputDecoration(
                labelText: 'EMAIL',
                labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1, color: Color(0xFF8899AA)),
                hintText: 'partner@example.com',
                hintStyle: const TextStyle(fontFamily: 'monospace', color: Color(0xFF455566)),
                prefixIcon: const Icon(Icons.email, color: Color(0xFF8899AA)),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF1E2A35)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF00E5CC)),
                ),
                errorBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFFFF4C5E)),
                ),
                filled: true,
                fillColor: const Color(0xFF141A22),
                errorText: _errorMessage,
                errorStyle: const TextStyle(fontFamily: 'monospace', color: Color(0xFFFF4C5E)),
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
                  side: const BorderSide(color: Color(0xFF00E5CC)),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5CC)),
                      )
                    : const Text(
                        'INVITE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Color(0xFF00E5CC),
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

    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser!;
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
        // Get the group name for the invite
        groupName = 'Spread the Fund Group';
      } else {
        // Create a new group first
        final newGroupId = await _billService.createNamedGroup(
          currentUser.uid,
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

      // Check if they already have an account — if so, add them directly
      final existingUid = await _billService.getUserIdByEmail(email);
      if (existingUid != null) {
        await _billService.addMemberToGroup(targetGroupId, existingUid);
      }

      // Always store a pending invite (so they auto-join if they sign in later)
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
            backgroundColor: const Color(0xFF141A22),
            content: Text(
              emailSent
                  ? 'Invite email sent to $email!'
                  : 'Invite saved! ${EmailService.isConfigured ? "Email failed to send." : "Configure email credentials to send notifications."}',
              style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5CC)),
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
