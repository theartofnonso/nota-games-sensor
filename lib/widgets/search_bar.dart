import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


import 'package:tracker_app/utils/theme/color_extensions.dart';

class CSearchBar extends StatelessWidget {
  final Function(String) onChanged;
  final Function() onClear;
  final String hintText;
  final TextEditingController controller;

  const CSearchBar(
      {super.key, required this.onChanged, required this.onClear, required this.hintText, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SearchBar(
        controller: controller,
        onChanged: onChanged,
        trailing: [
          IconButton(
            onPressed: onClear,
            icon: const FaIcon(
              FontAwesomeIcons.squareXmark,
              color: Colors.white,
            ),
          )
        ],
        hintText: hintText,
        hintStyle: WidgetStatePropertyAll<TextStyle>(TextStyle(color: Colors.white70)),
        textStyle: WidgetStatePropertyAll<TextStyle>(TextStyle(color: Colors.white)),
        backgroundColor: WidgetStatePropertyAll<Color>(Theme.of(context).colors.sapphireDark),
        shape: WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.0),
        )));
  }
}
