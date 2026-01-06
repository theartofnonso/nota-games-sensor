import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:trainware/utils/general_utils.dart';

/// Unified bottom sheet component for the entire app
/// Handles both simple and draggable scrollable sheets with consistent styling
class AppBottomSheet extends StatelessWidget {
  final Widget Function(
      BuildContext context, ScrollController? scrollController)? builder;
  final Widget? child;
  final bool isDraggable;
  final bool isDismissible;
  final double? initialChildSize;
  final double? minChildSize;
  final double? maxChildSize;
  final bool useBlurredTransparentBackground;
  final double blurSigma;

  const AppBottomSheet({
    super.key,
    this.builder,
    this.child,
    this.isDraggable = false,
    this.isDismissible = true,
    this.initialChildSize = 0.7,
    this.minChildSize = 0.5,
    this.maxChildSize = 0.9,
    this.useBlurredTransparentBackground = true,
    this.blurSigma = 16,
  }) : assert(builder != null || child != null,
            'Either builder or child must be provided');

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
        color: useBlurredTransparentBackground
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFF1A1F2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        gradient: useBlurredTransparentBackground
            ? null
            : themeGradient(context: context));

    Widget wrapWithBlur({required Widget child}) {
      if (!useBlurredTransparentBackground) return child;
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: child,
        ),
      );
    }

    if (isDraggable) {
      return DraggableScrollableSheet(
        initialChildSize: initialChildSize ?? 0.7,
        minChildSize: minChildSize ?? 0.5,
        maxChildSize: maxChildSize ?? 0.9,
        snap: true,
        builder: (context, scrollController) {
          return GestureDetector(
            onTap: () {}, // Absorb taps on the sheet content
            child: wrapWithBlur(
              child: Container(
                decoration: decoration,
                child: builder != null
                    ? builder!(context, scrollController)
                    : child!,
              ),
            ),
          );
        },
      );
    }

    return wrapWithBlur(
      child: Container(
        decoration: decoration,
        child: SafeArea(
          bottom: false,
          child: builder != null ? builder!(context, null) : child!,
        ),
      ),
    );
  }
}

/// Helper function to show the unified bottom sheet
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  Widget Function(BuildContext context, ScrollController? scrollController)?
      builder,
  Widget? child,
  bool isDraggable = false,
  bool isDismissible = true,
  bool isScrollControlled = true,
  double? initialChildSize,
  double? minChildSize,
  double? maxChildSize,
  bool useBlurredTransparentBackground = true,
  double blurSigma = 16,
  Future<bool> Function()? onBarrierTap,
}) {
  assert(builder != null || child != null,
      'Either builder or child must be provided');

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    // When using our own DraggableScrollableSheet, disable the modal's drag
    // dismissal so slight pulls don't instantly close the sheet.
    enableDrag: !isDraggable,
    showDragHandle: false,
    useSafeArea: true,
    // Dim the backdrop so transparent sheets still pop against the content behind.
    barrierColor: isDismissible
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.transparent, // Make barrier transparent when non-dismissible
    builder: (context) => Stack(
      children: [
        // Custom tappable barrier when isDismissible is false (behind sheet to catch outside taps)
        if (!isDismissible)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                // If a callback is provided, use it to show confirmation dialog
                if (onBarrierTap != null) {
                  final shouldPop = await onBarrierTap();
                  if (shouldPop && context.mounted) {
                    Navigator.of(context, rootNavigator: false).pop();
                  }
                } else {
                  // Fallback: try maybePop to trigger PopScope's onPopInvokedWithResult
                  Navigator.of(context, rootNavigator: false).maybePop();
                }
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.55), // Match barrier color
              ),
            ),
          ),
        // Sheet content on top (so taps on sheet don't hit barrier)
        AppBottomSheet(
          isDraggable: isDraggable,
          isDismissible: isDismissible,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          useBlurredTransparentBackground: useBlurredTransparentBackground,
          blurSigma: blurSigma,
          builder: builder,
          child: child,
        ),
      ],
    ),
  );
}
