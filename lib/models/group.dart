import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final List<dynamic> members;
  final DateTime createdAt;
  final String createdBy;

  Group({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
    required this.createdBy,
  });

  factory Group.fromMap(Map<String, dynamic> map, String id) {
    return Group(
      id: id,
      name: map['name'] as String? ?? 'Unnamed Group',
      members: map['members'] as List,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: map['createdBy'] as String,
    );
  }
}
