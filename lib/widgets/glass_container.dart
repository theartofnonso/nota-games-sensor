import 'dart:ui';
import 'package:flutter/material.dart';
import '../colors.dart';

/// TRNR Theme Glassmorphism Container
/// 
/// A reusable glass-effect container with blur and subtle borders.
/// Includes three preset styles: light, medium, and dark glass.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final GlassStyle style;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.style = GlassStyle.medium,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: effectiveBorderRadius,
            border: border ?? _getDefaultBorder(),
            boxShadow: _getShadow(),
          ),
          child: child,
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (style) {
      case GlassStyle.light:
        return glassLight;
      case GlassStyle.medium:
        return glassMedium;
      case GlassStyle.dark:
        return glassDark;
    }
  }

  Border _getDefaultBorder() {
    switch (style) {
      case GlassStyle.light:
        return Border.all(color: borderLight, width: 1);
      case GlassStyle.medium:
        return Border.all(color: borderMedium, width: 1);
      case GlassStyle.dark:
        return Border.all(color: borderSubtle, width: 1);
    }
  }

  List<BoxShadow> _getShadow() {
    switch (style) {
      case GlassStyle.light:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ];
      case GlassStyle.medium:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ];
      case GlassStyle.dark:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];
    }
  }
}

enum GlassStyle {
  light,  // backdrop-blur-xl bg-white/5 border-white/10
  medium, // backdrop-blur-xl bg-white/10 border-white/20
  dark,   // backdrop-blur-xl bg-zinc-900/30 border-white/5
}

/// Glass Button with TRNR styling
class GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final GlowState glowState;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.glowState = GlowState.idle,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(9999);
    
    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: glassLight,
                borderRadius: effectiveBorderRadius,
                border: Border.all(color: borderLight, width: 1),
                boxShadow: _getGlowShadow(),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: textPrimary.withOpacity(0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _getGlowShadow() {
    switch (glowState) {
      case GlowState.idle:
        return [
          BoxShadow(
            color: successGlow,
            blurRadius: 20,
            spreadRadius: 8,
          ),
        ];
      case GlowState.active:
        return [
          BoxShadow(
            color: infoGlow,
            blurRadius: 20,
            spreadRadius: 8,
          ),
        ];
      case GlowState.error:
        return [
          BoxShadow(
            color: errorGlow,
            blurRadius: 20,
            spreadRadius: 8,
          ),
        ];
      case GlowState.none:
        return [];
    }
  }
}

enum GlowState {
  idle,   // Green glow
  active, // Blue glow
  error,  // Red glow
  none,   // No glow
}

/// Status Indicator with glassmorphic styling
class StatusIndicator extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: _getBorderColor(), width: 1),
            boxShadow: [
              BoxShadow(
                color: _getGlowColor(),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _getTextColor(),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case StatusType.success:
        return const Color(0x99064e3b); // emerald-950/60
      case StatusType.info:
        return const Color(0x99172554); // blue-950/60
      case StatusType.error:
        return const Color(0x99450a0a); // red-950/60
    }
  }

  Color _getBorderColor() {
    switch (type) {
      case StatusType.success:
        return success.withOpacity(0.4);
      case StatusType.info:
        return info.withOpacity(0.4);
      case StatusType.error:
        return error.withOpacity(0.4);
    }
  }

  Color _getGlowColor() {
    switch (type) {
      case StatusType.success:
        return successGlow;
      case StatusType.info:
        return infoGlow;
      case StatusType.error:
        return errorGlow;
    }
  }

  Color _getTextColor() {
    switch (type) {
      case StatusType.success:
        return const Color(0xFF6ee7b7); // emerald-300
      case StatusType.info:
        return const Color(0xFF93c5fd); // blue-300
      case StatusType.error:
        return const Color(0xFFfca5a5); // red-300
    }
  }
}

enum StatusType {
  success,
  info,
  error,
}

