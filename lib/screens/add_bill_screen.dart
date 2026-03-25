import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/bill_service.dart';

// Default categories with icons
class _Category {
  final String name;
  final IconData icon;
  const _Category(this.name, this.icon);
}

const List<_Category> _defaultCategories = [
  _Category('Food', Icons.restaurant),
  _Category('Transport', Icons.directions_car),
  _Category('Groceries', Icons.shopping_cart),
  _Category('Entertainment', Icons.movie),
  _Category('Utilities', Icons.bolt),
  _Category('Rent', Icons.home),
  _Category('Shopping', Icons.shopping_bag),
  _Category('Health', Icons.medical_services),
];

IconData _iconForCategory(String name) {
  for (final c in _defaultCategories) {
    if (c.name.toLowerCase() == name.toLowerCase()) return c.icon;
  }
  return Icons.receipt_long;
}

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
    _billService = BillService();
    _paidBy = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    _amountController.addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _billService.getGroupCategories(widget.groupId);
    final members = await _billService.getGroupMembers(widget.groupId);

    // Merge: group-used categories first (by frequency), then defaults
    final usedNames = categories.map((c) => c.toLowerCase()).toSet();
    final defaults = _defaultCategories
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
    return Scaffold(
      appBar: AppBar(title: const Text('ADD BILL')),
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
              color: const Color(0xFF141A22),
              border: Border.all(
                color: _showCategories
                    ? const Color(0xFF00E5CC)
                    : const Color(0xFF1E2A35),
              ),
            ),
            child: Row(
              children: [
                if (_selectedCategory != null) ...[
                  Icon(_iconForCategory(_selectedCategory!),
                      color: const Color(0xFF00E5CC), size: 20),
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
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFF8899AA),
                    ),
                  ),
                ),
                Icon(
                  _showCategories
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF8899AA),
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
        border: Border.all(color: const Color(0xFF1E2A35)),
      ),
      child: Column(
        children: [
          // Cyan "+" bar at the top
          GestureDetector(
            onTap: () => setState(() => _showCustomInput = !_showCustomInput),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: const Color(0xFF00E5CC),
              child: const Icon(Icons.add, color: Color(0xFF0A0E14), size: 28),
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
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFFE0E0E0),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Custom category...',
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
                      color: const Color(0xFF00E5CC),
                      child: const Icon(Icons.check,
                          color: Color(0xFF0A0E14), size: 20),
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
                        ? const Color(0xFF00E5CC).withValues(alpha: 0.15)
                        : const Color(0xFF0A0E14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00E5CC)
                          : const Color(0xFF1E2A35),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _iconForCategory(cat),
                        color: isSelected
                            ? const Color(0xFF00E5CC)
                            : Colors.white,
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
                              ? const Color(0xFF00E5CC)
                              : const Color(0xFFE0E0E0),
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
                color: const Color(0xFF00E5CC),
                child: Text(
                  _showAllCategories ? 'SHOW LESS' : 'LOAD MORE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A0E14),
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

  // ── AMOUNT FIELD ───────────────────────────────────────────

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      style: const TextStyle(
          fontFamily: 'monospace', fontSize: 20, color: Color(0xFF00E5CC)),
      decoration: const InputDecoration(
        labelText: 'AMOUNT',
        labelStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            letterSpacing: 1,
            color: Color(0xFF8899AA)),
        hintText: '0.00',
        hintStyle: TextStyle(fontFamily: 'monospace', color: Color(0xFF455566)),
        prefixText: '\$ ',
        prefixStyle: TextStyle(
            fontFamily: 'monospace', fontSize: 20, color: Color(0xFF00E5CC)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF1E2A35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF00E5CC)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFFFF4C5E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFFFF4C5E)),
        ),
        filled: true,
        fillColor: Color(0xFF141A22),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value?.isEmpty ?? true) return 'Enter an amount';
        final parsed = double.tryParse(value!);
        if (parsed == null || parsed <= 0) return 'Enter a valid amount';
        return null;
      },
    );
  }

  // ── WHO PAID DROPDOWN ──────────────────────────────────────

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
          color: const Color(0xFF141A22),
          border: Border.all(
            color: _splitExpanded
                ? const Color(0xFF00E5CC)
                : const Color(0xFF1E2A35),
          ),
        ),
        child: Column(
          children: [
            // ── Collapsed header (always visible) ──
            GestureDetector(
              onTap: () => setState(() => _splitExpanded = !_splitExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                color: Colors.transparent,
                child: Row(
                  children: [
                    const Icon(Icons.pie_chart_outline,
                        color: Color(0xFF8899AA), size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'SPLIT',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        letterSpacing: 1,
                        color: Color(0xFF8899AA),
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
                            ? const Color(0xFFE0E0E0)
                            : const Color(0xFF00E5CC),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _splitExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFF8899AA),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded details ──
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
                          '${_splitPercent.round()}%  •  \$${payerShare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5CC),
                          ),
                        ),
                        Text(
                          '\$${otherShare.toStringAsFixed(2)}  •  ${(100 - _splitPercent).round()}%',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF4C5E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Slider
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF00E5CC),
                        inactiveTrackColor: const Color(0xFFFF4C5E).withValues(alpha: 0.4),
                        thumbColor: const Color(0xFF00E5CC),
                        overlayColor: const Color(0xFF00E5CC).withValues(alpha: 0.15),
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
            final currentEmail = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
            if (value >= 100) {
              _paidBy = currentEmail;
            } else if (value <= 0 && _members.length >= 2) {
              final other = _members.firstWhere(
                (m) => m['uid'] != currentEmail,
                orElse: () => _members.first,
              );
              _paidBy = other['uid'];
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: isActive
                  ? const Color(0xFF00E5CC)
                  : const Color(0xFF8899AA),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWhoPaidDropdown() {
    final currentEmail = FirebaseAuth.instance.currentUser!.email!.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        border: Border.all(color: const Color(0xFF1E2A35)),
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
              color: Color(0xFF8899AA),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_paidBy),
            initialValue: _members.any((m) => m['uid'] == _paidBy) ? _paidBy : null,
            dropdownColor: const Color(0xFF141A22),
            style: const TextStyle(
                fontFamily: 'monospace', color: Color(0xFFE0E0E0)),
            decoration: const InputDecoration(
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
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            isExpanded: true,
            selectedItemBuilder: (context) {
              return _members.isEmpty
                  ? []
                  : _members.map((m) {
                      final isMe = m['uid'] == currentEmail;
                      final email = m['email'] ?? '';
                      final showEmail = email.isNotEmpty && email != m['name'];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isMe
                                ? '${m['name']!.toUpperCase()} (YOU)'
                                : m['name']!.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          if (showEmail)
                            Text(
                              email,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Color(0xFF556677),
                              ),
                            ),
                        ],
                      );
                    }).toList();
            },
            items: _members.isEmpty
                ? []
                : _members.map((m) {
                    final isMe = m['uid'] == currentEmail;
                    final showEmail = m['email']!.isNotEmpty && m['email'] != m['name'];
                    return DropdownMenuItem(
                      value: m['uid'],
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
                                color: Color(0xFF556677),
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

  // ── NOTES FIELD ────────────────────────────────────────────

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: Color(0xFFE0E0E0),
      ),
      maxLines: 3,
      minLines: 1,
      decoration: const InputDecoration(
        labelText: 'NOTES (OPTIONAL)',
        labelStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          letterSpacing: 1,
          color: Color(0xFF8899AA),
        ),
        hintText: 'Add a note...',
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
        fillColor: Color(0xFF141A22),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ── DATE PICKER ────────────────────────────────────────────

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141A22),
          border: Border.all(color: const Color(0xFF1E2A35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: Color(0xFF8899AA), size: 18),
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
                    color: Color(0xFF8899AA),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy — h:mm a').format(_selectedDate),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Color(0xFFE0E0E0),
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit, color: Color(0xFF00E5CC), size: 16),
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
              primary: Color(0xFF00E5CC),
              surface: Color(0xFF141A22),
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
              primary: Color(0xFF00E5CC),
              surface: Color(0xFF141A22),
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

  // ── ADD BUTTON ─────────────────────────────────────────────

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _saveBill,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFF00E5CC)),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF00E5CC)),
              )
            : const Text(
                'ADD BILL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Color(0xFF00E5CC),
                ),
              ),
      ),
    );
  }

  Future<void> _saveBill() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF141A22),
          content: Text(
            'Please select a category',
            style: TextStyle(fontFamily: 'monospace', color: Color(0xFFFF4C5E)),
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
            backgroundColor: Color(0xFF141A22),
            content: Text(
              'Bill added!',
              style:
                  TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5CC)),
            ),
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF141A22),
            content: Text(
              'Error adding bill',
              style:
                  TextStyle(fontFamily: 'monospace', color: Color(0xFFFF4C5E)),
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
