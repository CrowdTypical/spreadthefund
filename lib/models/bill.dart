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
    );
  }
}
