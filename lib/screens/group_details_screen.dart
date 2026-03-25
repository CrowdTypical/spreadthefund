import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/bill_service.dart';
import '../models/group.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final BillService _billService = BillService();
  List<Map<String, String>> _members = [];
  Group? _group;
  bool _loading = true;
  bool _showMeta = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
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
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'RENAME GROUP',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 2,
            color: Color(0xFFE0E0E0),
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFFE0E0E0),
          ),
          decoration: const InputDecoration(
            hintText: 'New group name',
            hintStyle: TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFF556677),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFF1E2A35)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(0xFF00E5CC)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontFamily: 'monospace', color: Color(0xFF8899AA)),
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
                color: Color(0xFF00E5CC),
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
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'REMOVE MEMBER?',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 1,
            color: Color(0xFFFF4C5E),
          ),
        ),
        content: Text(
          'Remove "$name" from this group?',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFF8899AA),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontFamily: 'monospace', color: Color(0xFF8899AA)),
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
                    backgroundColor: const Color(0xFF141A22),
                    content: Text(
                      success ? 'Member removed' : 'Failed to remove member',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: success
                            ? const Color(0xFF00E5CC)
                            : const Color(0xFFFF4C5E),
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
                color: Color(0xFFFF4C5E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'DELETE GROUP?',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 1,
            color: Color(0xFFFF4C5E),
          ),
        ),
        content: Text(
          'This will permanently delete "${_group?.name ?? 'this group'}" and all its bills and settlements.',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFF8899AA),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontFamily: 'monospace', color: Color(0xFF8899AA)),
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
                color: Color(0xFFFF4C5E),
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
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00E5CC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'GROUP DETAILS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Color(0xFFE0E0E0),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5CC)),
            )
          : _group == null
              ? const Center(
                  child: Text(
                    'GROUP NOT FOUND',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF8899AA),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── GROUP NAME ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141A22),
                        border: Border.all(color: const Color(0xFF1E2A35)),
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
                              color: Color(0xFF556677),
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
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── MEMBERS ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141A22),
                        border: Border.all(color: const Color(0xFF1E2A35)),
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
                              color: Color(0xFF556677),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._members.map((m) {
                            final isOwner = m['uid'] == _group!.createdBy;
                            final currentUser = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
                            final isSelf = m['email']?.toLowerCase() == currentUser;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.person, color: Color(0xFF00E5CC), size: 18),
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
                                            color: Color(0xFFE0E0E0),
                                          ),
                                        ),
                                        if (m['email']!.isNotEmpty &&
                                            m['email'] != m['name'])
                                          Text(
                                            m['email']!,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 10,
                                              color: Color(0xFF556677),
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
                                            color: const Color(0xFF00E5CC)
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: const Text(
                                        'OWNER',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9,
                                          letterSpacing: 1,
                                          color: Color(0xFF00E5CC),
                                        ),
                                      ),
                                    ),
                                  if (!isOwner && !isSelf)
                                    IconButton(
                                      icon: const Icon(Icons.person_remove,
                                          color: Color(0xFFFF4C5E), size: 18),
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

                    // ── DEBUG / METADATA ──
                    GestureDetector(
                      onTap: () => setState(() => _showMeta = !_showMeta),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141A22),
                          border: Border.all(color: const Color(0xFF1E2A35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bug_report,
                                color: Color(0xFF556677), size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'DEBUG / METADATA',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                letterSpacing: 1,
                                color: Color(0xFF556677),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _showMeta
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: const Color(0xFF556677),
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
                          border: Border.all(color: const Color(0xFF1E2A35)),
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
                                    color: Color(0xFF556677),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.groupId,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Color(0xFF00E5CC),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Color(0xFF8899AA), size: 14),
                                  tooltip: 'Copy ID',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: widget.groupId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFF141A22),
                                        content: Text(
                                          'Group ID copied',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: Color(0xFF00E5CC),
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
                                color: Color(0xFF556677),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'CREATED AT  ${_group!.createdAt.toIso8601String()}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Color(0xFF556677),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── ACTIONS ──
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
                          foregroundColor: const Color(0xFF00E5CC),
                          side: const BorderSide(color: Color(0xFF00E5CC)),
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
                          foregroundColor: const Color(0xFFFF4C5E),
                          side: const BorderSide(color: Color(0xFFFF4C5E)),
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
