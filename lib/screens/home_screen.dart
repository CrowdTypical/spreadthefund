import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../models/bill.dart';
import '../models/group.dart';
import 'add_bill_screen.dart';
import 'bill_detail_screen.dart';
import 'group_details_screen.dart';
import 'partner_setup_screen.dart';

const String appVersion = 'v1.0.3';
const String releasesUrl = 'https://github.com/CrowdTypical/spreadthefund/releases';

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

// ── Group icon palette ──
const _groupIcons = <String, IconData>{
  'group': Icons.group,
  'person': Icons.person,
  'home': Icons.home,
  'favorite': Icons.favorite,
  'star': Icons.star,
  'rocket': Icons.rocket_launch,
  'pet': Icons.pets,
  'music': Icons.music_note,
  'game': Icons.sports_esports,
  'travel': Icons.flight,
  'food': Icons.restaurant,
  'coffee': Icons.coffee,
  'fitness': Icons.fitness_center,
  'school': Icons.school,
  'work': Icons.work,
  'beach': Icons.beach_access,
  'fire': Icons.local_fire_department,
  'diamond': Icons.diamond,
  'bolt': Icons.bolt,
  'palette': Icons.palette,
  'camera': Icons.camera_alt,
  'cake': Icons.cake,
  'car': Icons.directions_car,
  'bike': Icons.pedal_bike,
};

IconData _groupIcon(String key) {
  return _groupIcons[key] ?? Icons.group;
}

// ── Group accent colors (dark-theme friendly) ──
const _groupColors = <String, Color>{
  '00E5CC': Color(0xFF00E5CC), // teal (default)
  'FF6B9D': Color(0xFFFF6B9D), // pink
  '7B68EE': Color(0xFF7B68EE), // purple
  'FFA726': Color(0xFFFFA726), // amber
  '42A5F5': Color(0xFF42A5F5), // blue
  'EF5350': Color(0xFFEF5350), // red
  '66BB6A': Color(0xFF66BB6A), // green
  'FFEE58': Color(0xFFFFEE58), // yellow
  'AB47BC': Color(0xFFAB47BC), // violet
  'FF7043': Color(0xFFFF7043), // deep orange
  '26C6DA': Color(0xFF26C6DA), // cyan
  'EC407A': Color(0xFFEC407A), // rose
};

Color _groupColor(String hex) {
  return _groupColors[hex] ?? const Color(0xFF00E5CC);
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
  bool _reorderMode = false;
  List<String> _groupOrder = [];

  @override
  void initState() {
    super.initState();
    billService = BillService();
    _checkGroup();
    _checkForUpdate();
    _loadGroupOrder();
  }

  Future<void> _checkGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Process any pending invites every time the app starts (not just on sign-in),
      // since Firebase caches auth state across sessions.
      if (user.email != null) {
        // Migrate any old UID-based memberships to email
        await billService.migrateUidToEmail(user.uid, user.email!);
        await billService.processPendingInvites(user.email!);
      }

      final email = user.email!.toLowerCase();
      final groups = await billService.getUserGroupsStream(email).first;
      if (groups.isNotEmpty) {
        // Prefer a shared group (>1 member) over a solo personal group
        final sharedGroups = groups.where((g) => g.members.length > 1).toList();
        final selected = sharedGroups.isNotEmpty ? sharedGroups.first : groups.first;
        setState(() {
          groupId = selected.id;
          groupChecked = true;
        });
      } else {
        // Auto-create a personal group so the app is immediately usable
        final newId = await billService.createPersonalGroup(email);
        setState(() {
          groupId = newId;
          groupChecked = true;
        });
      }
    }
  }

  Future<void> _loadGroupOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final order = data?['groupOrder'] as List<dynamic>?;
        if (order != null) {
          setState(() => _groupOrder = order.cast<String>());
        }
      }
    } catch (_) {}
  }

  Future<void> _saveGroupOrder(List<String> order) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'groupOrder': order});
  }

  List<Group> _sortedGroups(List<Group> groups) {
    if (_groupOrder.isEmpty) return groups;
    final ordered = <Group>[];
    for (final id in _groupOrder) {
      final match = groups.where((g) => g.id == id);
      if (match.isNotEmpty) ordered.add(match.first);
    }
    // Append any groups not in the saved order
    for (final g in groups) {
      if (!_groupOrder.contains(g.id)) ordered.add(g);
    }
    return ordered;
  }

  /// Returns true if [remote] is a newer semver than [local].
  /// Strips leading 'v' or 'v.' prefixes before comparing.
  bool _isNewerVersion(String remote, String local) {
    List<int> parse(String v) {
      final cleaned = v.replaceFirst(RegExp(r'^v\.?'), '');
      return cleaned.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    }
    final r = parse(remote);
    final l = parse(local);
    final len = r.length > l.length ? r.length : l.length;
    for (int i = 0; i < len; i++) {
      final rp = i < r.length ? r[i] : 0;
      final lp = i < l.length ? l[i] : 0;
      if (rp > lp) return true;
      if (rp < lp) return false;
    }
    return false;
  }

  Future<void> _checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/CrowdTypical/spreadthefund/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestTag = data['tag_name'] as String?;
        if (latestTag != null && _isNewerVersion(latestTag, appVersion) && mounted) {
          _showUpdateDialog(latestTag);
        }
      }
    } catch (_) {
      // Silently fail — don't block the app if the check fails
    }
  }

  void _showUpdateDialog(String latestVersion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'UPDATE AVAILABLE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Color(0xFF00E5CC),
          ),
        ),
        content: Text(
          'A new version ($latestVersion) is available.\n\nYou are on $appVersion.',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFFE0E0E0),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'LATER',
              style: TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 1,
                color: Color(0xFF8899AA),
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openReleasesPage();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00E5CC)),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: const Text(
              'UPDATE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Color(0xFF00E5CC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReleasesPage() async {
    await launchUrl(Uri.parse(releasesUrl), mode: LaunchMode.externalApplication);
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
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E14),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/app_icon_transparent.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E5CC),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'assets/app_icon_transparent.png',
          width: 32,
          height: 32,
        ),
      ),
      drawer: _buildDrawer(),
      body: groupId == null ? _buildEmptyBillsView() : _buildGroupView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Ensure a group exists before adding a bill
          if (groupId == null) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final newId = await billService.createPersonalGroup(user.email!.toLowerCase());
              if (newId != null) {
                setState(() => groupId = newId);
              }
            }
          }
          if (groupId != null && context.mounted) {
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
                if (!_reorderMode)
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
                if (!_reorderMode) const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() {
                    _reorderMode = !_reorderMode;
                  }),
                  child: Row(
                    children: [
                      Icon(
                        _reorderMode ? Icons.check : Icons.swap_vert,
                        color: _reorderMode ? const Color(0xFF00E5CC) : const Color(0xFF8899AA),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _reorderMode ? 'DONE' : 'SORT',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: _reorderMode ? const Color(0xFF00E5CC) : const Color(0xFF8899AA),
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
                Icon(Icons.arrow_downward, color: Color(0xFF556677), size: 12),
                SizedBox(width: 6),
                Text(
                  'PULL TO CHECK INVITES',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    letterSpacing: 1,
                    color: Color(0xFF556677),
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_downward, color: Color(0xFF556677), size: 12),
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

                      final sortedGroups = _sortedGroups(groups);

                      if (_reorderMode) {
                        return ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: sortedGroups.length,
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              color: const Color(0xFF141A22),
                              elevation: 4,
                              child: child,
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex--;
                            setState(() {
                              final item = sortedGroups.removeAt(oldIndex);
                              sortedGroups.insert(newIndex, item);
                              _groupOrder = sortedGroups.map((g) => g.id).toList();
                            });
                            _saveGroupOrder(_groupOrder);
                          },
                          itemBuilder: (context, index) {
                            final group = sortedGroups[index];
                            final accent = _groupColor(group.color);
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
                                leading: _buildGroupAvatar(
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
                                    color: Color(0xFF556677),
                                  ),
                                ),
                                trailing: Icon(Icons.drag_handle, color: accent.withValues(alpha: 0.5), size: 20),
                              ),
                            );
                          },
                        );
                      }

                      return RefreshIndicator(
                        color: const Color(0xFF00E5CC),
                        backgroundColor: const Color(0xFF141A22),
                        onRefresh: _refreshInvites,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: sortedGroups.length,
                          itemBuilder: (context, index) {
                            final group = sortedGroups[index];
                            final isSelected = group.id == groupId;
                            final accent = _groupColor(group.color);
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
                                leading: _buildGroupAvatar(
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
                                onLongPress: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  Navigator.pop(context); // close drawer
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GroupDetailsScreen(groupId: group.id),
                                    ),
                                  );
                                  if (result == 'deleted' && mounted) {
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user != null) {
                                      final groups = await billService.getUserGroupsStream(user.email!.toLowerCase()).first;
                                      setState(() {
                                        groupId = groups.isNotEmpty ? groups.first.id : null;
                                      });
                                    }
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFF141A22),
                                        content: Text(
                                          'Group deleted',
                                          style: TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5CC)),
                                        ),
                                      ),
                                    );
                                  }
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
                top: BorderSide(color: Color(0xFF1E2A35), width: 1),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.feedback_outlined, color: Color(0xFF00E5CC), size: 20),
                  title: const Text(
                    'SEND FEEDBACK',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF00E5CC),
                    ),
                  ),
                  onTap: _showFeedbackDialog,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GestureDetector(
              onTap: _showAboutApp,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF556677), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'ABOUT THIS APP',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 1,
                        color: Color(0xFF556677),
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
    String selectedIcon = 'group';
    String selectedColor = '00E5CC';
    String? pendingImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final accent = _groupColor(selectedColor);
          return AlertDialog(
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFFE0E0E0),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Group name',
                      hintStyle: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF556677),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: Color(0xFF1E2A35)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Group image ──
                  const Text(
                    'GROUP IMAGE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      letterSpacing: 2,
                      color: Color(0xFF8899AA),
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
                          child: pendingImage != null && pendingImage!.isNotEmpty
                            ? Image.memory(
                                Uint8List.fromList(base64Decode(pendingImage!)),
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                                errorBuilder: (_, __, ___) =>
                                    Icon(_groupIcon(selectedIcon), color: accent, size: 24),
                              )
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
                                final result = await _pickAndCropImage(accent);
                                if (result != null) {
                                  setDialogState(() {
                                    pendingImage = result;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: accent),
                                ),
                                child: Text(
                                  pendingImage != null ? 'CHANGE IMAGE' : 'UPLOAD IMAGE',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    letterSpacing: 1,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                            if (pendingImage != null) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => setDialogState(() => pendingImage = null),
                                child: const Text(
                                  'REMOVE',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    color: Color(0xFFFF4C5E),
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
                      color: Color(0xFF8899AA),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Used when no image is set',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: Color(0xFF556677),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _groupIcons.entries.map((e) {
                      final isSel = e.key == selectedIcon;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = e.key),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSel ? accent.withValues(alpha: 0.15) : Colors.transparent,
                            border: Border.all(
                              color: isSel ? accent : const Color(0xFF1E2A35),
                            ),
                          ),
                          child: Icon(e.value, color: isSel ? accent : const Color(0xFF556677), size: 18),
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
                      color: Color(0xFF8899AA),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _groupColors.entries.map((e) {
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
                    final newId = await billService.createNamedGroup(
                      user.email!.toLowerCase(),
                      name,
                      icon: selectedIcon,
                      color: selectedColor,
                    );
                    if (newId != null) {
                      if (pendingImage != null) {
                        await billService.updateGroupAppearance(newId, customImage: pendingImage);
                      }
                      if (mounted) {
                        setState(() => groupId = newId);
                      }
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
              leading: const Icon(Icons.palette, color: Color(0xFF00E5CC), size: 20),
              title: const Text(
                'CHANGE APPEARANCE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  letterSpacing: 1,
                  color: Color(0xFFE0E0E0),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showChangeAppearanceDialog();
              },
            ),
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

  void _showChangeAppearanceDialog() async {
    if (groupId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final groups = await billService.getUserGroupsStream(user.email!.toLowerCase()).first;
    final current = groups.where((g) => g.id == groupId).toList();
    if (current.isEmpty) return;

    var selectedIcon = current.first.icon;
    var selectedColor = current.first.color;
    String? pendingImage = current.first.customImage;
    var clearImage = false;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final accent = _groupColor(selectedColor);
          return AlertDialog(
            backgroundColor: const Color(0xFF141A22),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: const Text(
              'CHANGE APPEARANCE',
              style: TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 2,
                color: Color(0xFFE0E0E0),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Custom image section ──
                  const Text(
                    'GROUP IMAGE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      letterSpacing: 2,
                      color: Color(0xFF8899AA),
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
                          child: pendingImage != null && pendingImage!.isNotEmpty
                            ? Image.memory(
                                Uint8List.fromList(base64Decode(pendingImage!)),
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                                errorBuilder: (_, __, ___) =>
                                    Icon(_groupIcon(selectedIcon), color: accent, size: 24),
                              )
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
                                final result = await _pickAndCropImage(accent);
                                if (result != null) {
                                  setDialogState(() {
                                    pendingImage = result;
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
                                  pendingImage != null && pendingImage!.isNotEmpty
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
                            if (pendingImage != null && pendingImage!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => setDialogState(() {
                                  pendingImage = null;
                                  clearImage = true;
                                }),
                                child: const Text(
                                  'REMOVE',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    color: Color(0xFFFF4C5E),
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
                  // ── Icon section ──
                  const Text(
                    'ICON',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      letterSpacing: 2,
                      color: Color(0xFF8899AA),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Used when no image is set',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: Color(0xFF556677),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _groupIcons.entries.map((e) {
                      final isSel = e.key == selectedIcon;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = e.key),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSel ? accent.withValues(alpha: 0.15) : Colors.transparent,
                            border: Border.all(
                              color: isSel ? accent : const Color(0xFF1E2A35),
                            ),
                          ),
                          child: Icon(e.value, color: isSel ? accent : const Color(0xFF556677), size: 18),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // ── Color section ──
                  const Text(
                    'COLOR',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      letterSpacing: 2,
                      color: Color(0xFF8899AA),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _groupColors.entries.map((e) {
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
                    color: Color(0xFF8899AA),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final success = await billService.updateGroupAppearance(
                    groupId!,
                    icon: selectedIcon,
                    color: selectedColor,
                    customImage: (pendingImage != null && !clearImage) ? pendingImage : null,
                    clearImage: clearImage,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF141A22),
                        content: Text(
                          success ? 'Appearance updated' : 'Error updating appearance',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: success ? const Color(0xFF00E5CC) : const Color(0xFFFF4C5E),
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
                    color: Color(0xFF00E5CC),
                  ),
                ),
              ),
            ],
          );
        },
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
              if (!mounted) return;
              if (success) {
                // If the deleted group was the active one, switch away
                if (groupId == targetGroupId) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final groups = await billService.getUserGroupsStream(user.email!.toLowerCase()).first;
                    setState(() {
                      groupId = groups.isNotEmpty ? groups.first.id : null;
                    });
                  }
                }
                if (!mounted) return;
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
          stream: billService.getUserGroupsStream(user.email!.toLowerCase()),
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
                from: user.email!.toLowerCase(),
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

  Future<String?> _pickAndCropImage(Color accent) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final base64Str = base64Encode(bytes);

    if (!mounted) return null;

    String? result;
    await showDialog(
      context: context,
      builder: (ctx) {
        final transformController = TransformationController();
        return AlertDialog(
          backgroundColor: const Color(0xFF0D1117),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'CROP IMAGE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: accent,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pinch to zoom, drag to move',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Color(0xFF8899AA),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: accent, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    transformationController: transformController,
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Image.memory(
                      Uint8List.fromList(bytes),
                      fit: BoxFit.cover,
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Preview shows final crop area',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  letterSpacing: 1,
                  color: Color(0xFF556677),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                  color: Color(0xFF8899AA),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                result = base64Str;
                Navigator.pop(ctx);
              },
              child: Text(
                'USE IMAGE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                  color: accent,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result;
  }

  Widget _buildGroupAvatar(String? customImage, String iconKey, Color accent, double size) {
    if (customImage != null && customImage.isNotEmpty) {
      try {
        final bytes = base64Decode(customImage);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(color: accent.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              Uint8List.fromList(bytes),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(_groupIcon(iconKey), color: accent, size: size * 0.8),
            ),
          ),
        );
      } catch (_) {
        return Icon(_groupIcon(iconKey), color: accent, size: size * 0.8);
      }
    }
    return Icon(_groupIcon(iconKey), color: accent, size: size * 0.8);
  }

  Widget _buildGroupView() {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group name banner
        if (user != null)
          StreamBuilder<List<Group>>(
            stream: billService.getUserGroupsStream(user.email!.toLowerCase()),
            builder: (context, snapshot) {
              final groups = snapshot.data ?? [];
              final current = groups.where((g) => g.id == groupId).toList();
              final name = current.isNotEmpty ? current.first.name : '';
              final accent = current.isNotEmpty ? _groupColor(current.first.color) : const Color(0xFF00E5CC);
              final iconKey = current.isNotEmpty ? current.first.icon : 'group';
              final customImage = current.isNotEmpty ? current.first.customImage : null;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141A22),
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
                          onTap: _showGroupOptionsDialog,
                          child: _buildGroupAvatar(customImage, iconKey, accent, 28),
                        ),
                        GestureDetector(
                          onTap: _invitePartner,
                          child: Icon(Icons.person_add, color: accent, size: 22),
                        ),
                      ],
                    ),
                  ],
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
            final currentUser = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
            double totalYouOwe = 0;
            double totalTheyOwe = 0;

            for (var bill in bills) {
              final otherOwes = bill.amount * (100 - bill.splitPercent) / 100;
              if (bill.paidBy == currentUser) {
                totalTheyOwe += otherOwes;
              } else {
                totalYouOwe += otherOwes;
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
                final otherOwes = bill.amount * (100 - bill.splitPercent) / 100;
                if (bill.paidBy == currentUser) {
                  runningOwed -= otherOwes; // they owe you
                } else {
                  runningOwed += otherOwes; // you owe them
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
    final currentUser = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
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
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BillDetailScreen(
                bill: bill,
                groupId: groupId!,
                billService: service,
              ),
            ),
          );
          if (result == 'updated' || result == 'deleted') {
            setState(() {});
          }
        },
        onLongPress: () => _showDeleteOption(bill, service),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Icon(
                _iconForCategory(bill.category.isNotEmpty ? bill.category : bill.description),
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Description + split info (left)
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
                  if ((bill.splitPercent - 50).abs() > 1) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Split ${bill.splitPercent.round()}/${(100 - bill.splitPercent).round()}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Color(0xFF00E5CC),
                      ),
                    ),
                  ],
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
            // Amount + owed + date (right)
            Builder(builder: (_) {
              final owed = isYourBill
                  ? bill.amount * (100 - bill.splitPercent) / 100
                  : bill.amount * bill.splitPercent / 100;
              final owedLabel = isYourBill ? "You're owed:" : 'You owe:';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${bill.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$owedLabel ',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF8899AA),
                        ),
                      ),
                      Text(
                        '\$${owed.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, h:mm a').format(bill.createdAt),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Color(0xFF556677),
                    ),
                  ),
                ],
              );
            }),
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
    final currentUser = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    final isYou = from == currentUser;
    final who = isYou ? 'You' : 'They';

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1A12),
        border: Border(
          left: BorderSide(color: Color(0xFF4CAF50), width: 3),
        ),
      ),
      child: Row(
        children: [
          // Settlement icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
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
              if (context.mounted) {
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

  Future<void> _refreshInvites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    await billService.processPendingInvites(user.email!);

    if (mounted) {
      final groups = await billService.getUserGroupsStream(user.email!.toLowerCase()).first;
      if (groups.isNotEmpty) {
        final sharedGroups = groups.where((g) => g.members.length > 1).toList();
        final selected = sharedGroups.isNotEmpty ? sharedGroups.first : groups.first;
        setState(() => groupId = selected.id);
      }
      if (!mounted) return;
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

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    String feedbackType = 'suggestion';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141A22),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text(
            'SEND FEEDBACK',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Color(0xFF00E5CC),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TYPE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Color(0xFF8899AA),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _feedbackTypeChip('suggestion', 'SUGGESTION', feedbackType, (val) {
                      setDialogState(() => feedbackType = val);
                    }),
                    const SizedBox(width: 8),
                    _feedbackTypeChip('bug', 'BUG', feedbackType, (val) {
                      setDialogState(() => feedbackType = val);
                    }),
                    const SizedBox(width: 8),
                    _feedbackTypeChip('other', 'OTHER', feedbackType, (val) {
                      setDialogState(() => feedbackType = val);
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  maxLines: 5,
                  minLines: 3,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFE0E0E0),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Describe your feedback...',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF455566),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Color(0xFF1E2A35)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Color(0xFF00E5CC)),
                    ),
                    filled: true,
                    fillColor: Color(0xFF0D1117),
                    contentPadding: EdgeInsets.all(12),
                  ),
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
                  letterSpacing: 1,
                  color: Color(0xFF8899AA),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () {
                final text = feedbackController.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(ctx);
                _submitFeedback(feedbackType, text);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00E5CC)),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: const Text(
                'SEND',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Color(0xFF00E5CC),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackTypeChip(String value, String label, String current, ValueChanged<String> onTap) {
    final isActive = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00E5CC).withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: isActive
                ? const Color(0xFF00E5CC)
                : const Color(0xFF1E2A35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive
                ? const Color(0xFF00E5CC)
                : const Color(0xFF8899AA),
          ),
        ),
      ),
    );
  }

  Future<void> _submitFeedback(String type, String body) async {
    final user = FirebaseAuth.instance.currentUser;
    // Save feedback to Firestore for tracking
    await FirebaseFirestore.instance.collection('feedback').add({
      'type': type,
      'body': body,
      'email': user?.email,
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF141A22),
          content: Text(
            'Feedback sent — thank you!',
            style: TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5CC)),
          ),
        ),
      );
    }
  }

  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A22),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/app_icon_transparent.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00E5CC), Color(0xFF42A5F5)],
                ).createShader(bounds),
                child: const Text(
                  'SPREAD\nTHE FUND',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                appVersion,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF8899AA),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A bill-splitting app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF556677),
                ),
              ),
              const SizedBox(height: 16),
              Container(width: double.infinity, height: 1, color: const Color(0xFF1E2A35)),
              const SizedBox(height: 16),

              // Developer section
              const Text(
                'This app is a passion project\ndeveloped by Jason Green',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFE0E0E0),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://github.com/CrowdTypical'), mode: LaunchMode.externalApplication),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.code, color: Color(0xFF00E5CC), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'github.com/CrowdTypical',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF00E5CC),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF00E5CC),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(width: double.infinity, height: 1, color: const Color(0xFF1E2A35)),
              const SizedBox(height: 16),

              // Donate section
              const Text(
                'SUPPORT THE PROJECT',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Color(0xFF8899AA),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://buymeacoffee.com/crowdtypical'), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFA726)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.coffee, color: Color(0xFFFFA726), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'BUY ME A COFFEE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Color(0xFFFFA726),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(width: double.infinity, height: 1, color: const Color(0xFF1E2A35)),
              const SizedBox(height: 16),

              // Privacy Policy
              const Text(
                'PRIVACY POLICY',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Color(0xFF8899AA),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Spread the Fund collects only the data '
                'necessary to provide its core bill-splitting '
                'functionality:\n\n'
                '\u2022 Google account info (name, email, photo) '
                'for authentication\n'
                '\u2022 Group and bill data you create within the app\n'
                '\u2022 Feedback you voluntarily submit\n\n'
                'Your data is stored securely in Firebase and is '
                'never sold or shared with third parties.',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.5,
                  color: Color(0xFF556677),
                ),
              ),
              const SizedBox(height: 16),
              Container(width: double.infinity, height: 1, color: const Color(0xFF1E2A35)),
              const SizedBox(height: 16),

              // Delete data section
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteDataDialog();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_forever, color: Color(0xFFEF5350), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'DELETE MY DATA',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Color(0xFFEF5350),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 1,
                color: Color(0xFF8899AA),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDataDialog() {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final confirmed = confirmController.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            backgroundColor: const Color(0xFF141A22),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: const Text(
              'DELETE ALL DATA',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Color(0xFFEF5350),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete:',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFE0E0E0),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Your account & profile\n'
                  '• All groups where you are the only member\n'
                  '• Your membership in shared groups\n'
                  '• All invites you sent or received\n'
                  '• All feedback you submitted',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.6,
                    color: Color(0xFF8899AA),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'THIS CANNOT BE UNDONE.',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF5350),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type DELETE to confirm:',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF8899AA),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF5350),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF333D47),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Color(0xFF1E2A35)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Color(0xFFEF5350)),
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
                  style: TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                    color: Color(0xFF8899AA),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: confirmed ? () => _executeDeleteAllData(ctx) : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: confirmed
                        ? const Color(0xFFEF5350)
                        : const Color(0xFF333D47),
                  ),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: Text(
                  'DELETE EVERYTHING',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: confirmed
                        ? const Color(0xFFEF5350)
                        : const Color(0xFF333D47),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeDeleteAllData(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    Navigator.pop(context); // close drawer

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF141A22),
          duration: Duration(seconds: 10),
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFEF5350),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Deleting all data...',
                style: TextStyle(fontFamily: 'monospace', color: Color(0xFFEF5350)),
              ),
            ],
          ),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final success = await billService.deleteAllUserData(user.email!, user.uid);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    if (success) {
      // Sign out and delete auth account
      try {
        await user.delete();
      } catch (_) {
        // If re-auth is required, just sign out instead
      }
      final authService = context.read<AuthService>();
      await authService.signOut();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF141A22),
            content: Text(
              'Failed to delete data. Please try again.',
              style: TextStyle(fontFamily: 'monospace', color: Color(0xFFEF5350)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final authService = context.read<AuthService>();
    await authService.signOut();
  }
}
