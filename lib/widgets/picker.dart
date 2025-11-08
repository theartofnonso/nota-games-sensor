import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'buttons/opacity_button_widget_two.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class GenericPicker<T> extends StatefulWidget {
  /// The initially selected item (optional).
  final T? initialValue;

  /// The list of items to display in the picker.
  final List<T> items;

  /// Callback to return a user-friendly label for each item (e.g., 'Male', 'Female').
  final String Function(T item) labelBuilder;

  /// Callback invoked when the user confirms their selection.
  final ValueChanged<T> onItemSelected;

  const GenericPicker({
    super.key,
    required this.items,
    required this.labelBuilder,
    required this.onItemSelected,
    this.initialValue,
  });

  @override
  State<GenericPicker<T>> createState() => _GenericPickerState<T>();
}

class _GenericPickerState<T> extends State<GenericPicker<T>> {
  late T _selectedItem;

  static const double _kItemExtent = 32.0;

  @override
  void initState() {
    super.initState();

    // If initialValue is provided and exists in the item list, use it;
    // otherwise, default to the first item (if the list isn't empty).
    if (widget.initialValue != null &&
        widget.items.contains(widget.initialValue)) {
      _selectedItem = widget.initialValue as T;
    } else if (widget.items.isNotEmpty) {
      _selectedItem = widget.items.first;
    } else {
      // Handle empty items list scenario here if needed.
      // For demonstration, we'll just throw:
      throw ArgumentError(
          'GenericPicker cannot be built with an empty items list.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convert each item into a Text widget using labelBuilder.
    final children = widget.items.map((item) {
      return Text(widget.labelBuilder(item));
    }).toList();

    // Get the index for _selectedItem (for initial scroll position).
    final initialIndex = widget.items.indexOf(_selectedItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: CupertinoPicker(
            magnification: 1.22,
            squeeze: 1.2,
            useMagnifier: true,
            itemExtent: _kItemExtent,
            scrollController: FixedExtentScrollController(
              initialItem: initialIndex >= 0 ? initialIndex : 0,
            ),
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedItem = widget.items[index];
              });
            },
            children: children,
          ),
        ),
        const SizedBox(height: 10),
        // Replace this button with your custom 'OpacityButtonWidget' if you like.
        OpacityButtonWidgetTwo(
          onPressed: () => widget.onItemSelected(_selectedItem),
          buttonColor: Theme.of(context).colors.vibrantAccent,
          label: "Select ${widget.labelBuilder(_selectedItem)}",
        ),
      ],
    );
  }
}
