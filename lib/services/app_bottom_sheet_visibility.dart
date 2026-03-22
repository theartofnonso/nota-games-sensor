import 'package:flutter/foundation.dart';

/// Tracks open [showAppBottomSheet] / [showAppActionBottomSheet] modals so the
/// main shell can hide the floating navigation bar while a sheet is visible.
class AppBottomSheetVisibility {
  AppBottomSheetVisibility._();
  static final AppBottomSheetVisibility instance = AppBottomSheetVisibility._();

  final ValueNotifier<int> openCount = ValueNotifier<int>(0);

  void _increment() {
    openCount.value = openCount.value + 1;
  }

  void _decrement() {
    if (openCount.value > 0) {
      openCount.value = openCount.value - 1;
    }
  }

  /// Wrap a bottom sheet future so open/close is tracked for the shell nav bar.
  Future<T?> track<T>(Future<T?> future) {
    _increment();
    return future.whenComplete(_decrement);
  }
}
