// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/bill.dart';
import '../models/group.dart';

class BillService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Invites ──────────────────────────────────────────────────────

  // Create a pending invite (stored by email so it works before they sign up)
  Future<bool> createInvite({
    required String groupId,
    required String groupName,
    required String inviterUid,
    required String inviterName,
    required String inviterEmail,
    required String inviteeEmail,
  }) async {
    try {
      await _firestore.collection('invites').add({
        'groupId': groupId,
        'groupName': groupName,
        'inviterUid': inviterUid,
        'inviterName': inviterName,
        'inviterEmail': inviterEmail.toLowerCase(),
        'inviteeEmail': inviteeEmail.toLowerCase(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) log('Error creating invite: $e');
      return false;
    }
  }

  // Count pending invites for a user (no longer auto-accepts).
  Future<int> countPendingInvites(String email) async {
    try {
      final normalizedEmail = email.toLowerCase();
      final snapshot = await _firestore
          .collection('invites')
          .where('inviteeEmail', isEqualTo: normalizedEmail)
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) log('Error counting invites: $e');
      return 0;
    }
  }

  // Real-time stream of pending invites received by this user.
  Stream<List<Map<String, dynamic>>> getReceivedPendingInvitesStream(String email) {
    return _firestore
        .collection('invites')
        .where('inviteeEmail', isEqualTo: email.toLowerCase())
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  // Real-time stream of pending invites sent by this user.
  Stream<List<Map<String, dynamic>>> getSentPendingInvitesStream(String uid) {
    return _firestore
        .collection('invites')
        .where('inviterUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  // Accept a pending invite (member is already in the group).
  Future<void> acceptInvite(String inviteId) async {
    try {
      await _firestore.collection('invites').doc(inviteId).update({
        'status': 'accepted',
      });
      if (kDebugMode) log('Accepted invite $inviteId');
    } catch (e) {
      if (kDebugMode) log('Error accepting invite: $e');
    }
  }

  // Decline a pending invite (removes member from the group).
  Future<void> declineInvite(String inviteId, String groupId, String email) async {
    try {
      await _firestore.collection('invites').doc(inviteId).delete();
      await removeMemberFromGroup(groupId, email.toLowerCase());
      if (kDebugMode) log('Declined invite $inviteId, removed from group $groupId');
    } catch (e) {
      if (kDebugMode) log('Error declining invite: $e');
    }
  }

  // When a user signs in, find every group that has their UID in the
  // members list and swap it for their email (backwards compat migration).
  Future<void> migrateUidToEmail(String uid, String email) async {
    try {
      final normalizedEmail = email.toLowerCase();
      if (kDebugMode) log('Migrating UID $uid → email $normalizedEmail in groups');

      final groups = await _firestore
          .collection('groups')
          .where('members', arrayContains: uid)
          .get();

      if (kDebugMode) log('Found ${groups.docs.length} group(s) with UID in members');

      for (final doc in groups.docs) {
        await _firestore.runTransaction((transaction) async {
          final freshSnap = await transaction.get(doc.reference);
          final members = List<String>.from(freshSnap.data()?['members'] ?? []);
          if (members.contains(uid)) {
            members.remove(uid);
            if (!members.contains(normalizedEmail)) {
              members.add(normalizedEmail);
            }
            transaction.update(doc.reference, {'members': members});
          }
        });
        if (kDebugMode) log('Migrated group ${doc.id}: $uid → $normalizedEmail');
      }
    } catch (e) {
      if (kDebugMode) log('Error migrating UID to email: $e');
    }
  }

  // ── Groups ───────────────────────────────────────────────────────

  // Create a personal group (solo user, partners can be added later)
  Future<String?> createPersonalGroup(String userEmail) async {
    try {
      final docRef = await _firestore.collection('groups').add({
        'name': 'Personal',
        'members': [userEmail.toLowerCase()],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userEmail.toLowerCase(),
        'icon': 'person',
        'color': '00E5CC',
      });
      return docRef.id;
    } catch (e) {
      if (kDebugMode) log('Error creating personal group: $e');
      return null;
    }
  }

  // Create a bill group with a partner (by email)
  Future<String?> createBillGroup(String userEmail, String partnerEmail) async {
    try {
      final docRef = await _firestore.collection('groups').add({
        'name': 'Group',
        'members': [userEmail.toLowerCase(), partnerEmail.toLowerCase()],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userEmail.toLowerCase(),
      });
      return docRef.id;
    } catch (e) {
      if (kDebugMode) log('Error creating bill group: $e');
      return null;
    }
  }

  // Create a named group
  Future<String?> createNamedGroup(String userEmail, String name, {String icon = 'group', String color = '00E5CC'}) async {
    try {
      final docRef = await _firestore.collection('groups').add({
        'name': name,
        'members': [userEmail.toLowerCase()],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userEmail.toLowerCase(),
        'icon': icon,
        'color': color,
      });
      return docRef.id;
    } catch (e) {
      if (kDebugMode) log('Error creating named group: $e');
      return null;
    }
  }

  // Maximum number of members allowed per group
  static const int maxGroupMembers = 2;

  // Add a member to an existing group (by email)
  Future<bool> addMemberToGroup(String groupId, String memberEmail) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      final members = (doc.data()?['members'] as List?) ?? [];
      if (members.length >= maxGroupMembers) {
        if (kDebugMode) log('Group already has $maxGroupMembers members');
        return false;
      }
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([memberEmail.toLowerCase()]),
      });
      return true;
    } catch (e) {
      if (kDebugMode) log('Error adding member: $e');
      return false;
    }
  }

  // Remove a member from a group
  Future<bool> removeMemberFromGroup(String groupId, String memberEmail) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([memberEmail.toLowerCase()]),
      });
      return true;
    } catch (e) {
      if (kDebugMode) log('Error removing member: $e');
      return false;
    }
  }

  // Add a bill to the group
  Future<bool> addBill({
    required String groupId,
    required String paidBy,
    required double amount,
    required String description,
    required String category,
    String notes = '',
    double splitPercent = 50.0,
    DateTime? date,
    String? createdBy,
  }) async {
    try {
      final bill = Bill(
        id: '',
        paidBy: paidBy,
        amount: amount,
        description: description,
        category: category,
        notes: notes,
        splitPercent: splitPercent,
        createdAt: date ?? DateTime.now(),
        settled: false,
        createdBy: createdBy,
      );
      final data = bill.toMap();
      data['splitEquallyWith'] = 'both';
      if (date == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await _firestore.collection('groups').doc(groupId).collection('bills').add(data);

      // Mark as seen so the creator's own bill doesn't show as unseen
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await updateLastSeen(groupId, uid);
      }

      // Track the category usage for this group
      final catRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('categories')
          .doc(category.toLowerCase());
      await catRef.set({
        'name': category,
        'count': FieldValue.increment(1),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      if (kDebugMode) log('Error adding bill: $e');
      return false;
    }
  }

  // Get custom categories for a group, ordered by usage
  Future<List<String>> getGroupCategories(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('categories')
          .orderBy('count', descending: true)
          .get();
      return snapshot.docs.map((doc) => doc['name'] as String).toList();
    } catch (e) {
      if (kDebugMode) log('Error getting categories: $e');
      return [];
    }
  }

  // Get group members with their display info.
  // Members are stored as emails in the group.
  Future<List<Map<String, String>>> getGroupMembers(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final members = List<String>.from(groupDoc.data()?['members'] ?? []);
      final emails = members.map((m) => m.toLowerCase()).toList();
      final result = <Map<String, String>>[];

      // Batch-lookup all members in one query (Firestore whereIn supports up to 30)
      final userDocs = <String, Map<String, dynamic>>{};
      if (emails.isNotEmpty) {
        final userSnap = await _firestore
            .collection('users')
            .where('email', whereIn: emails)
            .get();
        for (final doc in userSnap.docs) {
          final data = doc.data();
          final docEmail = (data['email'] as String?)?.toLowerCase();
          if (docEmail != null) userDocs[docEmail] = data;
        }
      }

      for (final email in emails) {
        final data = userDocs[email];
        if (data != null) {
          final username = data['username'] as String?;
          final displayName = data['displayName'] as String?;
          final name = (username != null && username.isNotEmpty)
              ? username
              : (displayName != null && displayName.isNotEmpty)
                  ? displayName
                  : email.split('@').first;
          result.add({
            'name': name,
            'email': email,
          });
        } else {
          // No account yet — show email as pending
          result.add({
            'name': email,
            'email': email,
            'pending': 'true',
          });
        }
      }
      return result;
    } catch (e) {
      if (kDebugMode) log('Error getting group members: $e');
      return [];
    }
  }

  // Get bills for a group (real-time)
  Stream<List<Bill>> getBillsStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('bills')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Bill.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Get groups for a user (by email)
  Stream<List<Group>> getUserGroupsStream(String userEmail) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userEmail.toLowerCase())
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Group.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Get user by email (case-insensitive)
  Future<String?> getUserIdByEmail(String email) async {
    try {
      final normalizedEmail = email.toLowerCase();
      if (kDebugMode) log('Searching for user with email: $normalizedEmail');
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (kDebugMode) log('Query returned ${snapshot.docs.length} results');
      for (var doc in snapshot.docs) {
        if (kDebugMode) log('Found user doc: ${doc.id} => ${doc.data()}');
      }

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      if (kDebugMode) log('Error getting user by email: $e');
      return null;
    }
  }



  // Rename a group
  Future<bool> renameGroup(String groupId, String newName) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'name': newName,
      });
      return true;
    } catch (e) {
      if (kDebugMode) log('Error renaming group: $e');
      return false;
    }
  }

  // Upload group image to Firebase Storage and return download URL
  Future<String?> uploadGroupImage(String groupId, String uid, Uint8List bytes) async {
    try {
      final ref = _storage.ref().child('group_images/$groupId/$uid.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) log('Error uploading group image: $e');
      return null;
    }
  }

  // Update group icon and color
  Future<bool> updateGroupAppearance(String groupId, {String? icon, String? color, String? customImage, bool clearImage = false}) async {
    try {
      final data = <String, dynamic>{};
      if (icon != null) data['icon'] = icon;
      if (color != null) data['color'] = color;
      if (customImage != null) data['customImage'] = customImage;
      if (clearImage) data['customImage'] = FieldValue.delete();
      if (data.isEmpty) return true;
      await _firestore.collection('groups').doc(groupId).update(data);
      return true;
    } catch (e) {
      if (kDebugMode) log('Error updating group appearance: $e');
      return false;
    }
  }

  // Delete a group and all its subcollections using batched writes
  Future<bool> deleteGroup(String groupId) async {
    try {
      final groupRef = _firestore.collection('groups').doc(groupId);

      // Collect all subcollection docs to delete
      final bills = await groupRef.collection('bills').get();
      final settlements = await groupRef.collection('settlements').get();
      final categories = await groupRef.collection('categories').get();

      final allDocs = [
        ...bills.docs,
        ...settlements.docs,
        ...categories.docs,
      ];

      // Firestore batches support max 500 operations
      const batchLimit = 500;
      for (var i = 0; i < allDocs.length; i += batchLimit) {
        final batch = _firestore.batch();
        final chunk = allDocs.skip(i).take(batchLimit);
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Delete the group document itself
      await groupRef.delete();
      return true;
    } catch (e) {
      if (kDebugMode) log('Error deleting group: $e');
      return false;
    }
  }

  // Update a bill
  Future<bool> updateBill({
    required String groupId,
    required String billId,
    required String paidBy,
    required double amount,
    required String description,
    required String category,
    String notes = '',
    double splitPercent = 50.0,
  }) async {
    try {
      final data = {
        'paidBy': paidBy,
        'amount': amount,
        'description': description,
        'category': category,
        'notes': notes,
        'splitPercent': splitPercent,
      };
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('bills')
          .doc(billId)
          .update(data);
      return true;
    } catch (e) {
      if (kDebugMode) log('Error updating bill: $e');
      return false;
    }
  }

  // Delete a bill
  Future<bool> deleteBill(String groupId, String billId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('bills')
          .doc(billId)
          .delete();
      return true;
    } catch (e) {
      if (kDebugMode) log('Error deleting bill: $e');
      return false;
    }
  }

  // Settle up (record payment)
  Future<bool> settleUp({
    required String groupId,
    required String from,
    required String to,
    required double amount,
    String paymentMethod = '',
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).collection('settlements').add({
        'from': from,
        'to': to,
        'amount': amount,
        'settledAt': Timestamp.now(),
        'paymentMethod': paymentMethod,
      });

      // Mark as seen so the creator's own settlement doesn't show as unseen
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await updateLastSeen(groupId, uid);
      }

      return true;
    } catch (e) {
      if (kDebugMode) log('Error settling up: $e');
      return false;
    }
  }

  // Get settlements for a group
  Stream<QuerySnapshot> getSettlementsStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .orderBy('settledAt', descending: true)
        .snapshots();
  }

  // Update a settlement
  Future<bool> updateSettlement({
    required String groupId,
    required String settlementId,
    required double amount,
    String paymentMethod = '',
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .doc(settlementId)
          .update({
        'amount': amount,
        'paymentMethod': paymentMethod,
      });
      return true;
    } catch (e) {
      if (kDebugMode) log('Error updating settlement: $e');
      return false;
    }
  }

  // Delete a settlement
  Future<bool> deleteSettlement({
    required String groupId,
    required String settlementId,
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .doc(settlementId)
          .delete();
      return true;
    } catch (e) {
      if (kDebugMode) log('Error deleting settlement: $e');
      return false;
    }
  }

  // Bulk delete bills and settlements
  Future<bool> bulkDeleteActivity({
    required String groupId,
    required Set<String> billIds,
    required Set<String> settlementIds,
  }) async {
    try {
      final allIds = <DocumentReference>[];
      for (final id in billIds) {
        allIds.add(_firestore.collection('groups').doc(groupId).collection('bills').doc(id));
      }
      for (final id in settlementIds) {
        allIds.add(_firestore.collection('groups').doc(groupId).collection('settlements').doc(id));
      }

      const batchLimit = 500;
      for (var i = 0; i < allIds.length; i += batchLimit) {
        final batch = _firestore.batch();
        final chunk = allIds.skip(i).take(batchLimit);
        for (final ref in chunk) {
          batch.delete(ref);
        }
        await batch.commit();
      }
      return true;
    } catch (e) {
      if (kDebugMode) log('Error bulk deleting activity: $e');
      return false;
    }
  }

  /// Delete all data associated with a user:
  /// - Remove from groups (delete group if sole member)
  /// - Delete invites (sent and received)
  /// - Delete feedback
  /// - Delete user document
  Future<bool> deleteAllUserData(String email, String uid) async {
    final normalizedEmail = email.toLowerCase();
    var success = true;

    // 1. Handle groups
    try {
      final groupsSnap = await _firestore
          .collection('groups')
          .where('members', arrayContains: normalizedEmail)
          .get();

      for (final doc in groupsSnap.docs) {
        final members = List<String>.from(doc.data()['members'] ?? []);
        if (members.length <= 1) {
          // Sole member — delete the entire group and subcollections
          await deleteGroup(doc.id);
        } else {
          // Collect user's bills and settlements in this shared group
          final bills = await doc.reference
              .collection('bills')
              .where('paidBy', isEqualTo: normalizedEmail)
              .get();
          final settlementsFrom = await doc.reference
              .collection('settlements')
              .where('from', isEqualTo: normalizedEmail)
              .get();
          final settlementsTo = await doc.reference
              .collection('settlements')
              .where('to', isEqualTo: normalizedEmail)
              .get();

          final allDocs = [
            ...bills.docs,
            ...settlementsFrom.docs,
            ...settlementsTo.docs,
          ];

          const batchLimit = 500;
          for (var i = 0; i < allDocs.length; i += batchLimit) {
            final batch = _firestore.batch();
            final chunk = allDocs.skip(i).take(batchLimit);
            for (final d in chunk) {
              batch.delete(d.reference);
            }
            await batch.commit();
          }

          // Remove user from the group
          await doc.reference.update({
            'members': FieldValue.arrayRemove([normalizedEmail]),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) log('Error deleting groups: $e');
      success = false;
    }

    // 2. Delete invites and feedback
    try {
      final invitesReceived = await _firestore
          .collection('invites')
          .where('inviteeEmail', isEqualTo: normalizedEmail)
          .get();
      final invitesSent = await _firestore
          .collection('invites')
          .where('inviterUid', isEqualTo: uid)
          .get();
      final feedbackSnap = await _firestore
          .collection('feedback')
          .where('email', isEqualTo: normalizedEmail)
          .get();

      final allDocs = [
        ...invitesReceived.docs,
        ...invitesSent.docs,
        ...feedbackSnap.docs,
      ];

      const batchLimit = 500;
      for (var i = 0; i < allDocs.length; i += batchLimit) {
        final batch = _firestore.batch();
        final chunk = allDocs.skip(i).take(batchLimit);
        for (final d in chunk) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) log('Error deleting invites/feedback: $e');
      success = false;
    }

    // 3. Delete user document
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      if (kDebugMode) log('Error deleting user document: $e');
      success = false;
    }

    return success;
  }

  /// Compute net balance from bills and settlements.
  /// Returns positive = you owe, negative = you are owed.
  static double computeNetBalance({
    required List<Bill> bills,
    required List<Map<String, dynamic>> settlements,
    required String userEmail,
  }) {
    double totalYouOwe = 0;
    double totalTheyOwe = 0;
    for (final bill in bills) {
      final otherOwes = bill.amount * (100 - bill.splitPercent) / 100;
      if (bill.paidBy == userEmail) {
        totalTheyOwe += otherOwes;
      } else {
        totalYouOwe += otherOwes;
      }
    }

    double settledByYou = 0;
    double settledByThem = 0;
    for (final s in settlements) {
      final amount = (s['amount'] as num?)?.toDouble() ?? 0;
      final from = s['from'] as String? ?? '';
      if (from == userEmail) {
        settledByYou += amount;
      } else {
        settledByThem += amount;
      }
    }

    final rawDifference = totalYouOwe - totalTheyOwe;
    final result = rawDifference + settledByThem - settledByYou;
    return double.parse(result.toStringAsFixed(2));
  }

  /// Compute running balance at each settlement point in a timeline.
  /// Modifies timeline items in-place, adding 'remainingAtTime' to settlements.
  /// Timeline should be sorted newest-first; this reverses internally.
  static void computeRunningBalances({
    required List<Map<String, dynamic>> timeline,
    required String userEmail,
  }) {
    double runningOwed = 0;
    double runningSettled = 0;
    final chronological = List<Map<String, dynamic>>.from(timeline.reversed);
    for (final item in chronological) {
      if (item['type'] == 'bill') {
        final bill = item['data'] as Bill;
        final otherOwes = bill.amount * (100 - bill.splitPercent) / 100;
        if (bill.paidBy == userEmail) {
          runningOwed -= otherOwes; // they owe you
        } else {
          runningOwed += otherOwes; // you owe them
        }
      } else {
        runningSettled += item['amount'] as double;
        final remaining = (runningOwed.abs() - runningSettled).clamp(0.0, double.infinity);
        item['remainingAtTime'] = remaining;
      }
    }
  }

  /// Returns a real-time stream of the net balance for [userEmail] in [groupId].
  /// Positive = you owe, Negative = you are owed.
  Stream<double> getGroupBalanceStream(String groupId, String userEmail) {
    final billStream = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('bills')
        .snapshots();
    final settlementStream = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .snapshots();

    // Combine both streams; re-evaluate whenever either emits
    List<QueryDocumentSnapshot>? lastBills;
    List<QueryDocumentSnapshot>? lastSettlements;

    double compute() {
      final bills = (lastBills ?? <QueryDocumentSnapshot>[])
          .map((doc) => Bill.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      final settlements = (lastSettlements ?? <QueryDocumentSnapshot>[])
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      return computeNetBalance(
        bills: bills,
        settlements: settlements,
        userEmail: userEmail,
      );
    }

    final controller = StreamController<double>.broadcast();

    final billSub = billStream.listen((snap) {
      lastBills = snap.docs;
      if (lastSettlements != null && !controller.isClosed) {
        controller.add(compute());
      }
    });
    final settleSub = settlementStream.listen((snap) {
      lastSettlements = snap.docs;
      if (lastBills != null && !controller.isClosed) {
        controller.add(compute());
      }
    });

    controller.onCancel = () {
      billSub.cancel();
      settleSub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ── Last Seen Tracking ──────────────────────────────────────────

  // Update the last-seen timestamp for the current user in a group
  Future<void> updateLastSeen(String groupId, String uid) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('lastSeen')
          .doc(uid)
          .set({'timestamp': Timestamp.now()});
    } catch (e) {
      if (kDebugMode) log('Error updating lastSeen: $e');
    }
  }

  // Stream the last-seen timestamp for a user in a group
  Stream<DateTime?> getLastSeenStream(String groupId, String uid) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('lastSeen')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final ts = doc.data()?['timestamp'] as Timestamp?;
      return ts?.toDate();
    });
  }

  // Stream whether a group has unseen activity for a given user.
  // Uses Firestore where-queries to check for items newer than lastSeen.
  Stream<bool> hasUnseenActivity(String groupId, String uid) {
    final controller = StreamController<bool>();
    StreamSubscription? innerBillSub;
    StreamSubscription? innerSettleSub;
    bool? billResult;
    bool? settleResult;

    void cancelInner() {
      innerBillSub?.cancel();
      innerSettleSub?.cancel();
      innerBillSub = null;
      innerSettleSub = null;
      billResult = null;
      settleResult = null;
    }

    void emitIfReady() {
      if (billResult != null && settleResult != null && !controller.isClosed) {
        controller.add(billResult! || settleResult!);
      }
    }

    final lastSeenSub = getLastSeenStream(groupId, uid).listen((lastSeen) {
      cancelInner();
      final ts = lastSeen != null
          ? Timestamp.fromDate(lastSeen)
          : Timestamp(0, 0);

      innerBillSub = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('bills')
          .where('createdAt', isGreaterThan: ts)
          .limit(1)
          .snapshots()
          .listen((snap) {
        billResult = snap.docs.isNotEmpty;
        emitIfReady();
      });

      innerSettleSub = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .where('settledAt', isGreaterThan: ts)
          .limit(1)
          .snapshots()
          .listen((snap) {
        settleResult = snap.docs.isNotEmpty;
        emitIfReady();
      });
    });

    controller.onCancel = () {
      lastSeenSub.cancel();
      cancelInner();
      controller.close();
    };

    return controller.stream;
  }
}
