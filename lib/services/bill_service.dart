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
      print('Error creating invite: $e');
      return false;
    }
  }

  // Check and process pending invites for a user who just signed in
  Future<void> processPendingInvites(String userId, String email) async {
    try {
      print('Processing invites for: ${email.toLowerCase()}');
      // Query only by email to avoid needing a composite index
      final snapshot = await _firestore
          .collection('invites')
          .where('inviteeEmail', isEqualTo: email.toLowerCase())
          .get();

      print('Found ${snapshot.docs.length} invite(s)');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        if (status != 'pending') {
          print('Skipping invite ${doc.id} — status: $status');
          continue;
        }

        final groupId = data['groupId'] as String;
        print('Joining group $groupId from invite ${doc.id}');

        // Add user UID to the group
        await _firestore.collection('groups').doc(groupId).update({
          'members': FieldValue.arrayUnion([userId]),
        });

        // Mark invite as accepted
        await doc.reference.update({'status': 'accepted'});

        print('Successfully joined group $groupId');
      }
    } catch (e) {
      print('Error processing invites: $e');
    }
  }

  // ── Groups ───────────────────────────────────────────────────────

  // Create a personal group (solo user, partners can be added later)
  Future<String?> createPersonalGroup(String userId) async {
    try {
      final docRef = await _firestore.collection('groups').add({
        'name': 'Personal',
        'members': [userId],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
      });
      return docRef.id;
    } catch (e) {
      print('Error creating personal group: $e');
      return null;
    }
  }

  // Create a bill group with a partner
  Future<String?> createBillGroup(String userId, String partnerEmail) async {
    try {
      final docRef = await _firestore.collection('groups').add({
        'name': 'Group',
        'members': [userId, partnerEmail],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
      });
      return docRef.id;
    } catch (e) {
      print('Error creating bill group: $e');
      return null;
    }
  }

  // Create a named group
  Future<String?> createNamedGroup(String userId, String name) async {
    try {
      final docRef = await _firestore.collection('groups').add({
        'name': name,
        'members': [userId],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
      });
      return docRef.id;
    } catch (e) {
      print('Error creating named group: $e');
      return null;
    }
  }

  // Add a member to an existing group
  Future<bool> addMemberToGroup(String groupId, String memberEmail) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([memberEmail]),
      });
      return true;
    } catch (e) {
      print('Error adding member: $e');
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
    DateTime? date,
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).collection('bills').add({
        'paidBy': paidBy,
        'amount': amount,
        'description': description,
        'category': category,
        'notes': notes,
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
      print('Error adding bill: $e');
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
      print('Error getting categories: $e');
      return [];
    }
  }

  // Get group members with their display info
  Future<List<Map<String, String>>> getGroupMembers(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final members = List<String>.from(groupDoc.data()?['members'] ?? []);
      final result = <Map<String, String>>[];
      for (final uid in members) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final name = (data['username'] as String?)?.isNotEmpty == true
              ? data['username'] as String
              : data['displayName'] as String? ?? data['email'] as String? ?? uid;
          result.add({
            'uid': uid,
            'name': name,
            'email': data['email'] as String? ?? '',
          });
        } else {
          result.add({'uid': uid, 'name': uid, 'email': ''});
        }
      }
      return result;
    } catch (e) {
      print('Error getting group members: $e');
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

  // Get groups for a user
  Stream<List<Group>> getUserGroupsStream(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Group.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Get user by email
  Future<String?> getUserIdByEmail(String email) async {
    try {
      print('Searching for user with email: $email');
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      print('Query returned ${snapshot.docs.length} results');
      for (var doc in snapshot.docs) {
        print('Found user doc: ${doc.id} => ${doc.data()}');
      }

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
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
      print('Error renaming group: $e');
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
      print('Error deleting group: $e');
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
      print('Error deleting bill: $e');
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
      print('Error settling up: $e');
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
}
