import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill.dart';
import '../models/group.dart';

class BillService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Invites ──────────────────────────────────────────────────────

  // Create a pending invite (stored by email so it works before they sign up)
  Future<bool> createInvite({
    required String groupId,
    required String groupName,
    required String inviterUid,
    required String inviterName,
    required String inviteeEmail,
  }) async {
    try {
      await _firestore.collection('invites').add({
        'groupId': groupId,
        'groupName': groupName,
        'inviterUid': inviterUid,
        'inviterName': inviterName,
        'inviteeEmail': inviteeEmail.toLowerCase(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      log('Error creating invite: $e');
      return false;
    }
  }

  // Check and process pending invites for a user who just signed in.
  // Marks invites as accepted and ensures the user's email is in the group.
  Future<void> processPendingInvites(String email) async {
    try {
      final normalizedEmail = email.toLowerCase();
      log('Processing invites for: $normalizedEmail');
      final snapshot = await _firestore
          .collection('invites')
          .where('inviteeEmail', isEqualTo: normalizedEmail)
          .get();

      log('Found ${snapshot.docs.length} invite(s)');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        if (status != 'pending') {
          log('Skipping invite ${doc.id} — status: $status');
          continue;
        }
        await doc.reference.update({'status': 'accepted'});
        log('Marked invite ${doc.id} as accepted');
      }
    } catch (e) {
      log('Error processing invites: $e');
    }
  }

  // When a user signs in, find every group that has their UID in the
  // members list and swap it for their email (backwards compat migration).
  Future<void> migrateUidToEmail(String uid, String email) async {
    try {
      final normalizedEmail = email.toLowerCase();
      log('Migrating UID $uid → email $normalizedEmail in groups');

      final groups = await _firestore
          .collection('groups')
          .where('members', arrayContains: uid)
          .get();

      log('Found ${groups.docs.length} group(s) with UID in members');

      for (final doc in groups.docs) {
        await doc.reference.update({
          'members': FieldValue.arrayRemove([uid]),
        });
        await doc.reference.update({
          'members': FieldValue.arrayUnion([normalizedEmail]),
        });
        log('Migrated group ${doc.id}: $uid → $normalizedEmail');
      }
    } catch (e) {
      log('Error migrating UID to email: $e');
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
      log('Error creating personal group: $e');
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
      log('Error creating bill group: $e');
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
      log('Error creating named group: $e');
      return null;
    }
  }

  // Add a member to an existing group (by email)
  Future<bool> addMemberToGroup(String groupId, String memberEmail) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([memberEmail.toLowerCase()]),
      });
      return true;
    } catch (e) {
      log('Error adding member: $e');
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
      log('Error removing member: $e');
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
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).collection('bills').add({
        'paidBy': paidBy,
        'amount': amount,
        'description': description,
        'category': category,
        'notes': notes,
        'splitPercent': splitPercent,
        'splitEquallyWith': 'both',
        'createdAt': date != null ? Timestamp.fromDate(date) : FieldValue.serverTimestamp(),
        'settled': false,
      });

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
      log('Error adding bill: $e');
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
      log('Error getting categories: $e');
      return [];
    }
  }

  // Get group members with their display info.
  // Members are stored as emails in the group.
  Future<List<Map<String, String>>> getGroupMembers(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final members = List<String>.from(groupDoc.data()?['members'] ?? []);
      final result = <Map<String, String>>[];
      for (final member in members) {
        final email = member.toLowerCase();
        // Look up user doc by email
        final userSnap = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (userSnap.docs.isNotEmpty) {
          final data = userSnap.docs.first.data();
          final username = data['username'] as String?;
          final displayName = data['displayName'] as String?;
          final name = (username != null && username.isNotEmpty)
              ? username
              : (displayName != null && displayName.isNotEmpty)
                  ? displayName
                  : email.split('@').first;
          result.add({
            'uid': email,
            'name': name,
            'email': email,
          });
        } else {
          // No account yet — show email as pending
          result.add({
            'uid': email,
            'name': email,
            'email': email,
            'pending': 'true',
          });
        }
      }
      return result;
    } catch (e) {
      log('Error getting group members: $e');
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
      log('Searching for user with email: $normalizedEmail');
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      log('Query returned ${snapshot.docs.length} results');
      for (var doc in snapshot.docs) {
        log('Found user doc: ${doc.id} => ${doc.data()}');
      }

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      log('Error getting user by email: $e');
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
      log('Error renaming group: $e');
      return false;
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
      log('Error updating group appearance: $e');
      return false;
    }
  }

  // Delete a group and all its subcollections
  Future<bool> deleteGroup(String groupId) async {
    try {
      final groupRef = _firestore.collection('groups').doc(groupId);

      // Delete bills subcollection
      final bills = await groupRef.collection('bills').get();
      for (final doc in bills.docs) {
        await doc.reference.delete();
      }

      // Delete settlements subcollection
      final settlements = await groupRef.collection('settlements').get();
      for (final doc in settlements.docs) {
        await doc.reference.delete();
      }

      // Delete categories subcollection
      final categories = await groupRef.collection('categories').get();
      for (final doc in categories.docs) {
        await doc.reference.delete();
      }

      // Delete the group document
      await groupRef.delete();
      return true;
    } catch (e) {
      log('Error deleting group: $e');
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
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('bills')
          .doc(billId)
          .update({
        'paidBy': paidBy,
        'amount': amount,
        'description': description,
        'category': category,
        'notes': notes,
        'splitPercent': splitPercent,
      });
      return true;
    } catch (e) {
      log('Error updating bill: $e');
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
      log('Error deleting bill: $e');
      return false;
    }
  }

  // Settle up (record payment)
  Future<bool> settleUp({
    required String groupId,
    required String from,
    required String to,
    required double amount,
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).collection('settlements').add({
        'from': from,
        'to': to,
        'amount': amount,
        'settledAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      log('Error settling up: $e');
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

  /// Delete all data associated with a user:
  /// - Remove from groups (delete group if sole member)
  /// - Delete invites (sent and received)
  /// - Delete feedback
  /// - Delete user document
  Future<bool> deleteAllUserData(String email, String uid) async {
    try {
      final normalizedEmail = email.toLowerCase();

      // 1. Handle groups
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
          // Remove user from the group
          await doc.reference.update({
            'members': FieldValue.arrayRemove([normalizedEmail]),
          });
        }
      }

      // 2. Delete invites where user is invitee
      final invitesReceived = await _firestore
          .collection('invites')
          .where('inviteeEmail', isEqualTo: normalizedEmail)
          .get();
      for (final doc in invitesReceived.docs) {
        await doc.reference.delete();
      }

      // 3. Delete invites where user is inviter
      final invitesSent = await _firestore
          .collection('invites')
          .where('inviterUid', isEqualTo: uid)
          .get();
      for (final doc in invitesSent.docs) {
        await doc.reference.delete();
      }

      // 4. Delete feedback submitted by user
      final feedbackSnap = await _firestore
          .collection('feedback')
          .where('email', isEqualTo: normalizedEmail)
          .get();
      for (final doc in feedbackSnap.docs) {
        await doc.reference.delete();
      }

      // 5. Delete user document
      await _firestore.collection('users').doc(uid).delete();

      return true;
    } catch (e) {
      log('Error deleting all user data: $e');
      return false;
    }
  }
}
