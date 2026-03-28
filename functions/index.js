const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const nodemailer = require("nodemailer");

// Secrets are stored securely in Google Cloud Secret Manager.
// Set them once via:
//   firebase functions:secrets:set SMTP_EMAIL
//   firebase functions:secrets:set SMTP_PASSWORD
const smtpEmail = defineSecret("SMTP_EMAIL");
const smtpPassword = defineSecret("SMTP_PASSWORD");

exports.sendInviteEmail = onCall(
  { secrets: [smtpEmail, smtpPassword], invoker: "public" },
  async (request) => {
    // Require authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be signed in to send invite emails."
      );
    }

    const { toEmail, inviterName, groupName } = request.data;

    if (!toEmail || !inviterName || !groupName) {
      throw new HttpsError(
        "invalid-argument",
        "toEmail, inviterName, and groupName are required."
      );
    }

    // Basic email format validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(toEmail)) {
      throw new HttpsError("invalid-argument", "Invalid email address.");
    }

    // HTML-escape user-provided strings to prevent XSS
    function escapeHtml(str) {
      return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
    }

    const safeInviterName = escapeHtml(inviterName);
    const safeGroupName = escapeHtml(groupName);
    const safeToEmail = escapeHtml(toEmail);

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: smtpEmail.value(),
        pass: smtpPassword.value(),
      },
    });

    const mailOptions = {
      from: `"Spread the Fund" <${smtpEmail.value()}>`,
      to: toEmail,
      subject: `${safeInviterName} invited you to Spread the Fund!`,
      html: `
        <div style="font-family: monospace; background: #0A0E14; color: #E0E0E0; padding: 32px; max-width: 500px;">
          <h2 style="color: #00E5CC; letter-spacing: 2px;">SPREAD THE FUND</h2>
          <p><strong>${safeInviterName}</strong> invited you to join the group <strong>"${safeGroupName}"</strong>.</p>
          <p>Sign in with <strong>${safeToEmail}</strong> and you'll automatically be added to the group.</p>
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
      `,
    };

    try {
      await transporter.sendMail(mailOptions);
      return { success: true };
    } catch (error) {
      console.error("Error sending email:", error);
      throw new HttpsError("internal", "Failed to send invite email.");
    }
  }
);
