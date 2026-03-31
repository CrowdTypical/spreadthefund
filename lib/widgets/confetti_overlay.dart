// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const ConfettiOverlay({super.key, required this.onComplete});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      });

    _particles = List.generate(60, (_) => _Particle(_random));
    _controller.forward();
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
        return IgnorePointer(
          child: CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class _Particle {
  final double x; // 0..1 starting horizontal position
  final double startY; // 0..0.3 starting vertical position
  final double speed; // fall speed multiplier
  final double drift; // horizontal drift
  final double size;
  final double rotation;
  final Color color;

  _Particle(Random r)
      : x = r.nextDouble(),
        startY = -0.05 - r.nextDouble() * 0.25,
        speed = 0.6 + r.nextDouble() * 0.8,
        drift = (r.nextDouble() - 0.5) * 0.3,
        size = 4 + r.nextDouble() * 6,
        rotation = r.nextDouble() * pi * 2,
        color = [
          const Color(0xFF00D1B2), // accent/teal
          const Color(0xFF4CAF50), // green
          const Color(0xFFFFD700), // gold
          const Color(0xFFEF5350), // red
          const Color(0xFF42A5F5), // blue
          const Color(0xFFAB47BC), // purple
        ][r.nextInt(6)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Fade out in the last 30%
    final opacity = progress > 0.7 ? (1.0 - progress) / 0.3 : 1.0;

    for (final p in particles) {
      final x = (p.x + p.drift * progress) * size.width;
      final y = (p.startY + p.speed * progress) * size.height;

      if (y < -20 || y > size.height + 20) continue;

      final paint = Paint()..color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * pi * 2 * p.speed);

      // Draw a small rectangle (confetti piece)
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
