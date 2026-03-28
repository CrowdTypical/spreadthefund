import 'package:flutter/material.dart';
import '../constants/theme_constants.dart';

/// A $ icon with an RGB channel-split glitch on the bottom portion.
/// Built with native Flutter widgets for pixel-perfect rendering at any size.
class GlitchDollarIcon extends StatelessWidget {
  final double size;
  const GlitchDollarIcon({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Red channel — shifted right
          Transform.translate(
            offset: Offset(size * 0.06, 0),
            child: Icon(Icons.attach_money, size: size, color: const Color(0xAAFF4C5E)),
          ),
          // Blue channel — shifted left
          Transform.translate(
            offset: Offset(-size * 0.06, 0),
            child: Icon(Icons.attach_money, size: size, color: const Color(0x5542A5F5)),
          ),
          // Main teal $ on top
          Icon(Icons.attach_money, size: size, color: AppColors.accent),
        ],
      ),
    );
  }
}


