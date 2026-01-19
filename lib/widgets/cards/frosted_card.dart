import 'dart:ui';

import 'package:flutter/material.dart';

class FrostedCard extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final EdgeInsets padding;
  final double borderRadius;
  final double blurSigma;
  final double textureOpacity;

  const FrostedCard({
    super.key,
    required this.child,
    required this.gradientColors,
    this.padding = const EdgeInsets.all(22),
    this.borderRadius = 22,
    this.blurSigma = 16,
    this.textureOpacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: textureOpacity,
                  child: Image.asset(
                    'images/1k_Dissolve_Noise_Texture.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
