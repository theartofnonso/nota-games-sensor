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
  final bool showTopLeftCloseButton;

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
    this.showTopLeftCloseButton = false,
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

    Widget withOptionalCloseButton({required Widget child}) {
      if (!showTopLeftCloseButton) return child;
      return Stack(
        children: [
          child,
          Positioned(
            top: 8,
            left: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close,
                    size: 20, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
          ),
        ],
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
            // Only consume gestures within the sheet content, not outside
            behavior: HitTestBehavior.deferToChild,
            child: withOptionalCloseButton(
              child: wrapWithBlur(
                child: Container(
                  decoration: decoration,
                  child: builder != null
                      ? builder!(context, scrollController)
                      : child!,
                ),
              ),
            ),
          );
        },
      );
    }

    return withOptionalCloseButton(
      child: wrapWithBlur(
        child: Container(
          decoration: decoration,
          child: SafeArea(
            bottom: false,
            child: builder != null ? builder!(context, null) : child!,
          ),
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
  bool useRootNavigator = false,
  double? initialChildSize,
  double? minChildSize,
  double? maxChildSize,
  bool showTopLeftCloseButton = false,
  bool useBlurredTransparentBackground = true,
  double blurSigma = 16,
  Future<bool> Function()? onBarrierTap,
  bool? enableDrag,
}) {
  assert(builder != null || child != null,
      'Either builder or child must be provided');

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    enableDrag: enableDrag ?? (isDismissible && !isDraggable),
    showDragHandle: false,
    builder: (context) => AppBottomSheet(
      isDraggable: isDraggable,
      isDismissible: isDismissible,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      showTopLeftCloseButton: showTopLeftCloseButton,
      useBlurredTransparentBackground: useBlurredTransparentBackground,
      blurSigma: blurSigma,
      builder: builder,
      child: child,
    ),
  );
}
