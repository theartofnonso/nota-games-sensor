import 'package:flutter/material.dart';

/// Custom color extension for TRNR theme
/// Access via: Theme.of(context).extension TRKRColors borderLight
class TRKRColors extends ThemeExtension<TRKRColors> {
  final Color containerBackground;
  final Color borderLight;
  final Color borderMedium;
  final Color borderSubtle;
  final Color textSecondary;
  final Color mutedGreen;
  final Color glassLight;
  final Color glassMedium;
  final Color glassDark;
  final Color successGlow;
  final Color infoGlow;
  final Color errorGlow;
  final Color dividerColor;
  final Color vibrantAccent;
  final Color sapphireDark;
  final Color sapphireDark80;

  const TRKRColors({
    required this.containerBackground,
    required this.borderLight,
    required this.borderMedium,
    required this.borderSubtle,
    required this.textSecondary,
    required this.mutedGreen,
    required this.glassLight,
    required this.glassMedium,
    required this.glassDark,
    required this.successGlow,
    required this.infoGlow,
    required this.errorGlow,
    required this.dividerColor,
    required this.vibrantAccent,
    required this.sapphireDark,
    required this.sapphireDark80,
  });

  // Light theme colors
  static const light = TRKRColors(
    containerBackground: Color(0xFFF5F5F5), // lightContainer
    borderLight: Color(0x1A000000), // black/10
    borderMedium: Color(0x33000000), // black/20
    borderSubtle: Color(0x0D000000), // black/5
    textSecondary: Color(0xFF666666),
    mutedGreen: Color(0xFF3A5C4A),
    glassLight: Color(0x0D000000),
    glassMedium: Color(0x1A000000),
    glassDark: Color(0x4D000000),
    successGlow: Color(0x664CAF50),
    infoGlow: Color(0x993b82f6),
    errorGlow: Color(0x99ef4444),
    dividerColor: Color(0xFFE0E0E0),
    vibrantAccent: Color(0xFF4CAF50), // freshGreen
    sapphireDark: Color(0xFFE8E8E8), // Light grey for light theme
    sapphireDark80: Color(0xFFF0F0F0), // Lighter grey for light theme
  );

  // Dark theme colors
  static const dark = TRKRColors(
    containerBackground: Color(0xFF212121), // charcoalContainer (legacy)
    borderLight: Color(0x1AFFFFFF), // white/10
    borderMedium: Color(0x33FFFFFF), // white/20
    borderSubtle: Color(0x0DFFFFFF), // white/5
    textSecondary: Color(0xFFa0a0a0),
    mutedGreen: Color(0xFF3A5C4A),
    glassLight: Color(0x0DFFFFFF), // white/5
    glassMedium: Color(0x1AFFFFFF), // white/10
    glassDark: Color(0x4D18181B), // zinc-900/30
    successGlow: Color(0x6622c55e), // rgba(34, 197, 94, 0.4)
    infoGlow: Color(0x993b82f6), // rgba(59, 130, 246, 0.6)
    errorGlow: Color(0x99ef4444), // rgba(239, 68, 68, 0.6)
    dividerColor: Color.fromRGBO(37, 41, 54, 1), // sapphireLighter
    vibrantAccent: Color.fromRGBO(43, 242, 12, 1), // vibrantGreen
    sapphireDark: Color.fromRGBO(12, 14, 18, 1), // sapphireDark
    sapphireDark80: Color.fromRGBO(27, 33, 38, 1.0), // sapphireDark80
  );

  @override
  ThemeExtension<TRKRColors> copyWith({
    Color? containerBackground,
    Color? borderLight,
    Color? borderMedium,
    Color? borderSubtle,
    Color? textSecondary,
    Color? mutedGreen,
    Color? glassLight,
    Color? glassMedium,
    Color? glassDark,
    Color? successGlow,
    Color? infoGlow,
    Color? errorGlow,
    Color? dividerColor,
    Color? vibrantAccent,
    Color? sapphireDark,
    Color? sapphireDark80,
  }) {
    return TRKRColors(
      containerBackground: containerBackground ?? this.containerBackground,
      borderLight: borderLight ?? this.borderLight,
      borderMedium: borderMedium ?? this.borderMedium,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textSecondary: textSecondary ?? this.textSecondary,
      mutedGreen: mutedGreen ?? this.mutedGreen,
      glassLight: glassLight ?? this.glassLight,
      glassMedium: glassMedium ?? this.glassMedium,
      glassDark: glassDark ?? this.glassDark,
      successGlow: successGlow ?? this.successGlow,
      infoGlow: infoGlow ?? this.infoGlow,
      errorGlow: errorGlow ?? this.errorGlow,
      dividerColor: dividerColor ?? this.dividerColor,
      vibrantAccent: vibrantAccent ?? this.vibrantAccent,
      sapphireDark: sapphireDark ?? this.sapphireDark,
      sapphireDark80: sapphireDark80 ?? this.sapphireDark80,
    );
  }

  @override
  ThemeExtension<TRKRColors> lerp(
    covariant ThemeExtension<TRKRColors>? other,
    double t,
  ) {
    if (other is! TRKRColors) {
      return this;
    }
    return TRKRColors(
      containerBackground:
          Color.lerp(containerBackground, other.containerBackground, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      borderMedium: Color.lerp(borderMedium, other.borderMedium, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      mutedGreen: Color.lerp(mutedGreen, other.mutedGreen, t)!,
      glassLight: Color.lerp(glassLight, other.glassLight, t)!,
      glassMedium: Color.lerp(glassMedium, other.glassMedium, t)!,
      glassDark: Color.lerp(glassDark, other.glassDark, t)!,
      successGlow: Color.lerp(successGlow, other.successGlow, t)!,
      infoGlow: Color.lerp(infoGlow, other.infoGlow, t)!,
      errorGlow: Color.lerp(errorGlow, other.errorGlow, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      vibrantAccent: Color.lerp(vibrantAccent, other.vibrantAccent, t)!,
      sapphireDark: Color.lerp(sapphireDark, other.sapphireDark, t)!,
      sapphireDark80: Color.lerp(sapphireDark80, other.sapphireDark80, t)!,
    );
  }
}

/// Extension to make accessing custom colors easier
extension ThemeExtensions on ThemeData {
  TRKRColors get colors => extension<TRKRColors>()!;
}
