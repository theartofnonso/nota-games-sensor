import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:tracker_app/widgets/buttons/opacity_button_widget.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class DoubleGenericPicker<T> extends StatefulWidget {
  /// The initially selected item (optional).
  final T? firstInitialValue;
  final T? secondInitialValue;

  /// The list of items to display in the picker.
  final List<T> firstItems;
  final List<T> secondItems;

  /// Callback to return a user-friendly label for each item (e.g., 'Male', 'Female').
  final String Function(T item) firstLabelBuilder;
  final String Function(T item) secondLabelBuilder;

  /// Callback invoked when the user confirms their selection.
  final ValueChanged<Map<String, T>> onItemSelected;

  const DoubleGenericPicker({
    super.key,
    required this.firstItems,
    required this.firstLabelBuilder,
    required this.onItemSelected,
    this.firstInitialValue,
    this.secondInitialValue,
    required this.secondItems,
    required this.secondLabelBuilder,
  });

  @override
  State<DoubleGenericPicker<T>> createState() => _DoubleGenericPickerState<T>();
}

class _DoubleGenericPickerState<T> extends State<DoubleGenericPicker<T>> {
  late T _firstSelectedItem;
  late T _secondSelectedItem;

  static const double _kItemExtent = 32.0;

  @override
  void initState() {
    super.initState();

    // If initialValue is provided and exists in the item list, use it;
    // otherwise, default to the first item (if the list isn't empty).
    if (widget.firstInitialValue != null && widget.firstItems.contains(widget.firstInitialValue)) {
      _firstSelectedItem = widget.firstInitialValue as T;
    } else if (widget.firstItems.isNotEmpty) {
      _firstSelectedItem = widget.firstItems.first;
    } else {
      // Handle empty items list scenario here if needed.
      // For demonstration, we'll just throw:
      throw ArgumentError('GenericPicker cannot be built with an empty items list.');
    }

    // If initialValue is provided and exists in the item list, use it;
    // otherwise, default to the first item (if the list isn't empty).
    if (widget.secondInitialValue != null && widget.secondItems.contains(widget.secondInitialValue)) {
      _secondSelectedItem = widget.secondInitialValue as T;
    } else if (widget.secondItems.isNotEmpty) {
      _secondSelectedItem = widget.secondItems.first;
    } else {
      // Handle empty items list scenario here if needed.
      // For demonstration, we'll just throw:
      throw ArgumentError('GenericPicker cannot be built with an empty items list.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convert each item into a Text widget using labelBuilder.
    final firstChildren = widget.firstItems.map((item) {
      return Text(widget.firstLabelBuilder(item));
    }).toList();

    final secondChildren = widget.secondItems.map((item) {
      return Text(widget.secondLabelBuilder(item));
    }).toList();

    // Get the index for _selectedItem (for initial scroll position).
    final firstInitialIndex = widget.firstItems.indexOf(_firstSelectedItem);
    final secondInitialIndex = widget.secondItems.indexOf(_secondSelectedItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(children: [
            Expanded(
              child: CupertinoPicker(
                magnification: 1.22,
                squeeze: 1.2,
                useMagnifier: true,
                itemExtent: _kItemExtent,
                scrollController: FixedExtentScrollController(
                  initialItem: firstInitialIndex >= 0 ? firstInitialIndex : 0,
                ),
                onSelectedItemChanged: (index) {
                  setState(() {
                    _firstSelectedItem = widget.firstItems[index];
                  });
                },
                children: firstChildren,
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                magnification: 1.22,
                squeeze: 1.2,
                useMagnifier: true,
                itemExtent: _kItemExtent,
                scrollController: FixedExtentScrollController(
                  initialItem: secondInitialIndex >= 0 ? secondInitialIndex : 0,
                ),
                onSelectedItemChanged: (index) {
                  setState(() {
                    _secondSelectedItem = widget.secondItems[index];
                  });
                },
                children: secondChildren,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        // Replace this button with your custom 'OpacityButtonWidget' if you like.
        OpacityButtonWidget(
          onPressed: () {
            final selectedItem = {
              "first": _firstSelectedItem,
              "second": _secondSelectedItem
            };
            widget.onItemSelected(selectedItem);
          },
          buttonColor: Theme.of(context).colors.vibrantAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          label: "Select ${widget.firstLabelBuilder(_firstSelectedItem)} ${widget.secondLabelBuilder(_secondSelectedItem)}",
        ),
      ],
    );
  }
}
