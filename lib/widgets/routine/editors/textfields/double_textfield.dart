import 'package:flutter/material.dart';

class DoubleTextField extends StatelessWidget {
  final num value;
  final TextEditingController controller;
  final void Function(double value) onChanged;
  final void Function()? onTap;
  final TextAlign? textAlign;
  final int? maxLength;

  const DoubleTextField(
      {super.key, required this.value, required this.controller, required this.onChanged, this.onTap, this.textAlign, this.maxLength});

  double _parseDoubleOrDefault({required String value}) {
    return double.tryParse(value) ?? 0;
  }

  @override
  Widget build(BuildContext context) {

    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return TextField(
      controller: controller,
      onTap: onTap,
      cursorColor: isDarkMode ? Colors.white : Colors.black,
      onChanged: (value) => onChanged(_parseDoubleOrDefault(value: value)),
      maxLength: maxLength,
      decoration: InputDecoration(
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.transparent)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.transparent)),
          counterText: "",
          hintText: "${value > 0 ? value : '-'}"),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      maxLines: 1,
      textAlign: textAlign ?? TextAlign.center,
    );
  }
}
