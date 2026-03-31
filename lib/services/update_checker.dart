// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';

const String releasesUrl = 'https://github.com/CrowdTypical/spreadthefund/releases';

/// Returns true if [remote] is a newer semver than [local].
bool isNewerVersion(String remote, String local) {
  List<int> parse(String v) {
    final cleaned = v.replaceFirst(RegExp(r'^v\.?'), '');
    return cleaned.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }
  final r = parse(remote);
  final l = parse(local);
  final len = r.length > l.length ? r.length : l.length;
  for (int i = 0; i < len; i++) {
    final rp = i < r.length ? r[i] : 0;
    final lp = i < l.length ? l[i] : 0;
    if (rp > lp) return true;
    if (rp < lp) return false;
  }
  return false;
}

Future<void> checkForUpdate(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt('update_check_timestamp') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const oneDayMs = 24 * 60 * 60 * 1000;

    if (now - lastCheck < oneDayMs) {
      final cachedTag = prefs.getString('update_check_latest_tag');
      if (cachedTag != null && isNewerVersion(cachedTag, appVersion) && context.mounted) {
        showUpdateDialog(context, cachedTag);
      }
      return;
    }

    final response = await http.get(
      Uri.parse('https://api.github.com/repos/CrowdTypical/spreadthefund/releases/latest'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final latestTag = data['tag_name'] as String?;
      await prefs.setInt('update_check_timestamp', now);
      if (latestTag != null) {
        await prefs.setString('update_check_latest_tag', latestTag);
        if (isNewerVersion(latestTag, appVersion) && context.mounted) {
          showUpdateDialog(context, latestTag);
        }
      }
    }
  } catch (_) {
    // Silently fail \u2014 don't block the app if the check fails
  }
}

void showUpdateDialog(BuildContext context, String latestVersion) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: const Text(
        'UPDATE AVAILABLE',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          color: AppColors.accent,
        ),
      ),
      content: Text(
        'A new version ($latestVersion) is available.\n\nYou are on $appVersion.',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'LATER',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(ctx);
            openReleasesPage();
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.accent),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          child: const Text(
            'UPDATE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> openReleasesPage() async {
  await launchUrl(Uri.parse(releasesUrl), mode: LaunchMode.externalApplication);
}
