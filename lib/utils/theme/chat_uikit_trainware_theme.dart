import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:trainware/utils/general_utils.dart';

import 'color_extensions.dart';

/// Fallback sapphire hue when a surface color is too neutral for HSL hue.
const double _kSapphireHue = 218;

double _hueFromColor(Color c, {double fallback = _kSapphireHue}) {
  final hsl = HSLColor.fromColor(c);
  if (hsl.saturation < 0.04) return fallback;
  final h = hsl.hue;
  return h.isFinite ? h : fallback;
}

/// Agora Chat UI Kit tuned to trainware dark theme: sapphire-tinted neutrals and
/// bubbles ([primaryColor2] / [primaryColor6] in the kit), plus [Grift] typography.
void applyTrainwareChatUIKitTheme() {
  const ext = TRKRColors.dark;

  final primaryHue = _hueFromColor(ext.sapphireDark80);
  final neutralHue = _hueFromColor(ext.dividerColor, fallback: primaryHue);
  final neutralSpecialHue = _hueFromColor(
    Color.lerp(ext.sapphireDark, ext.sapphireDark80, 0.5)!,
    fallback: primaryHue,
  );
  final secondaryHue = _hueFromColor(ext.vibrantAccent, fallback: 115);

  ChatUIKitTheme.instance.setColor(
    ChatUIKitColor.dark(
      primaryHue: primaryHue,
      secondaryHue: secondaryHue,
      errorHue: 350,
      neutralHue: neutralHue,
      neutralSpecialHue: neutralSpecialHue,
      barrageLightness: LightnessStyle.zero,
    ),
  );

  const ff = 'Grift';
  ChatUIKitTheme.instance.setFont(
    ChatUIKitFont(
      headlineLarge: const TextStyle(
        fontFamily: ff,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: const TextStyle(
        fontFamily: ff,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: const TextStyle(
        fontFamily: ff,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: const TextStyle(
        fontFamily: ff,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: const TextStyle(
        fontFamily: ff,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: const TextStyle(
        fontFamily: ff,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: const TextStyle(
        fontFamily: ff,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: const TextStyle(
        fontFamily: ff,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: const TextStyle(
        fontFamily: ff,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelExtraSmall: const TextStyle(
        fontFamily: ff,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
      bodyLarge: const TextStyle(
        fontFamily: ff,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: const TextStyle(
        fontFamily: ff,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: const TextStyle(
        fontFamily: ff,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      bodyExtraSmall: const TextStyle(
        fontFamily: ff,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}

TRKRColors _trkrColors(BuildContext context) {
  return Theme.of(context).extension<TRKRColors>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? TRKRColors.dark
          : TRKRColors.light);
}

/// Same vertical gradient as the rest of the app ([themeGradient]), sized to
/// fill the chat kit’s background stack (over the kit’s flat neutral layer).
Widget trainwareChatBackground(BuildContext context) {
  return SizedBox.expand(
    child: DecoratedBox(
      decoration: BoxDecoration(gradient: themeGradient(context: context)),
    ),
  );
}

Color _trainwareBubbleReceived(BuildContext context) {
  final ext = _trkrColors(context);
  if (Theme.of(context).brightness == Brightness.dark) {
    // Neutral charcoal (same family as [TRKRColors.containerBackground]), not
    // [dividerColor] / sapphireLighter — those read noticeably blue on screen.
    return ext.containerBackground;
  }
  return ext.sapphireDark80;
}

Color _trainwareBubbleSent(BuildContext context) {
  final ext = _trkrColors(context);
  if (Theme.of(context).brightness == Brightness.dark) {
    return Color.alphaBlend(
      Colors.white.withValues(alpha: 0.5),
      ext.containerBackground,
    );
  }
  return Color.alphaBlend(
    Colors.black.withValues(alpha: 0.18),
    ext.sapphireDark80,
  );
}

/// Neutral elevated bubbles (charcoal / light grey); pairs with the kit’s
/// text colors (dark text on sent / light text on received in dark mode).
Widget? trainwareChatBubbleBuilder(
  BuildContext context,
  Widget child,
  MessageModel model,
) {
  final left = model.message.direction == MessageDirection.RECEIVE;
  final color =
      left ? _trainwareBubbleReceived(context) : _trainwareBubbleSent(context);
  return ChatUIKitMessageBubbleWidget(
    key: ValueKey(model.message.localTime),
    needSmallCorner: model.message.getQuote == null,
    isLeft: left,
    color: color,
    isVisible: !(model.message.bodyType == MessageType.VIDEO ||
        model.message.bodyType == MessageType.IMAGE),
    child: child,
  );
}
