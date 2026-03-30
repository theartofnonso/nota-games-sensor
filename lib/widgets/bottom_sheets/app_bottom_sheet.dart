import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:trainware/services/app_bottom_sheet_visibility.dart';
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
    this.isDraggable = true,
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
        // Let the modal barrier / scrim receive taps above the sheet. With the
        // default expand: true, the sheet layer fills the screen and blocks
        // barrier dismiss (only drag-to-close worked).
        expand: false,
        initialChildSize: initialChildSize ?? 0.7,
        minChildSize: minChildSize ?? 0.5,
        maxChildSize: maxChildSize ?? 0.9,
        shouldCloseOnMinExtent: true,
        snap: true,
        builder: (context, scrollController) {
          return GestureDetector(
            // Only consume gestures within the sheet content, not outside
            behavior: HitTestBehavior.deferToChild,
            child: wrapWithBlur(
              child: Container(
                decoration: decoration,
                child: SafeArea(
                  top: true,
                  bottom: false,
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

    return wrapWithBlur(
      child: Container(
        decoration: decoration,
        child: SafeArea(
          top: true,
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
  bool isDraggable = true,
  bool isDismissible = true,
  bool isScrollControlled = true,
  bool useRootNavigator = false,
  double? initialChildSize,
  double? minChildSize,
  double? maxChildSize,
  bool useBlurredTransparentBackground = true,
  double blurSigma = 16,
  Future<bool> Function()? onBarrierTap,
  bool? enableDrag,
}) {
  assert(builder != null || child != null,
      'Either builder or child must be provided');

  return AppBottomSheetVisibility.instance.track(
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      useRootNavigator: useRootNavigator,
      // Modal drag is separate from sheet content drag ([isDraggable]).
      enableDrag: enableDrag ?? isDraggable,
      showDragHandle: false,
      builder: (context) {
        Future<void> dismissOnBarrierTap() async {
          if (!isDismissible) return;
          if (onBarrierTap != null) {
            final should = await onBarrierTap();
            if (!context.mounted) return;
            if (should) Navigator.of(context).pop();
          } else {
            Navigator.of(context).maybePop();
          }
        }

        Widget sheet = AppBottomSheet(
          isDraggable: isDraggable,
          isDismissible: isDismissible,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          useBlurredTransparentBackground: useBlurredTransparentBackground,
          blurSigma: blurSigma,
          builder: builder,
          child: child,
        );
        // Non-draggable + scroll-controlled: hug content height instead of a
        // tall empty modal region (Flutter default for isScrollControlled: false).
        if (!isDraggable && isScrollControlled) {
          sheet = Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              widthFactor: 1.0,
              child: sheet,
            ),
          );
        }

        // Modal page sits above the route barrier, so the barrier never gets
        // pointer events. A full-screen hit target behind the sheet closes on tap.
        if (!isDismissible) {
          return sheet;
        }

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => dismissOnBarrierTap(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            sheet,
          ],
        );
      },
    ),
  );
}

/// Helper for compact action/confirmation/warning sheets.
/// These sheets fit content and avoid draggable min-height behavior.
Future<T?> showAppActionBottomSheet<T>({
  required BuildContext context,
  Widget Function(BuildContext context, ScrollController? scrollController)?
      builder,
  Widget? child,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool useRootNavigator = false,
  bool useBlurredTransparentBackground = true,
  double blurSigma = 16,
  bool? enableDrag,
}) {
  return showAppBottomSheet<T>(
    context: context,
    builder: builder,
    child: child,
    isDraggable: false,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    useBlurredTransparentBackground: useBlurredTransparentBackground,
    blurSigma: blurSigma,
    enableDrag: enableDrag,
  );
}
