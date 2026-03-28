// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EmailService {
  static Future<bool> sendInviteEmail({
    required String toEmail,
    required String inviterName,
    required String groupName,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendInviteEmail');
      await callable.call<dynamic>({
        'toEmail': toEmail,
        'inviterName': inviterName,
        'groupName': groupName,
      });
      if (kDebugMode) log('Invite email sent to $toEmail');
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) log('Cloud Function error: ${e.code} — ${e.message}');
      return false;
    } catch (e) {
      if (kDebugMode) log('Error sending email: $e');
      return false;
    }
  }
}
