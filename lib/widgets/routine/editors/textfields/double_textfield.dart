import 'package:flutter/material.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class DoubleTextField extends StatelessWidget {
  final num value;
  final TextEditingController controller;
  final void Function(double value) onChanged;
  final void Function()? onTap;
  final TextAlign? textAlign;
  final int? maxLength;
  final String? suffix;

  const DoubleTextField(
      {super.key,
      required this.value,
      required this.controller,
      required this.onChanged,
      this.onTap,
      this.textAlign,
      this.maxLength,
      this.suffix});

  double _parseDoubleOrDefault({required String value}) {
    return double.tryParse(value) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return TextField(
      controller: controller,
      onTap: onTap,
      cursorColor: isDarkMode ? Colors.white : Colors.black,
      onChanged: (value) => onChanged(_parseDoubleOrDefault(value: value)),
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
        suffixText: suffix,
        suffixStyle: TextStyle(
          color: theme.extension<TRKRColors>()?.textSecondary,
          fontSize: 13,
        ),
        counterText: "",
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      maxLines: 1,
      textAlign: textAlign ?? TextAlign.center,
    );
  }
}
