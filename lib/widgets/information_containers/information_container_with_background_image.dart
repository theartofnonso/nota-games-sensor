import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// ---------------------------------------------------------------------------
///  MembershipPromoCard
/// ---------------------------------------------------------------------------
///  Screenshot‑style promotional banner:
///    • Background image (full‑bleed) with dark bottom gradient
///    • Headline + body copy in the foreground (bottom‑left)
///    • Chevron‑right icon in the foreground (bottom‑right)
///    • Rounded corners, subtle drop‑shadow, tap callback
/// ---------------------------------------------------------------------------
class InformationContainerWithBackgroundImage extends StatelessWidget {
  const InformationContainerWithBackgroundImage({
    super.key,
    required this.image,
    required this.subtitle,
    this.onTap,
    required this.color,
    this.height = 160,
    this.borderRadius = 12,
    this.alignmentGeometry,
  });

  /// Background image (use AssetImage, NetworkImage, etc.).
  final String image;

  /// Descriptive copy under the headline.
  final String subtitle;

  /// Called when the user taps anywhere on the card.
  final VoidCallback? onTap;

  /// Fixed height of the card; width stretches to parent.
  final double height;

  /// Corner radius.
  final double borderRadius;

  final Color color;

  final AlignmentGeometry? alignmentGeometry;

  @override
  Widget build(BuildContext context) {
    final callback = onTap;

    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1️⃣ Background image
              Image.asset(
                image,
                fit: BoxFit.cover,
                width: double.infinity,
                alignment: alignmentGeometry ?? Alignment.topCenter,
              ),
              // 2️⃣ Gradient overlay (transparent → dark)
              Positioned.fill(
                child: Container(
                  color: color.withValues(alpha: 0.6),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Text column expands; arrow stays fixed size.
                    Expanded(
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (callback != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const FaIcon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
