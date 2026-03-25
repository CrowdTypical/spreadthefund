import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../models/bill.dart';
import '../models/group.dart';
import 'add_bill_screen.dart';
import 'partner_setup_screen.dart';

const _categoryIcons = <String, IconData>{
  'food': Icons.restaurant,
  'transport': Icons.directions_car,
  'groceries': Icons.shopping_cart,
  'entertainment': Icons.movie,
  'utilities': Icons.bolt,
  'rent': Icons.home,
  'shopping': Icons.shopping_bag,
  'health': Icons.medical_services,
};

IconData _iconForCategory(String name) {
  return _categoryIcons[name.toLowerCase()] ?? Icons.receipt_long;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late BillService billService;
  String? groupId;
  bool groupChecked = false;

  @override
  void initState() {
    super.initState();
    billService = BillService();
    _checkGroup();
  }

  Future<void> _checkGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final groups = await billService.getUserGroupsStream(user.uid).first;
      if (groups.isNotEmpty) {
        setState(() {
          groupId = groups.first.id;
          groupChecked = true;
        });
      } else {
        // Auto-create a personal group so the app is immediately usable
        final newId = await billService.createPersonalGroup(user.uid);
        setState(() {
          groupId = newId;
          groupChecked = true;
        });
      }
    }
  }

  void _invitePartner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerSetupScreen(
          groupId: groupId,
          onGroupCreated: (newGroupId) {
            setState(() => groupId = newGroupId);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!groupChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SPREAD THE FUND'),
        actions: [
          if (groupId != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF00E5CC), size: 20),
              tooltip: 'Group Options',
              onPressed: _showGroupOptionsDialog,
            ),
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF00E5CC)),
            tooltip: 'Invite Partner',
            onPressed: _invitePartner,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: groupId == null ? _buildEmptyBillsView() : _buildGroupView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Ensure a group exists before adding a bill
          if (groupId == null) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final newId = await billService.createPersonalGroup(user.uid);
              if (newId != null) {
                setState(() => groupId = newId);
              }
            }
          }
          if (groupId != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddBillScreen(groupId: groupId!),
              ),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: const Color(0xFF0A0E14),
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
              color: Color(0xFF141A22),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E2A35), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar — tappable to edit username
                GestureDetector(
                  onTap: () => _showEditUsernameDialog(),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00E5CC), width: 2),
                    ),
                    child: user?.photoURL != null
                        ? Image.network(user!.photoURL!, fit: BoxFit.cover)
                        : const Icon(Icons.person, color: Color(0xFF00E5CC), size: 32),
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
                        color: Color(0xFFE0E0E0),
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
                    color: Color(0xFF8899AA),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'UID: ${user?.uid.substring(0, 12) ?? ''}...',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFF556677),
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
                    color: Color(0xFF8899AA),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showCreateGroupDialog,
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Color(0xFF00E5CC), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'NEW',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Color(0xFF00E5CC),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Groups List
          Expanded(
            child: user == null
                ? const SizedBox.shrink()
                : StreamBuilder<List<Group>>(
                    stream: billService.getUserGroupsStream(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00E5CC),
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
                              color: Color(0xFF556677),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final isSelected = group.id == groupId;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00E5CC).withOpacity(0.1)
                                  : Colors.transparent,
                              border: Border(
                                left: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF00E5CC)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                group.members.length > 1
                                    ? Icons.group
                                    : Icons.person,
                                color: isSelected
                                    ? const Color(0xFF00E5CC)
                                    : const Color(0xFF8899AA),
                                size: 20,
                              ),
                              title: Text(
                                group.name.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: isSelected
                                      ? const Color(0xFF00E5CC)
                                      : const Color(0xFFE0E0E0),
                                ),
                              ),
                              subtitle: Text(
                                '${group.members.length} member${group.members.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: Color(0xFF556677),
                                ),
                              ),
                              onTap: () {
                                setState(() => groupId = group.id);
                                Navigator.pop(context);
                              },
                              onLongPress: () {
                                _showDeleteGroupConfirmation(group.id, group.name);
                              },
                            ),
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
                top: BorderSide(color: Color(0xFF1E2A35), width: 1),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh, color: Color(0xFF00E5CC), size: 20),
                  title: const Text(
                    'CHECK FOR INVITES',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF00E5CC),
                    ),
                  ),
                  onTap: _checkForInvites,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF8899AA), size: 20),
                  title: const Text(
                    'SIGN OUT',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF8899AA),
                    ),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  void _showEditUsernameDialog() {
    final controller = TextEditingController();
    final authService = context.read<AuthService>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'SET USERNAME',
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
            hintText: 'Enter username',
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
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF8899AA),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final success = await authService.updateUsername(name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF141A22),
                    content: Text(
                      success ? 'Username updated!' : 'Error updating username',
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

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'NEW GROUP',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 2,
            color: Color(0xFFE0E0E0),
          ),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFFE0E0E0),
          ),
          decoration: const InputDecoration(
            hintText: 'Group name',
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
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF8899AA),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final newId = await billService.createNamedGroup(user.uid, name);
                if (newId != null && mounted) {
                  setState(() => groupId = newId);
                }
              }
            },
            child: const Text(
              'CREATE',
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

  void _showGroupOptionsDialog() {
    if (groupId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'GROUP OPTIONS',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 2,
            color: Color(0xFFE0E0E0),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF00E5CC), size: 20),
              title: const Text(
                'RENAME GROUP',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  letterSpacing: 1,
                  color: Color(0xFFE0E0E0),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameGroupDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFFF4C5E), size: 20),
              title: const Text(
                'DELETE GROUP',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  letterSpacing: 1,
                  color: Color(0xFFFF4C5E),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteGroupConfirmation(groupId!, null);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteGroupConfirmation(String targetGroupId, String? name) {
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
          name != null
              ? 'This will permanently delete "$name" and all its bills and settlements.'
              : 'This will permanently delete this group and all its bills and settlements.',
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
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF8899AA),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await billService.deleteGroup(targetGroupId);
              if (mounted) {
                if (success) {
                  // If the deleted group was the active one, switch away
                  if (groupId == targetGroupId) {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final groups = await billService.getUserGroupsStream(user.uid).first;
                      setState(() {
                        groupId = groups.isNotEmpty ? groups.first.id : null;
                      });
                    }
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF141A22),
                      content: Text(
                        'Group deleted',
                        style: TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5CC)),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF141A22),
                      content: Text(
                        'Error deleting group',
                        style: TextStyle(fontFamily: 'monospace', color: Color(0xFFFF4C5E)),
                      ),
                    ),
                  );
                }
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

  void _showRenameGroupDialog() {
    final nameController = TextEditingController();
    // Pre-fill with current group name by reading from stream
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || groupId == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StreamBuilder<List<Group>>(
          stream: billService.getUserGroupsStream(user.uid),
          builder: (context, snapshot) {
            final groups = snapshot.data ?? [];
            final currentGroup = groups.where((g) => g.id == groupId).toList();
            if (currentGroup.isNotEmpty && nameController.text.isEmpty) {
              nameController.text = currentGroup.first.name;
            }
            return AlertDialog(
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
                controller: nameController,
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
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx);
                    await billService.renameGroup(groupId!, name);
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
            );
          },
        );
      },
    );
  }

  void _showSettleUpDialog(double suggestedAmount) {
    final amountController = TextEditingController(
      text: suggestedAmount.toStringAsFixed(2),
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || groupId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'SETTLE UP',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 2,
            color: Color(0xFFE0E0E0),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AMOUNT',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 2,
                color: Color(0xFF8899AA),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5CC),
              ),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                prefixStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E5CC),
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
          ],
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
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) return;
              Navigator.pop(ctx);
              // Record the settlement — "from" is the person who owes, "to" is the person owed
              await billService.settleUp(
                groupId: groupId!,
                from: user.uid,
                to: 'partner', // generic target since it's a 2-person split
                amount: amount,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF141A22),
                    content: Text(
                      'Settled \$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF00E5CC),
                      ),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'SETTLE',
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

  Widget _buildGroupView() {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group name banner
        if (user != null)
          StreamBuilder<List<Group>>(
            stream: billService.getUserGroupsStream(user.uid),
            builder: (context, snapshot) {
              final groups = snapshot.data ?? [];
              final current = groups.where((g) => g.id == groupId).toList();
              final name = current.isNotEmpty ? current.first.name : '';
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF141A22),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF1E2A35)),
                  ),
                ),
                child: Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Color(0xFF00E5CC),
                  ),
                ),
              );
            },
          ),
        Expanded(child: _buildBillsList()),
      ],
    );
  }

  Widget _buildEmptyBillsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1E2A35)),
            ),
            child: const Icon(Icons.receipt_long, size: 48, color: Color(0xFF8899AA)),
          ),
          const SizedBox(height: 24),
          const Text(
            'NO BILLS YET',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Color(0xFFE0E0E0),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to add a bill',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF8899AA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsList() {
    return StreamBuilder<List<Bill>>(
      stream: billService.getBillsStream(groupId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00E5CC)),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final bills = snapshot.data ?? [];

        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1E2A35)),
                  ),
                  child: const Icon(Icons.receipt_long, size: 48, color: Color(0xFF8899AA)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'NO BILLS YET',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Color(0xFFE0E0E0),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap + to add your first bill',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF8899AA),
                  ),
                ),
              ],
            ),
          );
        }

        // Nest a settlement stream so the balance updates in real time
        return StreamBuilder<QuerySnapshot>(
          stream: billService.getSettlementsStream(groupId!),
          builder: (context, settleSnap) {
            final currentUser = FirebaseAuth.instance.currentUser!.uid;
            double totalYouOwe = 0;
            double totalTheyOwe = 0;

            for (var bill in bills) {
              final splitAmount = bill.amount / 2;
              if (bill.paidBy == currentUser) {
                totalTheyOwe += splitAmount;
              } else {
                totalYouOwe += splitAmount;
              }
            }

            // Subtract settlements from the balance
            double totalSettled = 0;
            if (settleSnap.hasData) {
              for (var doc in settleSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                totalSettled += (data['amount'] as num?)?.toDouble() ?? 0;
              }
            }

            // Reduce the owed amount by settlements
            final rawDifference = totalYouOwe - totalTheyOwe;
            final double adjustedDifference = rawDifference > 0
                ? (rawDifference - totalSettled).clamp(0.0, double.infinity)
                : (rawDifference + totalSettled).clamp(double.negativeInfinity, 0.0);

            // Build a merged chronological list of bills + settlements
            final List<Map<String, dynamic>> timeline = [];

            for (final bill in bills) {
              timeline.add({'type': 'bill', 'data': bill, 'date': bill.createdAt});
            }

            final settlementsForTimeline = <Map<String, dynamic>>[];
            if (settleSnap.hasData) {
              for (final doc in settleSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final settledAt = data['settledAt'] as Timestamp?;
                final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                final from = data['from'] as String? ?? '';
                settlementsForTimeline.add({
                  'type': 'settlement',
                  'amount': amount,
                  'from': from,
                  'date': settledAt?.toDate() ?? DateTime.now(),
                });
              }
            }
            timeline.addAll(settlementsForTimeline);

            // Sort newest first
            timeline.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

            // Walk chronologically (oldest first) to compute running balance at each settlement
            double runningOwed = 0;
            double runningSettled = 0;
            final chronological = List<Map<String, dynamic>>.from(timeline.reversed);
            for (final item in chronological) {
              if (item['type'] == 'bill') {
                final bill = item['data'] as Bill;
                final split = bill.amount / 2;
                if (bill.paidBy == currentUser) {
                  runningOwed -= split; // they owe you
                } else {
                  runningOwed += split; // you owe them
                }
              } else {
                runningSettled += item['amount'] as double;
                final remaining = (runningOwed.abs() - runningSettled).clamp(0.0, double.infinity);
                item['remainingAtTime'] = remaining;
              }
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildBalanceCard(adjustedDifference > 0 ? adjustedDifference : 0.0,
                    adjustedDifference < 0 ? adjustedDifference.abs() : 0.0),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    'ACTIVITY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF8899AA),
                    ),
                  ),
                ),
                ...timeline.map((item) {
                  if (item['type'] == 'bill') {
                    return _buildBillTile(item['data'] as Bill, billService);
                  } else {
                    return _buildSettlementTile(
                      amount: item['amount'] as double,
                      from: item['from'] as String,
                      date: item['date'] as DateTime,
                      remainingBalance: (item['remainingAtTime'] as double?) ?? 0.0,
                    );
                  }
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceCard(double youOwe, double theyOwe) {
    final difference = youOwe - theyOwe;
    final bool hasBalance = difference.abs() >= 0.01;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        border: Border.all(color: const Color(0xFF1E2A35)),
      ),
      child: Column(
        children: [
          const Text(
            'BALANCE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: Color(0xFF8899AA),
            ),
          ),
          const SizedBox(height: 12),
          if (!hasBalance)
            const Text(
              'SETTLED UP',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5CC),
              ),
            )
          else if (difference > 0)
            Column(
              children: [
                const Text(
                  'YOU OWE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Color(0xFF8899AA),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '\$${difference.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF4C5E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showSettleUpDialog(difference),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF00E5CC)),
                        ),
                        child: const Text(
                          'SETTLE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: Color(0xFF00E5CC),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Column(
              children: [
                const Text(
                  'THEY OWE YOU',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Color(0xFF8899AA),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '\$${difference.abs().toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5CC),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showSettleUpDialog(difference.abs()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF00E5CC)),
                        ),
                        child: const Text(
                          'SETTLE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: Color(0xFF00E5CC),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBillTile(Bill bill, BillService service) {
    final currentUser = FirebaseAuth.instance.currentUser!.uid;
    final isYourBill = bill.paidBy == currentUser;
    final accentColor = isYourBill ? const Color(0xFF00E5CC) : const Color(0xFFFF4C5E);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
      ),
      child: InkWell(
        onLongPress: () => _showDeleteOption(bill, service),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Icon(
                _iconForCategory(bill.category.isNotEmpty ? bill.category : bill.description),
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Name + who paid
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.description.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE0E0E0),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isYourBill ? 'You paid' : 'They paid',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF8899AA),
                    ),
                  ),
                  if (bill.notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      bill.notes,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Color(0xFF667788),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Amount + date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${bill.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, h:mm a').format(bill.createdAt),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFF556677),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementTile({
    required double amount,
    required String from,
    required DateTime date,
    required double remainingBalance,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser!.uid;
    final isYou = from == currentUser;
    final who = isYou ? 'You' : 'They';

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A12),
        border: Border(
          left: BorderSide(color: const Color(0xFF4CAF50), width: 3),
        ),
      ),
      child: Row(
        children: [
          // Settlement icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.handshake,
              color: Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Settlement text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$who SETTLED UP',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  remainingBalance > 0.01
                      ? '\$${remainingBalance.toStringAsFixed(2)} remaining'
                      : 'All settled!',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: remainingBalance > 0.01
                        ? const Color(0xFFFF4C5E)
                        : const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
          // Amount + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, h:mm a').format(date),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Color(0xFF556677),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteOption(Bill bill, BillService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'DELETE BILL?',
          style: TextStyle(fontFamily: 'monospace', letterSpacing: 1, color: Color(0xFFE0E0E0)),
        ),
        content: Text(
          '${bill.description} — \$${bill.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF8899AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await service.deleteBill(groupId!, bill.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bill deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForInvites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    Navigator.pop(context); // close the drawer

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF141A22),
        content: Text(
          'Checking for invites...',
          style: TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5CC)),
        ),
        duration: Duration(seconds: 1),
      ),
    );

    await billService.processPendingInvites(user.uid, user.email!);

    // Refresh groups
    if (mounted) {
      final groups = await billService.getUserGroupsStream(user.uid).first;
      if (groups.isNotEmpty) {
        setState(() => groupId = groups.first.id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF141A22),
          content: Text(
            'Found ${groups.length} group(s)',
            style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5CC)),
          ),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final authService = context.read<AuthService>();
    await authService.signOut();
  }
}
