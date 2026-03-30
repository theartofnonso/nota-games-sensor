import 'dart:ui';

// ============================================================================
// trainware THEME - Core Color Palette
// ============================================================================

// Backgrounds
const bgPrimary = Color(0xFF0a0a0a); // Near-black base (OLED optimized)
const bgSecondary = Color(0xFF141414); // Elevated surfaces

// Text Colors (use with opacity for hierarchy)
const textPrimary = Color(0xFFFFFFFF); // Main content
const textSecondary = Color(0xFFa0a0a0); // Subdued text

// Semantic Colors - Success/Active (Green)
const success = Color(0xFF22c55e); // Tailwind green-500
const successDark = Color(0xFF15803d); // Tailwind green-700

// Semantic Colors - Info/Processing (Blue)
const info = Color(0xFF3b82f6); // Tailwind blue-500
const infoDark = Color(0xFF1e40af); // Tailwind blue-800

// Semantic Colors - Error/Danger (Red)
const error = Color(0xFFef4444); // Tailwind red-500
const errorDark = Color(0xFF991b1b); // Tailwind red-900

// Glassmorphism Colors
const glassLight = Color(0x0DFFFFFF); // white/5
const glassMedium = Color(0x1AFFFFFF); // white/10
const glassDark = Color(0x4D18181B); // zinc-900/30

// Border Colors (use with white + opacity)
const borderLight = Color(0x1AFFFFFF); // white/10
const borderMedium = Color(0x33FFFFFF); // white/20
const borderSubtle = Color(0x0DFFFFFF); // white/5

/// Deeper yellow frosted gradient (nutrition create row, calorie & fat cards).
/// Tailwind yellow 400 → 600 — still yellow, less harsh than 200–400.
const nutritionFrostedGradientColors = <Color>[
  Color(0xFFFACC15), // yellow-400
  Color(0xFFEAB308), // yellow-500
  Color(0xFFCA8A04), // yellow-600
];

// Glow Colors (for shadows/glows)
const successGlow = Color(0x6622c55e); // rgba(34, 197, 94, 0.4)
const infoGlow = Color(0x993b82f6); // rgba(59, 130, 246, 0.6)
const errorGlow = Color(0x99ef4444); // rgba(239, 68, 68, 0.6)

// ============================================================================
// Legacy Colors (keeping for backward compatibility)
// ============================================================================
const sapphireLighter = Color.fromRGBO(37, 41, 54, 1);
const sapphireDark = Color.fromRGBO(12, 14, 18, 1);
const sapphireDark80 = Color.fromRGBO(27, 33, 38, 1.0);
const charcoalContainer = Color(0xFF212121);
const mutedGreen = Color(0xFF3A5C4A);
const lightBackground = Color(0xFFFAFAFA);
const lightContainer = Color(0xFFF5F5F5);
const freshGreen = Color(0xFF4CAF50);
const vibrantGreen = Color.fromRGBO(43, 242, 12, 1);
const vibrantBlue = Color.fromRGBO(3, 140, 236, 1.0);
