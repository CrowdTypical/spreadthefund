// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme_constants.dart';

Future<Uint8List?> pickAndCropImage(BuildContext context, Color accent) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 70,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();

  if (!context.mounted) return null;

  Uint8List? result;
  await showDialog(
    context: context,
    builder: (ctx) {
      final transformController = TransformationController();
      return AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'CROP IMAGE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: accent,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pinch to zoom, drag to move',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InteractiveViewer(
                  transformationController: transformController,
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Image.memory(
                    Uint8List.fromList(bytes),
                    fit: BoxFit.cover,
                    width: 200,
                    height: 200,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preview shows final crop area',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                letterSpacing: 1,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 1,
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              result = bytes;
              Navigator.pop(ctx);
            },
            child: Text(
              'USE IMAGE',
              style: TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 1,
                color: accent,
              ),
            ),
          ),
        ],
      );
    },
  );

  return result;
}

Widget buildImagePreview(String imageStr, String iconKey, Color accent) {
  if (imageStr.startsWith('http')) {
    return Image.network(
      imageStr,
      fit: BoxFit.cover,
      width: 48,
      height: 48,
      errorBuilder: (_, __, ___) => Icon(groupIcon(iconKey), color: accent, size: 24),
    );
  }
  try {
    return Image.memory(
      Uint8List.fromList(base64Decode(imageStr)),
      fit: BoxFit.cover,
      width: 48,
      height: 48,
      errorBuilder: (_, __, ___) => Icon(groupIcon(iconKey), color: accent, size: 24),
    );
  } catch (_) {
    return Icon(groupIcon(iconKey), color: accent, size: 24);
  }
}
