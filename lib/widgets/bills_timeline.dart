// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../models/bill.dart';
import 'balance_card.dart';
import 'bill_tile.dart';
import 'settlement_tile.dart';
import 'settle_up_dialog.dart';
import 'settlement_detail_sheet.dart';
import '../constants/theme_constants.dart';

class BillsTimeline extends StatefulWidget {
  final String groupId;
  final BillService billService;
  final void Function(Bill bill) onBillTap;
  final void Function(Bill bill) onBillLongPress;
  final VoidCallback onChanged;
  final void Function(bool editing, int selectedCount)? onEditStateChanged;

  const BillsTimeline({
    super.key,
    required this.groupId,
    required this.billService,
    required this.onBillTap,
    required this.onBillLongPress,
    required this.onChanged,
    this.onEditStateChanged,
  });

  @override
  State<BillsTimeline> createState() => BillsTimelineState();
}

class BillsTimelineState extends State<BillsTimeline>
    with SingleTickerProviderStateMixin {
  bool _editMode = false;
  final Set<String> _selectedBillIds = {};
  final Set<String> _selectedSettlementIds = {};
  late final AnimationController _editAnimController;
  late final Animation<double> _checkboxWidth;
  late Stream<List<Bill>> _billsStream;
  late Stream<QuerySnapshot> _settlementsStream;

  bool get editMode => _editMode;
  int get totalSelected => _selectedBillIds.length + _selectedSettlementIds.length;

  @override
  void initState() {
    super.initState();
    _editAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _checkboxWidth = Tween<double>(begin: 0, end: 30).animate(
      CurvedAnimation(parent: _editAnimController, curve: Curves.easeInOut),
    );
    _billsStream = widget.billService.getBillsStream(widget.groupId);
    _settlementsStream = widget.billService.getSettlementsStream(widget.groupId);
  }

  @override
  void didUpdateWidget(covariant BillsTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _billsStream = widget.billService.getBillsStream(widget.groupId);
      _settlementsStream = widget.billService.getSettlementsStream(widget.groupId);
      // Reset edit state internally without notifying parent
      // (parent already resets its own state when changing groupId)
      _editAnimController.reset();
      setState(() {
        _editMode = false;
        _selectedBillIds.clear();
        _selectedSettlementIds.clear();
      });
    }
  }

  @override
  void dispose() {
    _editAnimController.dispose();
    super.dispose();
  }

  void _exitEditMode() {
    _editAnimController.reverse();
    setState(() {
      _editMode = false;
      _selectedBillIds.clear();
      _selectedSettlementIds.clear();
    });
    widget.onEditStateChanged?.call(false, 0);
  }

  void exitEditMode() => _exitEditMode();

  void _toggleBill(String id) {
    setState(() {
      if (_selectedBillIds.contains(id)) {
        _selectedBillIds.remove(id);
      } else {
        _selectedBillIds.add(id);
      }
    });
    widget.onEditStateChanged?.call(_editMode, totalSelected);
  }

  void _toggleSettlement(String id) {
    setState(() {
      if (_selectedSettlementIds.contains(id)) {
        _selectedSettlementIds.remove(id);
      } else {
        _selectedSettlementIds.add(id);
      }
    });
    widget.onEditStateChanged?.call(_editMode, totalSelected);
  }

  void _selectAll(List<Map<String, dynamic>> timeline) {
    setState(() {
      for (final item in timeline) {
        if (item['type'] == 'bill') {
          _selectedBillIds.add((item['data'] as Bill).id);
        } else {
          _selectedSettlementIds.add(item['id'] as String);
        }
      }
    });
    widget.onEditStateChanged?.call(_editMode, totalSelected);
  }

  void _deselectAll() {
    setState(() {
      _selectedBillIds.clear();
      _selectedSettlementIds.clear();
    });
    widget.onEditStateChanged?.call(_editMode, totalSelected);
  }

  int get _totalSelected => _selectedBillIds.length + _selectedSettlementIds.length;

  Future<void> confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'DELETE SELECTED?',
          style: TextStyle(fontFamily: 'monospace', letterSpacing: 1, color: AppColors.textPrimary),
        ),
        content: Text(
          'Delete $_totalSelected item${_totalSelected == 1 ? '' : 's'}? This cannot be undone.',
          style: const TextStyle(fontFamily: 'monospace', color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await widget.billService.bulkDeleteActivity(
        groupId: widget.groupId,
        billIds: _selectedBillIds,
        settlementIds: _selectedSettlementIds,
      );
      if (mounted) {
        _exitEditMode();
        widget.onChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              success ? 'Deleted successfully' : 'Error deleting items',
              style: TextStyle(
                fontFamily: 'monospace',
                color: success ? AppColors.accent : AppColors.danger,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Bill>>(
      stream: _billsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
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
                  'Tap + to add your first bill',
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

        return StreamBuilder<QuerySnapshot>(
          stream: _settlementsStream,
          builder: (context, settleSnap) {
            final currentUser = context.read<AuthService>().currentUser!.email!.toLowerCase();

            final settlementMaps = <Map<String, dynamic>>[];
            if (settleSnap.hasData) {
              for (var doc in settleSnap.data!.docs) {
                settlementMaps.add(doc.data() as Map<String, dynamic>);
              }
            }

            // Exit edit mode if group changed
            final double adjustedDifference = BillService.computeNetBalance(
              bills: bills,
              settlements: settlementMaps,
              userEmail: currentUser,
            );

            final List<Map<String, dynamic>> timeline = [];

            for (final bill in bills) {
              timeline.add({'type': 'bill', 'data': bill, 'date': bill.createdAt});
            }

            final settlementsForTimeline = <Map<String, dynamic>>[];
            if (settleSnap.hasData) {
              for (final doc in settleSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final settledAt = data['settledAt'] as Timestamp?;
                final settledAtLocal = data['settledAtLocal'] as String?;
                final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                final from = data['from'] as String? ?? '';
                final to = data['to'] as String? ?? '';
                final paymentMethod = data['paymentMethod'] as String? ?? '';
                final date = settledAt?.toDate()
                    ?? (settledAtLocal != null ? DateTime.tryParse(settledAtLocal) : null)
                    ?? DateTime(2000);
                settlementsForTimeline.add({
                  'type': 'settlement',
                  'id': doc.id,
                  'amount': amount,
                  'from': from,
                  'to': to,
                  'date': date,
                  'paymentMethod': paymentMethod,
                });
              }
            }
            timeline.addAll(settlementsForTimeline);

            timeline.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

            BillService.computeRunningBalances(
              timeline: timeline,
              userEmail: currentUser,
            );

            final partnerEmail = bills
                .map((b) => b.paidBy)
                .where((email) => email != currentUser)
                .cast<String>()
                .firstOrNull ?? '';

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                BalanceCard(
                    youOwe: adjustedDifference > 0 ? adjustedDifference : 0.0,
                    theyOwe: adjustedDifference < 0 ? adjustedDifference.abs() : 0.0,
                    onSettle: () {
                      final difference = (adjustedDifference > 0 ? adjustedDifference : 0.0) -
                          (adjustedDifference < 0 ? adjustedDifference.abs() : 0.0);
                      showSettleUpDialog(
                        context,
                        suggestedAmount: difference.abs(),
                        partnerEmail: partnerEmail,
                        youOwe: difference > 0,
                        groupId: widget.groupId,
                        billService: widget.billService,
                      );
                    },
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ACTIVITY',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (_editMode) ...[
                        GestureDetector(
                          onTap: () {
                            final allSelected = _totalSelected == timeline.length;
                            if (allSelected) {
                              _deselectAll();
                            } else {
                              _selectAll(timeline);
                            }
                          },
                          child: Text(
                            _totalSelected == timeline.length ? 'DESELECT ALL' : 'SELECT ALL',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      GestureDetector(
                        onTap: () {
                          if (_editMode) {
                            _exitEditMode();
                          } else {
                            _editAnimController.forward();
                            setState(() => _editMode = true);
                            widget.onEditStateChanged?.call(true, 0);
                          }
                        },
                        child: Text(
                          _editMode ? 'DONE' : 'EDIT',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: _editMode ? AppColors.danger : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...timeline.map((item) {
                  if (item['type'] == 'bill') {
                    final bill = item['data'] as Bill;
                    final isSelected = _selectedBillIds.contains(bill.id);
                    return Row(
                      children: [
                        AnimatedBuilder(
                          animation: _checkboxWidth,
                          builder: (context, child) => SizedBox(
                            width: _checkboxWidth.value,
                            child: child,
                          ),
                          child: GestureDetector(
                            onTap: () => _toggleBill(bill.id),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Icon(
                                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                color: isSelected ? AppColors.accent : AppColors.textMuted,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: BillTile(
                            bill: bill,
                            currentUserEmail: currentUser,
                            onTap: _editMode
                                ? () => _toggleBill(bill.id)
                                : () => widget.onBillTap(bill),
                            onLongPress: _editMode
                                ? () => _toggleBill(bill.id)
                                : () => widget.onBillLongPress(bill),
                          ),
                        ),
                      ],
                    );
                  } else {
                    final settlementId = item['id'] as String;
                    final isSelected = _selectedSettlementIds.contains(settlementId);
                    return Row(
                      children: [
                        AnimatedBuilder(
                          animation: _checkboxWidth,
                          builder: (context, child) => SizedBox(
                            width: _checkboxWidth.value,
                            child: child,
                          ),
                          child: GestureDetector(
                            onTap: () => _toggleSettlement(settlementId),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Icon(
                                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                color: isSelected ? AppColors.accent : AppColors.textMuted,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SettlementTile(
                            settlementId: settlementId,
                            amount: item['amount'] as double,
                            from: item['from'] as String,
                            to: item['to'] as String? ?? '',
                            date: item['date'] as DateTime,
                            remainingBalance: (item['remainingAtTime'] as double?) ?? 0.0,
                            paymentMethod: item['paymentMethod'] as String? ?? '',
                            currentUserEmail: currentUser,
                            onTap: _editMode
                                ? () => _toggleSettlement(settlementId)
                                : () => showSettlementDetailSheet(
                                    context,
                                    settlementId: settlementId,
                                    amount: item['amount'] as double,
                                    from: item['from'] as String,
                                    to: item['to'] as String? ?? '',
                                    date: item['date'] as DateTime,
                                    remainingBalance: (item['remainingAtTime'] as double?) ?? 0.0,
                                    paymentMethod: item['paymentMethod'] as String? ?? '',
                                    groupId: widget.groupId,
                                    billService: widget.billService,
                                    onChanged: widget.onChanged,
                                  ),
                          ),
                        ),
                      ],
                    );
                  }
                }),
                // Bottom padding when in edit mode to keep items above the floating delete bar
                if (_editMode)
                  const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }
}
