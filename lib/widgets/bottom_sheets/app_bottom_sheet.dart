import 'package:flutter/material.dart';
import 'package:tracker_app/utils/general_utils.dart';

/// Unified bottom sheet component for the entire app
/// Handles both simple and draggable scrollable sheets with consistent styling
class AppBottomSheet extends StatelessWidget {
  final Widget Function(
      BuildContext context, ScrollController? scrollController)? builder;
  final Widget? child;
  final bool isDraggable;
  final double? initialChildSize;
  final double? minChildSize;
  final double? maxChildSize;

  const AppBottomSheet({
    super.key,
    this.builder,
    this.child,
    this.isDraggable = false,
    this.initialChildSize = 0.7,
    this.minChildSize = 0.5,
    this.maxChildSize = 0.9,
  }) : assert(builder != null || child != null,
            'Either builder or child must be provided');

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: const Color(0xFF1A1F2E),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      gradient: themeGradient(context: context),
    );

    if (isDraggable) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: DraggableScrollableSheet(
          initialChildSize: initialChildSize ?? 0.7,
          minChildSize: minChildSize ?? 0.5,
          maxChildSize: maxChildSize ?? 0.9,
          snap: true,
          builder: (context, scrollController) {
            return GestureDetector(
              onTap: () {}, // Absorb taps on the sheet content
              child: Container(
                decoration: decoration,
                child: builder != null
                    ? builder!(context, scrollController)
                    : child!,
              ),
            );
          },
        ),
      );
    }

    return Container(
      decoration: decoration,
      child: SafeArea(
        child: builder != null ? builder!(context, null) : child!,
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
}) {
  assert(builder != null || child != null,
      'Either builder or child must be provided');

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: true,
    showDragHandle: false,
    useSafeArea: true,
    barrierColor: Colors.black54,
    builder: (context) => AppBottomSheet(
      isDraggable: isDraggable,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: builder,
      child: child,
    ),
  );
}
