// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:ui';

import 'package:flutter/material.dart';
import '../widgets/glitch_dollar_icon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../services/update_checker.dart';
import '../models/bill.dart';
import '../models/group.dart';
import 'add_bill_screen.dart';
import 'group_details_screen.dart';
import 'bill_detail_sheet_content.dart';
import 'partner_setup_screen.dart';
import '../constants/theme_constants.dart';
import '../widgets/group_drawer.dart';
import '../widgets/group_view_header.dart';
import '../widgets/bills_timeline.dart';
import '../widgets/create_group_dialog.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/about_dialog.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/confetti_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late BillService billService;
  String? groupId;
  bool groupChecked = false;
  bool _reorderMode = false;
  List<String> _groupOrder = [];
  final _timelineKey = GlobalKey<BillsTimelineState>();
  bool _editMode = false;
  int _editSelectedCount = 0;
  bool _showConfetti = false;
  late final AnimationController _fabMorphController;
  late final Animation<double> _fabMorph;

  @override
  void initState() {
    super.initState();
    billService = context.read<BillService>();
    _fabMorphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fabMorph = CurvedAnimation(
      parent: _fabMorphController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _initGroup();
    checkForUpdate(context);
  }

  Future<void> _initGroup() async {
    await _loadGroupOrder();
    await _checkGroup();
  }

  Future<void> _checkGroup() async {
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      // Process any pending invites every time the app starts (not just on sign-in),
      // since Firebase caches auth state across sessions.
      if (user.email != null) {
        // Migrate any old UID-based memberships to email (one-time operation)
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final uidMigrated = userDoc.data()?['uidMigrated'] == true;
        if (!uidMigrated) {
          await billService.migrateUidToEmail(user.uid, user.email!);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'uidMigrated': true}, SetOptions(merge: true));
        }
        // Pending invites are now shown in the drawer for user approval
        // (no longer auto-accepted).
      }

      final email = user.email!.toLowerCase();
      final groups = await billService.getUserGroupsStream(email).first;
      if (groups.isNotEmpty) {
        // Sort by custom group order (matches sidebar) then pick the first
        final sorted = _applySortOrder(groups);
        setState(() {
          groupId = sorted.first.id;
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

  List<Group> _applySortOrder(List<Group> groups) {
    if (_groupOrder.isEmpty) return groups;
    final ordered = <Group>[];
    for (final id in _groupOrder) {
      final match = groups.where((g) => g.id == id);
      if (match.isNotEmpty) ordered.add(match.first);
    }
    for (final g in groups) {
      if (!_groupOrder.contains(g.id)) ordered.add(g);
    }
    return ordered;
  }

  Future<void> _loadGroupOrder() async {
    final user = context.read<AuthService>().currentUser;
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
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'groupOrder': order});
  }

  void _invitePartner({int memberCount = 0}) {
    if (memberCount >= BillService.maxGroupMembers) {
      showGroupLimitDialog(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerSetupScreen(
          groupId: groupId,
          onGroupCreated: (newGroupId) {
            setState(() => groupId = newGroupId);
            _editMode = false;
            _editSelectedCount = 0;
            _fabMorphController.reset();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!groupChecked) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlitchDollarIcon(size: 80),
              SizedBox(height: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.5,
      appBar: AppBar(
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, size: 30),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const GlitchDollarIcon(size: 42),
      ),
      drawer: GroupDrawer(
        billService: billService,
        selectedGroupId: groupId,
        reorderMode: _reorderMode,
        groupOrder: _groupOrder,
        onEditUsername: () => showEditUsernameDialog(context),
        onCreateGroup: () => showCreateGroupDialog(
          context,
          billService: billService,
          onGroupCreated: (newId) {
            if (mounted) setState(() { groupId = newId; _editMode = false; _editSelectedCount = 0; _fabMorphController.reset(); });
          },
        ),
        onToggleReorderMode: () => setState(() {
          _reorderMode = !_reorderMode;
        }),
        onReorder: (newOrder) {
          setState(() => _groupOrder = newOrder);
          _saveGroupOrder(newOrder);
        },
        onGroupSelected: (id) {
          setState(() { groupId = id; _editMode = false; _editSelectedCount = 0; _fabMorphController.reset(); });
        },
        onGroupLongPress: (group) async {
          final messenger = ScaffoldMessenger.of(context);
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailsScreen(groupId: group.id),
            ),
          );
          if (result == 'deleted' && context.mounted) {
            final user = context.read<AuthService>().currentUser;
            if (user != null) {
              final groups = await billService.getUserGroupsStream(user.email!.toLowerCase()).first;
              setState(() {
                groupId = groups.isNotEmpty ? groups.first.id : null;
              });
            }
            messenger.showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.surface,
                content: Text(
                  'Group deleted',
                  style: TextStyle(fontFamily: 'monospace', color: AppColors.accent),
                ),
              ),
            );
          }
        },
        onRefreshInvites: _refreshInvites,
        onFeedback: () => showFeedbackDialog(context),
        onLogout: _logout,
        onAbout: () => showAboutApp(context, billService: billService, authService: context.read<AuthService>()),
      ),
      body: groupId == null
          ? Stack(
              children: [
                _buildEmptyBillsView(),
                _buildMorphingFab(),
              ],
            )
          : Stack(
              children: [
                _buildGroupView(),
                _buildMorphingFab(),
                if (_showConfetti)
                  ConfettiOverlay(
                    onComplete: () => setState(() => _showConfetti = false),
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _fabMorphController.dispose();
    super.dispose();
  }

  Widget _buildMorphingFab() {
    return AnimatedBuilder(
      animation: _fabMorph,
      builder: (_, child) {
        final t = _fabMorph.value;
        final mq = MediaQuery.of(context);
        final screenWidth = mq.size.width;
        final navBarPad = mq.viewPadding.bottom;

        // Morph dimensions
        final width = lerpDouble(64, screenWidth, t)!;
        final height = lerpDouble(64, 60 + navBarPad, t)!;
        final right = lerpDouble(32, 0, t)!;
        final bottom = lerpDouble(48 + navBarPad, 0, t)!;
        final radius = lerpDouble(16, 0, t)!;

        // Color morph: accent → danger
        final color = Color.lerp(AppColors.accent, AppColors.danger, t)!;
        final displayColor = _editMode && _editSelectedCount == 0
            ? color.withValues(alpha: 0.5 + 0.5 * (1 - t).clamp(0.0, 1.0))
            : color;

        return Positioned(
          right: right,
          bottom: bottom,
          child: SizedBox(
            width: width,
            height: height,
            child: Material(
              color: displayColor,
              borderRadius: BorderRadius.circular(radius),
              elevation: 6,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _editMode
                    ? (_editSelectedCount > 0
                        ? () => _timelineKey.currentState?.confirmAndDelete()
                        : null)
                    : () async {
                        final user = context.read<AuthService>().currentUser;
                        final navigator = Navigator.of(context);
                        if (groupId == null) {
                          if (user != null) {
                            final newId = await billService
                                .createPersonalGroup(user.email!.toLowerCase());
                            if (newId != null) {
                              setState(() => groupId = newId);
                            }
                          }
                        }
                        if (groupId != null && context.mounted) {
                          navigator.push(
                            PageRouteBuilder(
                              opaque: false,
                              barrierDismissible: true,
                              barrierColor: Colors.black54,
                              transitionDuration:
                                  const Duration(milliseconds: 300),
                              reverseTransitionDuration:
                                  const Duration(milliseconds: 250),
                              pageBuilder: (_, __, ___) =>
                                  AddBillScreen(groupId: groupId!),
                              transitionsBuilder:
                                  (_, animation, __, child) {
                                final tween = Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
                                  end: Offset.zero,
                                ).chain(
                                    CurveTween(curve: Curves.easeOutCubic));
                                return SlideTransition(
                                  position: tween.animate(animation),
                                  child: child,
                                );
                              },
                            ),
                          );
                        }
                      },
                child: Padding(
                  padding: EdgeInsets.only(bottom: navBarPad * t),
                  child: Center(
                  child: t < 0.5
                      ? Opacity(
                          opacity: 1.0 - (t * 2).clamp(0.0, 1.0),
                          child: const Icon(
                            Icons.add,
                            color: AppColors.background,
                          ),
                        )
                      : Opacity(
                          opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _editSelectedCount > 0
                                    ? 'DELETE $_editSelectedCount ITEM${_editSelectedCount == 1 ? '' : 'S'}'
                                    : 'SELECT ITEMS TO DELETE',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GroupViewHeader(
          groupId: groupId!,
          billService: billService,
          onGroupOptions: () => showGroupOptionsDialog(
            context,
            groupId: groupId!,
            billService: billService,
            onGroupChanged: (newId) => setState(() { groupId = newId; _editMode = false; _editSelectedCount = 0; _fabMorphController.reset(); }),
          ),
          onInvitePartner: () {
            // Fetch current member count from stream for limit check
            final user = context.read<AuthService>().currentUser;
            if (user == null) return;
            billService.getUserGroupsStream(user.email!.toLowerCase()).first.then((groups) {
              final current = groups.where((g) => g.id == groupId).toList();
              _invitePartner(
                memberCount: current.isNotEmpty ? current.first.members.length : 0,
              );
            });
          },
        ),
        Expanded(
          child: BillsTimeline(
            key: _timelineKey,
            groupId: groupId!,
            billService: billService,
            onBillTap: (bill) => _showBillDetailSheet(bill, billService),
            onBillLongPress: (bill) => _showDeleteOption(bill, billService),
            onChanged: () => setState(() {}),
            onSettled: () => setState(() => _showConfetti = true),
            onEditStateChanged: (editing, selectedCount) {
              if (editing && !_editMode) {
                _fabMorphController.forward();
              } else if (!editing && _editMode) {
                _fabMorphController.reverse();
              }
              setState(() {
                _editMode = editing;
                _editSelectedCount = selectedCount;
              });
            },
          ),
        ),
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
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.receipt_long, size: 48, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          const Text(
            'NO BILLS YET',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to add a bill',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _showBillDetailSheet(Bill bill, BillService service) {
    final currentUser = context.read<AuthService>().currentUser!.email!.toLowerCase();
    final isYourBill = bill.paidBy == currentUser;
    final accentColor = isYourBill ? AppColors.accent : AppColors.danger;
    final owedAmount = isYourBill
        ? bill.amount * (100 - bill.splitPercent) / 100
        : bill.amount * bill.splitPercent / 100;
    final catColor = colorForCategory(bill.category.isNotEmpty ? bill.category : bill.description);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return BillDetailSheetContent(
              bill: bill,
              billService: service,
              groupId: groupId!,
              scrollController: scrollController,
              currentUser: currentUser,
              isYourBill: isYourBill,
              accentColor: accentColor,
              owedAmount: owedAmount,
              catColor: catColor,
              onChanged: () => setState(() {}),
            );
          },
        );
      },
    );
  }

  void _showDeleteOption(Bill bill, BillService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'DELETE BILL?',
          style: TextStyle(fontFamily: 'monospace', letterSpacing: 1, color: AppColors.textPrimary),
        ),
        content: Text(
          '${bill.description} — \$${bill.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontFamily: 'monospace', color: AppColors.textMuted),
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
    final user = context.read<AuthService>().currentUser;
    if (user == null || user.email == null) return;

    final pendingCount = await billService.countPendingInvites(user.email!);

    if (mounted) {
      final groups = await billService.getUserGroupsStream(user.email!.toLowerCase()).first;
      if (groups.isNotEmpty) {
        final stillExists = groupId != null && groups.any((g) => g.id == groupId);
        if (!stillExists) {
          final sharedGroups = groups.where((g) => g.members.length > 1).toList();
          final selected = sharedGroups.isNotEmpty ? sharedGroups.first : groups.first;
          setState(() { groupId = selected.id; _editMode = false; _editSelectedCount = 0; _fabMorphController.reset(); });
        }
      }
      if (!mounted) return;
      final msg = pendingCount > 0
          ? 'You have $pendingCount pending invite(s)'
          : 'Found ${groups.length} group(s)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            msg,
            style: const TextStyle(fontFamily: 'monospace', color: AppColors.accent),
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

