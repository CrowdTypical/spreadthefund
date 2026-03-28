// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/theme_constants.dart';

Widget buildGroupAvatar(String? customImage, String iconKey, Color accent, double size) {
  if (customImage != null && customImage.isNotEmpty) {
    try {
      if (customImage.startsWith('http')) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(color: accent.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              customImage,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(groupIcon(iconKey), color: accent, size: size * 0.8),
            ),
          ),
        );
      }
      // Legacy base64 support
      final bytes = base64Decode(customImage);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            Uint8List.fromList(bytes),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(groupIcon(iconKey), color: accent, size: size * 0.8),
          ),
        ),
      );
    } catch (_) {
      return Icon(groupIcon(iconKey), color: accent, size: size * 0.8);
    }
  }
  return Icon(groupIcon(iconKey), color: accent, size: size * 0.8);
}
