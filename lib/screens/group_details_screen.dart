import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
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

  static const _groupIcons = <String, IconData>{
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

  static const _groupColors = <String, Color>{
    '00E5CC': Color(0xFF00E5CC),
    'FF6B9D': Color(0xFFFF6B9D),
    '7B68EE': Color(0xFF7B68EE),
    'FFA726': Color(0xFFFFA726),
    '42A5F5': Color(0xFF42A5F5),
    'EF5350': Color(0xFFEF5350),
    '66BB6A': Color(0xFF66BB6A),
    'FFEE58': Color(0xFFFFEE58),
    'AB47BC': Color(0xFFAB47BC),
    'FF7043': Color(0xFFFF7043),
    '26C6DA': Color(0xFF26C6DA),
    'EC407A': Color(0xFFEC407A),
  };

  IconData _groupIcon(String key) => _groupIcons[key] ?? Icons.group;
  Color _groupColor(String hex) => _groupColors[hex] ?? const Color(0xFF00E5CC);

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

  void _showAppearanceDialog() {
    if (_group == null) return;
    var selectedIcon = _group!.icon;
    var selectedColor = _group!.color;
    String? pendingImage = _group!.customImage;
    var clearImage = false;

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
                  Navigator.pop(ctx);
                  final success = await _billService.updateGroupAppearance(
                    widget.groupId,
                    icon: selectedIcon,
                    color: selectedColor,
                    customImage: (pendingImage != null && !clearImage) ? pendingImage : null,
                    clearImage: clearImage,
                  );
                  if (mounted && success) {
                    _loadData(); // Refresh to show changes
                  }
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
                        onPressed: _showAppearanceDialog,
                        icon: const Icon(Icons.palette, size: 18),
                        label: const Text(
                          'CHANGE APPEARANCE',
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
