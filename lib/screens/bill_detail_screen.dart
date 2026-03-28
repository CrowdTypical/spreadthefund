// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../models/bill.dart';
import '../services/bill_service.dart';
import '../constants/theme_constants.dart';

class BillDetailScreen extends StatefulWidget {
  final Bill bill;
  final String groupId;
  final BillService billService;

  const BillDetailScreen({
    Key? key,
    required this.bill,
    required this.groupId,
    required this.billService,
  }) : super(key: key);

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  bool _editing = false;
  bool _saving = false;
  bool _showMeta = false;

  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late double _splitPercent;
  late String _paidBy;
  late String _category;

  List<Map<String, String>> _members = [];

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.bill.amount.toStringAsFixed(2));
    _notesController = TextEditingController(text: widget.bill.notes);
    _splitPercent = widget.bill.splitPercent.clamp(5, 95).toDouble();
    _paidBy = widget.bill.paidBy;
    _category = widget.bill.category;
    _loadData();
  }

  Future<void> _loadData() async {
    final members =
        await widget.billService.getGroupMembers(widget.groupId);
    if (mounted) {
      setState(() {
        _members = members;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _memberName(String email) {
    for (final m in _members) {
      if (m['email'] == email) return m['name'] ?? email;
    }
    return email;
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final currentUser = context.read<AuthService>().currentUser!.email!.toLowerCase();
    final isYourBill = bill.paidBy == currentUser;
    final accentColor =
        isYourBill ? AppColors.accent : AppColors.danger;

    final amount = double.tryParse(_amountController.text) ?? bill.amount;
    final owedAmount = isYourBill
        ? amount * (100 - _splitPercent) / 100
        : amount * _splitPercent / 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _editing ? 'EDIT BILL' : 'BILL DETAILS',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.accent),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // â”€â”€ Header: icon + category + amount â”€â”€
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colorForCategory(bill.category.isNotEmpty
                        ? bill.category
                        : bill.description).withValues(alpha: 0.12),
                    border: Border.all(color: colorForCategory(bill.category.isNotEmpty
                        ? bill.category
                        : bill.description).withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    iconForCategory(bill.category.isNotEmpty
                        ? bill.category
                        : bill.description),
                    color: colorForCategory(bill.category.isNotEmpty
                        ? bill.category
                        : bill.description),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  bill.description.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${bill.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy — h:mm a')
                      .format(bill.createdAt),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // â”€â”€ Split breakdown â”€â”€
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SPLIT BREAKDOWN',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                _detailRow(
                  'Paid by',
                  _memberName(bill.paidBy),
                  isYourBill
                      ? AppColors.accent
                      : AppColors.danger,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Split',
                  '${bill.splitPercent.round()} / ${(100 - bill.splitPercent).round()}',
                  AppColors.textPrimary,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Payer\'s share',
                  '\$${(bill.amount * bill.splitPercent / 100).toStringAsFixed(2)}',
                  AppColors.accent,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Other\'s share',
                  '\$${(bill.amount * (100 - bill.splitPercent) / 100).toStringAsFixed(2)}',
                  AppColors.danger,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: accentColor.withValues(alpha: 0.08),
                  child: Text(
                    isYourBill
                        ? 'You\'re owed \$${owedAmount.toStringAsFixed(2)}'
                        : 'You owe \$${owedAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // â”€â”€ Notes â”€â”€
          if (bill.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NOTES',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bill.notes,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // â”€â”€ Edit section â”€â”€
          if (_editing) ...[
            _buildEditSection(),
            const SizedBox(height: 12),
          ],

          // â”€â”€ Metadata toggle â”€â”€
          GestureDetector(
            onTap: () => setState(() => _showMeta = !_showMeta),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report,
                      color: AppColors.textDim, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'DEBUG / METADATA',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 1,
                      color: AppColors.textDim,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showMeta
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textDim,
                  ),
                ],
              ),
            ),
          ),

          if (_showMeta) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _metaRow('Bill ID', bill.id),
                  const SizedBox(height: 6),
                  _metaRow('Group ID', widget.groupId),
                  const SizedBox(height: 6),
                  _metaRow('Paid By (UID)', bill.paidBy),
                  const SizedBox(height: 6),
                  _metaRow('Category', bill.category),
                  const SizedBox(height: 6),
                  _metaRow('Description', bill.description),
                  const SizedBox(height: 6),
                  _metaRow('Amount (raw)', bill.amount.toString()),
                  const SizedBox(height: 6),
                  _metaRow('Split %', bill.splitPercent.toString()),
                  const SizedBox(height: 6),
                  _metaRow('Settled', bill.settled.toString()),
                  const SizedBox(height: 6),
                  _metaRow('Created At', bill.createdAt.toIso8601String()),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // â”€â”€ Delete button â”€â”€
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmDelete(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.danger),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
              ),
              child: const Text(
                'DELETE BILL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // â”€â”€ Edit section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildEditSection() {
    final currentEmail = context.read<AuthService>().currentUser!.email!.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EDIT BILL',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              letterSpacing: 1,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),

          // Amount
          TextFormField(
            controller: _amountController,
            maxLength: 12,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 20,
                color: AppColors.accent),
            decoration: const InputDecoration(
              labelText: 'AMOUNT',
              labelStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 1,
                  color: AppColors.textMuted),
              prefixText: '\$ ',
              prefixStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  color: AppColors.accent),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.accent),
              ),
              filled: true,
              fillColor: Color(0xFF0D1117),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),

          // Split slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SPLIT: ${_splitPercent.round()}/${(100 - _splitPercent).round()}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 1,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor:
                  AppColors.danger.withValues(alpha: 0.4),
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.15),
              trackHeight: 6,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _splitPercent,
              min: 5,
              max: 95,
              divisions: 18,
              onChanged: (val) => setState(() => _splitPercent = val),
            ),
          ),

          // Preset buttons
          Row(
            children: [
              _presetBtn('70/30', 70),
              const SizedBox(width: 6),
              _presetBtn('50/50', 50),
              const SizedBox(width: 6),
              _presetBtn('30/70', 30),
            ],
          ),
          const SizedBox(height: 12),

          // Who paid
          if (_members.isNotEmpty) ...[
            const Text(
              'WHO PAID?',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 1,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey(_paidBy),
              initialValue: _members.any((m) => m['email'] == _paidBy) ? _paidBy : null,
              dropdownColor: AppColors.surface,
              isExpanded: true,
              style: const TextStyle(
                  fontFamily: 'monospace', color: AppColors.textPrimary),
              decoration: const InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.accent),
                ),
                filled: true,
                fillColor: Color(0xFF0D1117),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              selectedItemBuilder: (context) {
                return _members.map((m) {
                  final isMe = m['email'] == currentEmail;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isMe
                          ? '${m['name']!.toUpperCase()} (YOU)'
                          : m['name']!.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList();
              },
              items: _members.map((m) {
                final isMe = m['email'] == currentEmail;
                final showEmail = m['email']!.isNotEmpty && m['email'] != m['name'];
                return DropdownMenuItem(
                  value: m['email'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isMe
                            ? '${m['name']!.toUpperCase()} (YOU)'
                            : m['name']!.toUpperCase(),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                      ),
                      if (showEmail)
                        Text(
                          m['email']!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: AppColors.textDim,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _paidBy = val!),
            ),
            const SizedBox(height: 12),
          ],

          // Notes
          TextField(
            controller: _notesController,
            maxLength: 500,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'NOTES',
              labelStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 1,
                color: AppColors.textMuted,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.accent),
              ),
              filled: true,
              fillColor: Color(0xFF0D1117),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Save / Cancel buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _editing = false;
                      _amountController.text =
                          widget.bill.amount.toStringAsFixed(2);
                      _notesController.text = widget.bill.notes;
                      _splitPercent = widget.bill.splitPercent.clamp(5, 95).toDouble();
                      _paidBy = widget.bill.paidBy;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.textMuted),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _saveChanges,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.accent),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent),
                        )
                      : const Text(
                          'SAVE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: AppColors.accent,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetBtn(String label, double value) {
    final isActive = (_splitPercent - value).abs() < 1;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _splitPercent = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accent.withValues(alpha: 0.15)
                : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? AppColors.accent
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive
                  ? AppColors.accent
                  : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _detailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: AppColors.textDim,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surface,
                  duration: const Duration(seconds: 1),
                  content: Text(
                    'Copied: $label',
                    style: const TextStyle(
                        fontFamily: 'monospace', color: AppColors.accent),
                  ),
                ),
              );
            },
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Enter a valid amount',
            style:
                TextStyle(fontFamily: 'monospace', color: AppColors.danger),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final success = await widget.billService.updateBill(
      groupId: widget.groupId,
      billId: widget.bill.id,
      paidBy: _paidBy,
      amount: amount,
      description: _category,
      category: _category,
      notes: _notesController.text.trim(),
      splitPercent: _splitPercent,
    );

    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Bill updated!',
              style:
                  TextStyle(fontFamily: 'monospace', color: AppColors.accent),
            ),
          ),
        );
        Navigator.pop(context, 'updated');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Error updating bill',
              style:
                  TextStyle(fontFamily: 'monospace', color: AppColors.danger),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'DELETE BILL?',
          style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1,
              color: AppColors.textPrimary),
        ),
        content: Text(
          '${widget.bill.description} — \$${widget.bill.amount.toStringAsFixed(2)}',
          style: const TextStyle(
              fontFamily: 'monospace', color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL',
                style: TextStyle(fontFamily: 'monospace')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE',
                style: TextStyle(
                    fontFamily: 'monospace', color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.billService.deleteBill(widget.groupId, widget.bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Bill deleted',
              style:
                  TextStyle(fontFamily: 'monospace', color: AppColors.danger),
            ),
          ),
        );
        Navigator.pop(context, 'deleted');
      }
    }
  }
}
