import 'package:flutter/material.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';

/// Shared preset for draggable, non-eager-dismiss editor bottom sheets.
Future<T?> showEditorBottomSheet<T>({
  required BuildContext context,
  Widget Function(BuildContext context, ScrollController? scrollController)?
      builder,
  Widget? child,
  double initialChildSize = 0.9,
  double minChildSize = 0.5,
  double maxChildSize = 0.95,
  bool isDismissible = true,
  bool enableDrag = true,
  Future<bool> Function()? onBarrierTap,
}) {
  return showAppBottomSheet<T>(
    context: context,
    isDraggable: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    initialChildSize: initialChildSize,
    minChildSize: minChildSize,
    maxChildSize: maxChildSize,
    builder: builder,
    child: child,
    onBarrierTap: onBarrierTap,
    enableDrag: enableDrag,
  );
}
