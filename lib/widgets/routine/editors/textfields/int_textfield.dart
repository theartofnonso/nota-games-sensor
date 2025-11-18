import 'package:flutter/material.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class IntTextField extends StatelessWidget {
  final int value;
  final TextEditingController controller;
  final void Function(int value) onChanged;
  final void Function() onTap;
  final int? maxLength;

  const IntTextField(
      {super.key,
      required this.value,
      required this.controller,
      required this.onChanged,
      required this.onTap,
      this.maxLength});

  int _parseIntOrDefault({required String value}) {
    return int.tryParse(value) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return TextField(
      controller: controller,
      cursorColor: isDarkMode ? Colors.white : Colors.black,
      onChanged: (value) => onChanged(_parseIntOrDefault(value: value)),
      onTap: onTap,
      maxLength: maxLength,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: "${value > 0 ? value : '-'}",
        hintStyle: TextStyle(
          color: theme.extension<TRKRColors>()?.textSecondary,
          fontSize: 15,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        counterText: "",
      ),
      keyboardType: TextInputType.number,
      maxLines: 1,
      textAlign: TextAlign.center,
    );
  }
}
