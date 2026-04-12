import 'package:flutter/material.dart';

import '../../utils/theme/color_extensions.dart';

/// Solid fill behind transparent PNG coach avatars (paywall, grid, cards, calls).
/// Uses [TRKRColors.sapphireDark80] so light/dark themes match the rest of the app.
abstract final class CoachProfilePhotoBackplate {
  CoachProfilePhotoBackplate._();

  static Color plateColor(BuildContext context) =>
      Theme.of(context).colors.sapphireDark80;

  /// Place behind full-bleed profile photos so transparent pixels read as sapphire panel.
  static Widget behind(BuildContext context, Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: plateColor(context)),
        Positioned.fill(child: child),
      ],
    );
  }
}
