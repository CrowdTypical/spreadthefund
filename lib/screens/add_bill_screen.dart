// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bill_service.dart';
import '../constants/theme_constants.dart';

class AddBillScreen extends StatefulWidget {
  final String groupId;

  const AddBillScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCategoryController = TextEditingController();
  late BillService _billService;

  String? _selectedCategory;
  String? _paidBy;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _showCategories = false;
  bool _showAllCategories = false;
  bool _showCustomInput = false;
  double _splitPercent = 50.0;
  bool _splitExpanded = false;

  List<String> _sortedCategories = [];
  List<Map<String, String>> _members = [];

  @override
  void initState() {
    super.initState();
    _billService = context.read<BillService>();
    _paidBy = context.read<AuthService>().currentUser!.email!.toLowerCase();
    _amountController.addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _billService.getGroupCategories(widget.groupId);
    final members = await _billService.getGroupMembers(widget.groupId);

    // Merge: group-used categories first (by frequency), then defaults
    final usedNames = categories.map((c) => c.toLowerCase()).toSet();
    final defaults = defaultCategories
        .where((c) => !usedNames.contains(c.name.toLowerCase()))
        .map((c) => c.name)
        .toList();

    setState(() {
      _sortedCategories = [...categories, ...defaults];
      _members = members;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ADD BILL'),
        leading: routeAnimation != null
            ? AnimatedBuilder(
                animation: routeAnimation,
                builder: (context, child) {
                  // Complete the flip in the first half of the route animation
                  final raw = (1.0 - routeAnimation.value).clamp(0.0, 1.0);
                  final t = (raw * 2.0).clamp(0.0, 1.0);
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(t * math.pi),
                    child: child,
                  );
                },
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.maybePop(context),
                ),
              )
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          children: [
            _buildCategorySelector(),
            const SizedBox(height: 10),
            _buildAmountField(),
            _buildSplitSlider(),
            const SizedBox(height: 10),
            _buildWhoPaidDropdown(),
            const SizedBox(height: 10),
            _buildNotesField(),
            const SizedBox(height: 10),
            _buildDatePicker(),
            const SizedBox(height: 18),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  // â”€â”€ CATEGORY SELECTOR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                color: _showCategories
                    ? AppColors.accent
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                if (_selectedCategory != null) ...[
                  Icon(iconForCategory(_selectedCategory!),
                      color: colorForCategory(_selectedCategory!), size: 20),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    _selectedCategory?.toUpperCase() ?? 'DESCRIPTION',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      letterSpacing: 1,
                      color: _selectedCategory != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
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
    // Show 7 items + "Other" tile = 8 (2×4 grid), or all if expanded
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
          // Cyan "+" bar at the top
          GestureDetector(
            onTap: () => setState(() => _showCustomInput = !_showCustomInput),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: AppColors.accent,
              child: const Icon(Icons.add, color: AppColors.background, size: 28),
            ),
          ),

          // Custom category input
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

          // Grid of category tiles
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
                  _selectedCategory?.toLowerCase() == cat.toLowerCase();
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

          // Load More / Show Less (only if more than 7 categories)
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

  // â”€â”€ AMOUNT FIELD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      maxLength: 12,
      style: const TextStyle(
          fontFamily: 'monospace', fontSize: 20, color: AppColors.accent),
      decoration: const InputDecoration(
        labelText: 'AMOUNT',
        labelStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            letterSpacing: 1,
            color: AppColors.textMuted),
        hintText: '0.00',
        hintStyle: TextStyle(fontFamily: 'monospace', color: Color(0xFF455566)),
        prefixText: '\$ ',
        prefixStyle: TextStyle(
            fontFamily: 'monospace', fontSize: 20, color: AppColors.accent),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        filled: true,
        fillColor: AppColors.surface,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value?.isEmpty ?? true) return 'Enter an amount';
        final parsed = double.tryParse(value!);
        if (parsed == null || parsed <= 0) return 'Enter a valid amount';
        return null;
      },
    );
  }

  // â”€â”€ WHO PAID DROPDOWN â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSplitSlider() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return const SizedBox.shrink();

    final payerShare = amount * _splitPercent / 100;
    final otherShare = amount - payerShare;
    final splitLabel = '${_splitPercent.round()}/${(100 - _splitPercent).round()}';

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: _splitExpanded
                ? AppColors.accent
                : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            // â”€â”€ Collapsed header (always visible) â”€â”€
            GestureDetector(
              onTap: () => setState(() => _splitExpanded = !_splitExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                color: Colors.transparent,
                child: Row(
                  children: [
                    const Icon(Icons.pie_chart_outline,
                        color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'SPLIT',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        letterSpacing: 1,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      splitLabel,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: (_splitPercent - 50).abs() < 1
                            ? AppColors.textPrimary
                            : AppColors.accent,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _splitExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Expanded details â”€â”€
            if (_splitExpanded) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    // Payer / Other labels with amounts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_splitPercent.round()}%  â€¢  \$${payerShare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                        Text(
                          '\$${otherShare.toStringAsFixed(2)}  â€¢  ${(100 - _splitPercent).round()}%',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Slider
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
                    // Quick-select buttons
                    Row(
                      children: [
                        _splitPresetButton('70/30', 70),
                        const SizedBox(width: 6),
                        _splitPresetButton('50/50', 50),
                        const SizedBox(width: 6),
                        _splitPresetButton('30/70', 30),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _splitPresetButton(String label, double value) {
    final isActive = (_splitPercent - value).abs() < 1;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _splitPercent = value;
            // Auto-switch Who Paid for the full-pay presets
            final currentEmail = context.read<AuthService>().currentUser!.email!.toLowerCase();
            if (value >= 100) {
              _paidBy = currentEmail;
            } else if (value <= 0 && _members.length >= 2) {
              final other = _members.firstWhere(
                (m) => m['email'] != currentEmail,
                orElse: () => _members.first,
              );
              _paidBy = other['email'];
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
              letterSpacing: 0.5,
              color: isActive
                  ? AppColors.accent
                  : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWhoPaidDropdown() {
    final currentEmail = context.read<AuthService>().currentUser!.email!.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHO PAID?',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_paidBy),
            initialValue: _members.any((m) => m['email'] == _paidBy) ? _paidBy : null,
            dropdownColor: AppColors.surface,
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
            isExpanded: true,
            selectedItemBuilder: (context) {
              return _members.isEmpty
                  ? []
                  : _members.map((m) {
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
            items: _members.isEmpty
                ? []
                : _members.map((m) {
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
            onChanged: (val) => setState(() => _paidBy = val),
          ),
        ],
      ),
    );
  }

  // â”€â”€ NOTES FIELD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildNotesField() {
    return TextField(
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
        labelText: 'NOTES (OPTIONAL)',
        labelStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          letterSpacing: 1,
          color: AppColors.textMuted,
        ),
        hintText: 'Add a note...',
        hintStyle: TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFF455566),
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
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // â”€â”€ DATE PICKER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: AppColors.textMuted, size: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DATE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy — h:mm a').format(_selectedDate),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit, color: AppColors.accent, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _selectedDate.hour,
        time?.minute ?? _selectedDate.minute,
      );
    });
  }

  // â”€â”€ ADD BUTTON â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _saveBill,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.accent),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              )
            : const Text(
                'ADD BILL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.accent,
                ),
              ),
      ),
    );
  }

  Future<void> _saveBill() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Please select a category',
            style: TextStyle(fontFamily: 'monospace', color: AppColors.danger),
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);

      final success = await _billService.addBill(
        groupId: widget.groupId,
        paidBy: _paidBy!,
        amount: amount,
        description: _selectedCategory!,
        category: _selectedCategory!,
        notes: _notesController.text.trim(),
        splitPercent: _splitPercent,
        date: _selectedDate,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Bill added!',
              style:
                  TextStyle(fontFamily: 'monospace', color: AppColors.accent),
            ),
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Error adding bill',
              style:
                  TextStyle(fontFamily: 'monospace', color: AppColors.danger),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
