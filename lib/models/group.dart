// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final List<String> members;
  final DateTime createdAt;
  final String createdBy;
  final String icon;
  final String color;
  final String? customImage;

  Group({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
    required this.createdBy,
    this.icon = 'group',
    this.color = '00E5CC',
    this.customImage,
  });

  factory Group.fromMap(Map<String, dynamic> map, String id) {
    return Group(
      id: id,
      name: map['name'] as String? ?? 'Unnamed Group',
      members: List<String>.from(map['members'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: map['createdBy'] as String,
      icon: map['icon'] as String? ?? 'group',
      color: map['color'] as String? ?? '00E5CC',
      customImage: map['customImage'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'icon': icon,
      'color': color,
    };
    if (customImage != null) map['customImage'] = customImage;
    return map;
  }
}
