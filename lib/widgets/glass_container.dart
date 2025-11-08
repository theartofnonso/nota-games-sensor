import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

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
            color: _getBackgroundColor(context),
            borderRadius: effectiveBorderRadius,
            border: border ?? _getDefaultBorder(context),
            boxShadow: _getShadow(context),
          ),
          child: child,
        ),
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    switch (style) {
      case GlassStyle.light:
        return Theme.of(context).colors.glassLight;
      case GlassStyle.medium:
        return Theme.of(context).colors.glassMedium;
      case GlassStyle.dark:
        return Theme.of(context).colors.glassDark;
    }
  }

  Border _getDefaultBorder(BuildContext context) {
    switch (style) {
      case GlassStyle.light:
        return Border.all(color: Theme.of(context).colors.borderLight, width: 1);
      case GlassStyle.medium:
        return Border.all(color: Theme.of(context).colors.borderMedium, width: 1);
      case GlassStyle.dark:
        return Border.all(color: Theme.of(context).colors.borderSubtle, width: 1);
    }
  }

  List<BoxShadow> _getShadow(BuildContext context) {
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

/// Glass Styles
enum GlassStyle { light, medium, dark }

/// Example Usage Widget
/// 
/// This demonstrates how to use the glass container in different scenarios
class GlassContainerExample extends StatelessWidget {
  const GlassContainerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colors.glassLight,
              Theme.of(context).colors.glassMedium,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Light glass
              GlassContainer(
                style: GlassStyle.light,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Light Glass',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Medium glass (default)
              GlassContainer(
                padding: const EdgeInsets.all(24),
                width: 300,
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      size: 48,
                      color: Theme.of(context).colors.successGlow,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Medium Glass',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Dark glass
              GlassContainer(
                style: GlassStyle.dark,
                padding: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.nightlight_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dark Glass',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Additional utilities for glass effects

/// Glass Status Container
/// 
/// A specialized glass container with status-based styling
class GlassStatusContainer extends StatelessWidget {
  final Widget child;
  final StatusType status;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const GlassStatusContainer({
    super.key,
    required this.child,
    required this.status,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      style: GlassStyle.medium,
      padding: padding ?? const EdgeInsets.all(16),
      borderRadius: borderRadius,
      border: Border.all(
        color: _getStatusBorderColor(context),
        width: 1.5,
      ),
      child: child,
    );
  }

  Color _getStatusBorderColor(BuildContext context) {
    switch (status) {
      case StatusType.success:
        return Theme.of(context).colorScheme.primary.withOpacity(0.4);
      case StatusType.warning:
        return Colors.orange.withOpacity(0.4);
      case StatusType.error:
        return Theme.of(context).colorScheme.error.withOpacity(0.4);
      case StatusType.info:
        return Theme.of(context).colorScheme.secondary.withOpacity(0.4);
    }
  }

}

enum StatusType {
  success,
  warning,
  error,
  info,
}
