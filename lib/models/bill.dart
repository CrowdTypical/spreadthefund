// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:cloud_firestore/cloud_firestore.dart';

class Bill {
  final String id;
  final String paidBy;
  final double amount;
  final String description;
  final String category;
  final String notes;
  final double splitPercent;
  final DateTime createdAt;
  final bool settled;
  final String? createdBy;

  Bill({
    required this.id,
    required this.paidBy,
    required this.amount,
    required this.description,
    required this.category,
    this.notes = '',
    this.splitPercent = 50.0,
    required this.createdAt,
    required this.settled,
    this.createdBy,
  });

  factory Bill.fromMap(Map<String, dynamic> map, String id) {
    return Bill(
      id: id,
      paidBy: map['paidBy'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      category: map['category'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      splitPercent: (map['splitPercent'] as num?)?.toDouble() ?? 50.0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      settled: map['settled'] ?? false,
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'paidBy': paidBy,
        'amount': amount,
        'description': description,
        'category': category,
        'notes': notes,
        'splitPercent': splitPercent,
        'createdAt': Timestamp.fromDate(createdAt),
        'settled': settled,
        if (createdBy != null) 'createdBy': createdBy,
      };
}
