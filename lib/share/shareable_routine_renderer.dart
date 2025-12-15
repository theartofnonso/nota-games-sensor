import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:trainware/dtos/shareable_routine_summary.dart';
import 'package:trainware/widgets/share/shareable_routine_templates.dart';

enum ShareVariant { standard, durationSplit, durationSplitCentered }

class ShareableRoutineRenderer {
  ShareableRoutineRenderer({this.pixelRatio = 3.0});

  final double pixelRatio;

  Future<Uint8List> renderPrimary({
    required BuildContext context,
    required ShareableRoutineSummary summary,
    ShareVariant variant = ShareVariant.standard,
  }) {
    final widget = UnconstrainedBox(
      clipBehavior: Clip.none,
      child: switch (variant) {
        ShareVariant.standard =>
          ShareableRoutineVerticalCard(summary: summary),
        ShareVariant.durationSplit =>
          ShareableRoutineVerticalCardDurationSplit(summary: summary),
        ShareVariant.durationSplitCentered =>
          ShareableRoutineVerticalCardDurationSplitCentered(
              summary: summary),
      },
    );
    return _renderWidgetToImage(context: context, widget: widget);
  }

  Future<Uint8List> _renderWidgetToImage({
    required BuildContext context,
    required Widget widget,
  }) async {
    final repaintKey = GlobalKey();
    final overlayState = Overlay.of(context, rootOverlay: true);

    final entry = OverlayEntry(
      builder: (_) => Center(
        child: RepaintBoundary(
          key: repaintKey,
          child: widget,
        ),
      ),
    );

    overlayState.insert(entry);

    // Wait for the frame to paint before capturing.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      entry.remove();
      throw StateError('Could not obtain render boundary for share asset.');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    entry.remove();

    if (byteData == null) {
      throw StateError('Failed to encode share asset as PNG.');
    }

    return byteData.buffer.asUint8List();
  }
}
