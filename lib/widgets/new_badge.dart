// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';
import '../constants/theme_constants.dart';

/// A "NEW" corner badge with a one-shot shimmer/shine sweep.
class NewBadge extends StatefulWidget {
  const NewBadge({super.key});

  @override
  State<NewBadge> createState() => _NewBadgeState();
}

class _NewBadgeState extends State<NewBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(count: 2);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Sweep a white highlight across the badge
        final t = _controller.value;
        // Map t from 0..1 to alignment range -2..+2
        final pos = -2.0 + 4.0 * t;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
            ),
            gradient: LinearGradient(
              begin: Alignment(pos - 0.8, 0),
              end: Alignment(pos + 0.8, 0),
              colors: [
                AppColors.accent,
                Colors.white.withValues(alpha: 0.85),
                AppColors.accent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: const Text(
            'NEW',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: AppColors.background,
            ),
          ),
        );
      },
    );
  }
}
