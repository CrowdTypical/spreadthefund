import 'dart:developer';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // ── CONFIGURE THESE ──────────────────────────────────────────────
  // Use a Gmail account with an App Password:
  //   1. Enable 2-Factor Auth on the Gmail account
  //   2. Go to https://myaccount.google.com/apppasswords
  //   3. Create an App Password and paste it below
  static const String _senderEmail = 'spreadthefund@gmail.com';
  static const String _senderPassword = 'kbxy wrmw apgm kiot';
  // ─────────────────────────────────────────────────────────────────

  static bool get isConfigured =>
      _senderEmail != 'YOUR_GMAIL@gmail.com' &&
      _senderPassword != 'YOUR_APP_PASSWORD';

  static Future<bool> sendInviteEmail({
    required String toEmail,
    required String inviterName,
    required String groupName,
  }) async {
    if (!isConfigured) {
      log('Email not configured — skipping send');
      return false;
    }

    final smtpServer = gmail(_senderEmail, _senderPassword);

    final message = Message()
      ..from = const Address(_senderEmail, 'Spread the Fund')
      ..recipients.add(toEmail)
      ..subject = '$inviterName invited you to Spread the Fund!'
      ..html = '''
        <div style="font-family: monospace; background: #0A0E14; color: #E0E0E0; padding: 32px; max-width: 500px;">
          <h2 style="color: #00E5CC; letter-spacing: 2px;">SPREAD THE FUND</h2>
          <p><strong>$inviterName</strong> invited you to join the group <strong>"$groupName"</strong>.</p>
          <p>Sign in with <strong>$toEmail</strong> and you'll automatically be added to the group.</p>
          <div style="margin: 24px 0; text-align: center;">
            <a href="https://github.com/CrowdTypical/spreadthefund/releases"
               style="display: inline-block; padding: 14px 28px; background: #00E5CC; color: #0A0E14;
                      font-family: monospace; font-size: 14px; font-weight: bold; letter-spacing: 2px;
                      text-decoration: none;">
              DOWNLOAD THE APP
            </a>
          </div>
          <p style="color: #8899AA; font-size: 12px;">
            <strong>Note:</strong> Spread the Fund is currently available on <strong>Android only</strong>.
            You'll need to install the APK manually.
          </p>
          <p style="color: #8899AA; font-size: 12px;">
            New to installing APKs? Follow this guide:
            <a href="https://www.lifewire.com/install-apk-on-android-4177185"
               style="color: #00E5CC; text-decoration: underline;">
              How to Install Third-Party APKs on Android
            </a>
          </p>
        </div>
      ''';

    try {
      await send(message, smtpServer);
      log('Invite email sent to $toEmail');
      return true;
    } catch (e) {
      log('Error sending email: $e');
      return false;
    }
  }
}
