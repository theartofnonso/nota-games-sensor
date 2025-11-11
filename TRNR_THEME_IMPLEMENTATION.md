# trainware Theme Implementation Guide

This document outlines the implementation of the trainware Theme - a dark, minimalist iOS-inspired glassmorphism design system for the TRACKR app.

---

## 📋 What Was Implemented

### 1. **Core Color Palette** (`lib/colors.dart`)

The complete trainware color system has been added:

#### Backgrounds
- `bgPrimary` (#0a0a0a) - Near-black OLED-optimized base
- `bgSecondary` (#141414) - Elevated surfaces

#### Text Colors
- `textPrimary` (#FFFFFF) - Main content (use with opacity for hierarchy)
- `textSecondary` (#a0a0a0) - Subdued text

#### Semantic Colors
- **Success/Active (Green)**
  - `success` (#22c55e) - Tailwind green-500
  - `successDark` (#15803d) - Darker variant
  - `successGlow` - For shadows/glows

- **Info/Processing (Blue)**
  - `info` (#3b82f6) - Tailwind blue-500
  - `infoDark` (#1e40af) - Darker variant
  - `infoGlow` - For shadows/glows

- **Error/Danger (Red)**
  - `error` (#ef4444) - Tailwind red-500
  - `errorDark` (#991b1b) - Darker variant
  - `errorGlow` - For shadows/glows

#### Glassmorphism Support
- `glassLight`, `glassMedium`, `glassDark` - Background opacity layers
- `borderLight`, `borderMedium`, `borderSubtle` - Border colors

---

### 2. **Glassmorphism Widgets** (`lib/widgets/glass_container.dart`)

Three reusable components for the trainware aesthetic:

#### **GlassContainer**
```dart
GlassContainer(
  style: GlassStyle.medium,
  padding: const EdgeInsets.all(20),
  borderRadius: BorderRadius.circular(16),
  child: YourWidget(),
)
```

**Styles:**
- `GlassStyle.light` - bg-white/5, border-white/10
- `GlassStyle.medium` - bg-white/10, border-white/20
- `GlassStyle.dark` - bg-zinc-900/30, border-white/5

#### **GlassButton**
```dart
GlassButton(
  onPressed: () {},
  glowState: GlowState.active,
  child: const Text('Click Me'),
)
```

**Glow States:**
- `GlowState.idle` - Green glow (success)
- `GlowState.active` - Blue glow (processing)
- `GlowState.error` - Red glow (error)
- `GlowState.none` - No glow

#### **StatusIndicator**
```dart
StatusIndicator(
  label: 'Active',
  type: StatusType.success,
)
```

**Types:** `StatusType.success`, `StatusType.info`, `StatusType.error`

---

### 3. **Theme Configuration Updates**

#### **Dark Theme** (`lib/utils/theme/theme.dart`)
- Primary color: `success` (green #22c55e)
- Background: `bgPrimary` (near-black #0a0a0a)
- Surface: `bgSecondary` (#141414)
- Text: `textPrimary` / `textSecondary`

#### **Input Fields** (`lib/utils/theme/input_textfield_theme.dart`)
- Border radius increased to 16px
- Dark theme uses `bgSecondary` fill
- Borders use trainware border colors
- Focus border highlights with success green

#### **App Bar** (`lib/utils/theme/app_bar_theme.dart`)
- Dark theme: `bgPrimary` background
- Foreground: `textPrimary`

#### **Floating Action Buttons** (`lib/utils/theme/floating_action_button_theme.dart`)
- Dark theme: `success` green background
- Border radius: 16px
- Elevation: 8

#### **Navigation Bar** (`lib/utils/theme/navigation_bar_theme.dart`)
- Dark theme: `bgSecondary` background
- Zero elevation for seamless integration

#### **List Tiles** (`lib/utils/theme/list_title_theme.dart`)
- Border radius: 16px (up from 5px)
- Text colors use trainware palette
- Improved padding and spacing

---

### 4. **Auth Screen Update** (`lib/screens/auth/supabase_auth_screen.dart`)

Updated buttons to use trainware success green (#22c55e) instead of muted green:
- Continue button: Bright success green
- Verify button: Bright success green
- Text opacity adjusted to 90% for optimal readability

---

## 🎨 Design Principles

1. **Dark-First**: Near-black base (#0a0a0a) optimized for OLED displays
2. **Opacity Hierarchy**: Use white with opacity layers instead of gray shades
3. **3-Color Semantic System**: Green (success), Blue (info), Red (error)
4. **Glassmorphism**: Heavy blur + low opacity + subtle borders
5. **Minimal Motion**: Smooth transitions, avoid distracting animations
6. **Rounded Corners**: 16px radius for modern feel

---

## 📖 Usage Examples

### Example 1: Glass Card
```dart
GlassContainer(
  style: GlassStyle.medium,
  padding: const EdgeInsets.all(20),
  child: Column(
    children: [
      Text(
        'Workout Session',
        style: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '45 minutes • Upper Body',
        style: TextStyle(
          color: textPrimary.withOpacity(0.6),
          fontSize: 14,
        ),
      ),
    ],
  ),
)
```

### Example 2: Glass Button with Glow
```dart
GlassButton(
  onPressed: () => startWorkout(),
  glowState: GlowState.active,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Start Workout'),
      const SizedBox(width: 8),
      const Icon(Icons.play_arrow, size: 18),
    ],
  ),
)
```

### Example 3: Status Badge
```dart
Row(
  children: [
    StatusIndicator(label: 'Active', type: StatusType.success),
    const SizedBox(width: 8),
    StatusIndicator(label: 'Processing', type: StatusType.info),
  ],
)
```

### Example 4: Complete Card with Status
```dart
GlassContainer(
  style: GlassStyle.medium,
  padding: const EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 16,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Workout Session',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          StatusIndicator(
            label: 'Active',
            type: StatusType.success,
          ),
        ],
      ),
      Text(
        '45 minutes • Upper Body',
        style: TextStyle(
          color: textPrimary.withOpacity(0.6),
          fontSize: 14,
        ),
      ),
      GlassButton(
        onPressed: () {},
        glowState: GlowState.active,
        child: const Text('Continue Workout'),
      ),
    ],
  ),
)
```

---

## 🔄 Opacity Scale (Text Hierarchy)

Use white with opacity for text hierarchy:

```dart
// Primary emphasis
Text('Heading', style: TextStyle(color: textPrimary.withOpacity(0.9)))

// Secondary content
Text('Subheading', style: TextStyle(color: textPrimary.withOpacity(0.7)))

// Tertiary elements
Text('Caption', style: TextStyle(color: textPrimary.withOpacity(0.5)))

// Placeholders
Text('Hint', style: TextStyle(color: textPrimary.withOpacity(0.3)))
```

---

## 🎯 Border Radius Scale

Standard border radii throughout the app:

- **2px** - Small elements
- **8px** - Compact UI elements
- **12px** - Standard inputs
- **16px** - Cards, containers, buttons
- **9999px** - Pills, status indicators, rounded buttons

---

## 🌟 Interactive States

### Hover/Press Effects (for buttons)
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOut,
  // Your content
)
```

### Transition Timing
- **200ms** - Quick feedback
- **300ms** - General UI transitions
- **500ms** - Fade in animations

---

## 📁 Files Modified/Created

### Created:
- `lib/widgets/glass_container.dart` - Glassmorphism components
- `lib/widgets/glass_container_example.dart` - Usage examples
- `trainware_THEME_IMPLEMENTATION.md` - This documentation

### Modified:
- `lib/colors.dart` - Complete trainware color palette
- `lib/utils/theme/theme.dart` - Dark theme configuration
- `lib/utils/theme/input_textfield_theme.dart` - Input styling
- `lib/utils/theme/app_bar_theme.dart` - App bar styling
- `lib/utils/theme/floating_action_button_theme.dart` - FAB styling
- `lib/utils/theme/navigation_bar_theme.dart` - Nav bar styling
- `lib/utils/theme/list_title_theme.dart` - List tile styling
- `lib/screens/auth/supabase_auth_screen.dart` - Auth button colors

---

## 🚀 Next Steps

1. **Apply Glass Containers** to existing screens
2. **Replace standard buttons** with `GlassButton` where appropriate
3. **Add Status Indicators** to workout sessions, exercises, etc.
4. **Update card widgets** to use `GlassContainer`
5. **Implement backdrop blur** for modals and overlays

---

## 💡 Tips

1. Always use `textPrimary` with opacity for text hierarchy
2. Use semantic colors (success, info, error) for state indication
3. Keep glassmorphism subtle - don't overuse
4. Test on actual devices for blur performance
5. Ensure sufficient contrast for accessibility

---

## 📚 Reference

For more patterns and examples, see:
- `lib/widgets/glass_container_example.dart` - Live examples
- Original trainware Theme specification provided by user

---

**Implementation Complete** ✅

All trainware Theme components are now available throughout the app. Use the glassmorphism widgets to create a consistent, modern, iOS-inspired dark aesthetic.

