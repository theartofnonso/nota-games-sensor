import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Edge-to-edge horizontal list: symmetric [ListView.padding] so the first
/// [itemSize] slot is centered when the scroll offset is zero, and the last
/// item can scroll to the same centered position.
class ExerciseAlternativesHorizontalList extends StatelessWidget {
  /// When null, uses [MediaQuery.sizeOf] width (full screen). Pass a finite
  /// width when the strip sits inside a narrower parent (e.g. list tile).
  final double? widthOverride;

  final double itemSize;
  final double gap;
  final int itemCount;
  final ScrollPhysics? physics;
  final IndexedWidgetBuilder itemBuilder;

  const ExerciseAlternativesHorizontalList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.widthOverride,
    this.itemSize = 80,
    this.gap = 8,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final vw = widthOverride ?? MediaQuery.sizeOf(context).width;
    final inset = math.max(0.0, (vw - itemSize) / 2);

    return SizedBox(
      height: itemSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: inset),
        physics: physics ?? const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: itemCount,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
