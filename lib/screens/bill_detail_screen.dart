import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/bill_service.dart';

// Category icons (same as add_bill_screen)
IconData _iconForCategory(String name) {
  const map = {
    'food': Icons.restaurant,
    'transport': Icons.directions_car,
    'groceries': Icons.shopping_cart,
    'entertainment': Icons.movie,
    'utilities': Icons.bolt,
    'rent': Icons.home,
    'shopping': Icons.shopping_bag,
    'health': Icons.medical_services,
  };
  return map[name.toLowerCase()] ?? Icons.receipt_long;
}

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
    _category = widget.bill.description;
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

  String _memberName(String uid) {
    for (final m in _members) {
      if (m['uid'] == uid) return m['name'] ?? uid;
    }
    return uid;
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final currentUser = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    final isYourBill = bill.paidBy == currentUser;
    final accentColor =
        isYourBill ? const Color(0xFF00E5CC) : const Color(0xFFFF4C5E);

    final amount = double.tryParse(_amountController.text) ?? bill.amount;
    final owedAmount = isYourBill
        ? amount * (100 - _splitPercent) / 100
        : amount * _splitPercent / 100;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E14),
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
              icon: const Icon(Icons.edit, color: Color(0xFF00E5CC)),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header: icon + category + amount ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141A22),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    _iconForCategory(bill.category.isNotEmpty
                        ? bill.category
                        : bill.description),
                    color: accentColor,
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
                    color: Color(0xFFE0E0E0),
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
                    color: Color(0xFF556677),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Split breakdown ──
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
                  'SPLIT BREAKDOWN',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Color(0xFF8899AA),
                  ),
                ),
                const SizedBox(height: 12),
                _detailRow(
                  'Paid by',
                  _memberName(bill.paidBy),
                  isYourBill
                      ? const Color(0xFF00E5CC)
                      : const Color(0xFFFF4C5E),
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Split',
                  '${bill.splitPercent.round()} / ${(100 - bill.splitPercent).round()}',
                  const Color(0xFFE0E0E0),
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Payer\'s share',
                  '\$${(bill.amount * bill.splitPercent / 100).toStringAsFixed(2)}',
                  const Color(0xFF00E5CC),
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Other\'s share',
                  '\$${(bill.amount * (100 - bill.splitPercent) / 100).toStringAsFixed(2)}',
                  const Color(0xFFFF4C5E),
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

          // ── Notes ──
          if (bill.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141A22),
                border: Border.all(color: const Color(0xFF1E2A35)),
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
                      color: Color(0xFF8899AA),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bill.notes,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFFE0E0E0),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Edit section ──
          if (_editing) ...[
            _buildEditSection(),
            const SizedBox(height: 12),
          ],

          // ── Metadata toggle ──
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

          if (_showMeta) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                border: Border.all(color: const Color(0xFF1E2A35)),
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

          // ── Delete button ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmDelete(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFFF4C5E)),
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
                  color: Color(0xFFFF4C5E),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Edit section ──────────────────────────────────────────

  Widget _buildEditSection() {
    final currentUid = FirebaseAuth.instance.currentUser!.email!.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        border: Border.all(color: const Color(0xFF00E5CC)),
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
              color: Color(0xFF00E5CC),
            ),
          ),
          const SizedBox(height: 12),

          // Amount
          TextFormField(
            controller: _amountController,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 20,
                color: Color(0xFF00E5CC)),
            decoration: const InputDecoration(
              labelText: 'AMOUNT',
              labelStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 1,
                  color: Color(0xFF8899AA)),
              prefixText: '\$ ',
              prefixStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  color: Color(0xFF00E5CC)),
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
                  color: Color(0xFF8899AA),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF00E5CC),
              inactiveTrackColor:
                  const Color(0xFFFF4C5E).withValues(alpha: 0.4),
              thumbColor: const Color(0xFF00E5CC),
              overlayColor: const Color(0xFF00E5CC).withValues(alpha: 0.15),
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
                color: Color(0xFF8899AA),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey(_paidBy),
              initialValue: _members.any((m) => m['uid'] == _paidBy) ? _paidBy : null,
              dropdownColor: const Color(0xFF141A22),
              isExpanded: true,
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
              selectedItemBuilder: (context) {
                return _members.map((m) {
                  final isMe = m['uid'] == currentUid;
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
              items: _members.map((m) {
                final isMe = m['uid'] == currentUid;
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
              onChanged: (val) => setState(() => _paidBy = val!),
            ),
            const SizedBox(height: 12),
          ],

          // Notes
          TextField(
            controller: _notesController,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Color(0xFFE0E0E0),
            ),
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'NOTES',
              labelStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 1,
                color: Color(0xFF8899AA),
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
                    side: const BorderSide(color: Color(0xFF8899AA)),
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
                      color: Color(0xFF8899AA),
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
                    side: const BorderSide(color: Color(0xFF00E5CC)),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF00E5CC)),
                        )
                      : const Text(
                          'SAVE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
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
              color: isActive
                  ? const Color(0xFF00E5CC)
                  : const Color(0xFF8899AA),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  Widget _detailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFF8899AA),
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
              color: Color(0xFF556677),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF141A22),
                  duration: const Duration(seconds: 1),
                  content: Text(
                    'Copied: $label',
                    style: const TextStyle(
                        fontFamily: 'monospace', color: Color(0xFF00E5CC)),
                  ),
                ),
              );
            },
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Color(0xFF8899AA),
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
          backgroundColor: Color(0xFF141A22),
          content: Text(
            'Enter a valid amount',
            style:
                TextStyle(fontFamily: 'monospace', color: Color(0xFFFF4C5E)),
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
            backgroundColor: Color(0xFF141A22),
            content: Text(
              'Bill updated!',
              style:
                  TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5CC)),
            ),
          ),
        );
        Navigator.pop(context, 'updated');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF141A22),
            content: Text(
              'Error updating bill',
              style:
                  TextStyle(fontFamily: 'monospace', color: Color(0xFFFF4C5E)),
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
        backgroundColor: const Color(0xFF141A22),
        shape:
            const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'DELETE BILL?',
          style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1,
              color: Color(0xFFE0E0E0)),
        ),
        content: Text(
          '${widget.bill.description} — \$${widget.bill.amount.toStringAsFixed(2)}',
          style: const TextStyle(
              fontFamily: 'monospace', color: Color(0xFF8899AA)),
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
                    fontFamily: 'monospace', color: Color(0xFFFF4C5E))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.billService.deleteBill(widget.groupId, widget.bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF141A22),
            content: Text(
              'Bill deleted',
              style:
                  TextStyle(fontFamily: 'monospace', color: Color(0xFFFF4C5E)),
            ),
          ),
        );
        Navigator.pop(context, 'deleted');
      }
    }
  }
}
