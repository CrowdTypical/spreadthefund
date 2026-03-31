// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/bill_service.dart';
import '../constants/theme_constants.dart';

// â”€â”€ Bill Detail Bottom Sheet (stateful for edit mode) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class BillDetailSheetContent extends StatefulWidget {
  final Bill bill;
  final BillService billService;
  final String groupId;
  final ScrollController scrollController;
  final String currentUser;
  final bool isYourBill;
  final Color accentColor;
  final double owedAmount;
  final Color catColor;
  final VoidCallback onChanged;

  const BillDetailSheetContent({
    super.key,
    required this.bill,
    required this.billService,
    required this.groupId,
    required this.scrollController,
    required this.currentUser,
    required this.isYourBill,
    required this.accentColor,
    required this.owedAmount,
    required this.catColor,
    required this.onChanged,
  });

  @override
  State<BillDetailSheetContent> createState() => _BillDetailSheetContentState();
}

class _BillDetailSheetContentState extends State<BillDetailSheetContent> {
  bool _editing = false;
  bool _saving = false;
  bool _showCategories = false;
  bool _showAllCategories = false;
  bool _showCustomInput = false;

  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late TextEditingController _customCategoryController;
  late double _splitPercent;
  late String _paidBy;
  late String _selectedCategory;

  List<Map<String, String>> _members = [];
  List<String> _sortedCategories = [];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.bill.amount.toStringAsFixed(2));
    _notesController = TextEditingController(text: widget.bill.notes);
    _customCategoryController = TextEditingController();
    _splitPercent = widget.bill.splitPercent.clamp(5, 95).toDouble();
    _paidBy = widget.bill.paidBy;
    _selectedCategory = widget.bill.description;
    _loadData();
  }

  Future<void> _loadData() async {
    final members = await widget.billService.getGroupMembers(widget.groupId);
    final categories = await widget.billService.getGroupCategories(widget.groupId);
    final usedNames = categories.map((c) => c.toLowerCase()).toSet();
    final defaults = defaultCategories
        .where((c) => !usedNames.contains(c.name.toLowerCase()))
        .map((c) => c.name)
        .toList();
    if (mounted) {
      setState(() {
        _members = members;
        _sortedCategories = [...categories, ...defaults];
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
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

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header: icon + description + amount
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.catColor.withValues(alpha: 0.12),
                  border: Border.all(color: widget.catColor.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  iconForCategory(bill.category.isNotEmpty ? bill.category : bill.description),
                  color: widget.catColor,
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
                  color: widget.accentColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMMM d, yyyy — h:mm a').format(bill.createdAt),
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

        // Split breakdown
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
              _sheetDetailRow('Paid by', _memberName(bill.paidBy),
                  widget.isYourBill ? AppColors.accent : AppColors.danger),
              const SizedBox(height: 8),
              _sheetDetailRow('Split', '${bill.splitPercent.round()} / ${(100 - bill.splitPercent).round()}',
                  AppColors.textPrimary),
              const SizedBox(height: 8),
              _sheetDetailRow("Payer's share",
                  '\$${(bill.amount * bill.splitPercent / 100).toStringAsFixed(2)}',
                  AppColors.accent),
              const SizedBox(height: 8),
              _sheetDetailRow("Other's share",
                  '\$${(bill.amount * (100 - bill.splitPercent) / 100).toStringAsFixed(2)}',
                  AppColors.danger),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: widget.accentColor.withValues(alpha: 0.08),
                child: Text(
                  widget.isYourBill
                      ? 'You\'re owed \$${widget.owedAmount.toStringAsFixed(2)}'
                      : 'You owe \$${widget.owedAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // Added by
        if (bill.createdBy != null && bill.createdBy!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetDetailRow(
                  'Added by',
                  _memberName(bill.createdBy!),
                  AppColors.textPrimary,
                ),
                if (_memberName(bill.createdBy!) != bill.createdBy!) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      bill.createdBy!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Notes
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

        const SizedBox(height: 16),

        // Edit / Delete buttons row
        if (!_editing) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editing = true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.accent),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: const Text(
                    'EDIT',
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
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmDelete(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.danger),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: const Text(
                    'DELETE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],

        // Edit section (shown when user taps EDIT or drags up)
        if (_editing) ...[
          _buildEditSection(),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEditSection() {
    final currentEmail = widget.currentUser;

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

          // Category / Description selector
          _buildCategorySelector(),
          const SizedBox(height: 12),

          // Amount
          TextFormField(
            controller: _amountController,
            maxLength: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 20, color: AppColors.accent),
            decoration: const InputDecoration(
              labelText: 'AMOUNT',
              labelStyle: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1, color: AppColors.textMuted),
              prefixText: '\$ ',
              prefixStyle: TextStyle(fontFamily: 'monospace', fontSize: 20, color: AppColors.accent),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.accent)),
              filled: true,
              fillColor: Color(0xFF0D1117),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),

          // Split slider
          Text(
            'SPLIT: ${_splitPercent.round()}/${(100 - _splitPercent).round()}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1, color: AppColors.textMuted),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.danger.withValues(alpha: 0.4),
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.15),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _splitPercent,
              min: 5,
              max: 95,
              divisions: 18,
              onChanged: (val) => setState(() => _splitPercent = val),
            ),
          ),
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
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _members.any((m) => m['email'] == _paidBy) ? _paidBy : null,
              dropdownColor: AppColors.surface,
              isExpanded: true,
              style: const TextStyle(fontFamily: 'monospace', color: AppColors.textPrimary),
              decoration: const InputDecoration(
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.accent)),
                filled: true,
                fillColor: Color(0xFF0D1117),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: _members.map((m) {
                final isMe = m['email'] == currentEmail;
                return DropdownMenuItem(
                  value: m['email'],
                  child: Text(
                    isMe ? '${m['name']!.toUpperCase()} (YOU)' : m['name']!.toUpperCase(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
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
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: AppColors.textPrimary),
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'NOTES',
              labelStyle: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1, color: AppColors.textMuted),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.accent)),
              filled: true,
              fillColor: Color(0xFF0D1117),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Save / Cancel
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _editing = false;
                    _amountController.text = widget.bill.amount.toStringAsFixed(2);
                    _notesController.text = widget.bill.notes;
                    _splitPercent = widget.bill.splitPercent.clamp(5, 95).toDouble();
                    _paidBy = widget.bill.paidBy;
                    _selectedCategory = widget.bill.description;
                    _showCategories = false;
                    _showAllCategories = false;
                    _showCustomInput = false;
                  }),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.textMuted),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.textMuted),
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
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                      : const Text(
                          'SAVE',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.accent),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CATEGORY SELECTOR ──────────────────────────────────────

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showCategories = !_showCategories),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(
                color: _showCategories ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(iconForCategory(_selectedCategory),
                    color: colorForCategory(_selectedCategory), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedCategory.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      letterSpacing: 1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _showCategories
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_showCategories) _buildCategoryGrid(),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final visible = _showAllCategories
        ? _sortedCategories
        : _sortedCategories.take(7).toList();

    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showCustomInput = !_showCustomInput),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: AppColors.accent,
              child: const Icon(Icons.add, color: AppColors.background, size: 28),
            ),
          ),
          if (_showCustomInput)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customCategoryController,
                      autofocus: true,
                      maxLength: 50,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Custom category...',
                        hintStyle: TextStyle(
                          fontFamily: 'monospace',
                          color: AppColors.textDim,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: AppColors.accent),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _confirmCustomCategory,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: AppColors.accent,
                      child: const Icon(Icons.check,
                          color: AppColors.background, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final cat = visible[index];
              final isSelected =
                  _selectedCategory.toLowerCase() == cat.toLowerCase();
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    _showCategories = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorForCategory(cat).withValues(alpha: 0.15)
                        : colorForCategory(cat).withValues(alpha: 0.05),
                    border: Border.all(
                      color: isSelected
                          ? colorForCategory(cat)
                          : colorForCategory(cat).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        iconForCategory(cat),
                        color: isSelected
                            ? colorForCategory(cat)
                            : colorForCategory(cat).withValues(alpha: 0.8),
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: isSelected
                              ? colorForCategory(cat)
                              : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_sortedCategories.length > 7)
            GestureDetector(
              onTap: () =>
                  setState(() => _showAllCategories = !_showAllCategories),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: AppColors.accent,
                child: Text(
                  _showAllCategories ? 'SHOW LESS' : 'LOAD MORE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.background,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmCustomCategory() {
    final name = _customCategoryController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      if (!_sortedCategories
          .map((c) => c.toLowerCase())
          .contains(name.toLowerCase())) {
        _sortedCategories.insert(0, name);
      }
      _selectedCategory = name;
      _showCustomInput = false;
      _showCategories = false;
      _customCategoryController.clear();
    });
  }

  Widget _presetBtn(String label, double value) {
    final isActive = (_splitPercent - value).abs() < 1;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _splitPercent = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(color: isActive ? AppColors.accent : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textMuted)),
        Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Future<void> _saveChanges() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);

    final success = await widget.billService.updateBill(
      groupId: widget.groupId,
      billId: widget.bill.id,
      paidBy: _paidBy,
      amount: amount,
      description: _selectedCategory,
      category: _selectedCategory,
      notes: _notesController.text.trim(),
      splitPercent: _splitPercent,
    );

    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        widget.onChanged();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text('Bill updated!', style: TextStyle(fontFamily: 'monospace', color: AppColors.accent)),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('DELETE BILL?', style: TextStyle(fontFamily: 'monospace', letterSpacing: 1, color: AppColors.textPrimary)),
        content: Text(
          '${widget.bill.description} — \$${widget.bill.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontFamily: 'monospace', color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL', style: TextStyle(fontFamily: 'monospace'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(fontFamily: 'monospace', color: AppColors.danger))),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.billService.deleteBill(widget.groupId, widget.bill.id);
      widget.onChanged();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text('Bill deleted', style: TextStyle(fontFamily: 'monospace', color: AppColors.danger)),
          ),
        );
      }
    }
  }
}
