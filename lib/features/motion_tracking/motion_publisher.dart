import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'motion_payload.dart';

/// Publishes motion batches to the backend.
///
/// Today this is a stub transport (debug log only). Swap the body of
/// [publishMotionBatch] for your transport without touching UI or controller code.
abstract final class MotionPublisher {
  MotionPublisher._();

  /// Latest batch per player — useful for an in-app debug dashboard later.
  static final Map<String, PlayerMotionBatch> latestBatchByPlayerId = {};

  /// Call once per batch window (~1 s) while the sensor is active.
  static void publishMotionBatch(PlayerMotionBatch batch) {
    latestBatchByPlayerId[batch.playerId] = batch;

    // TODO(NOTA): Replace with real backend POST (Supabase / REST / WS).
    if (kDebugMode) {
      debugPrint(
        'NOTA motion batch ${batch.playerId.substring(0, 8)}… '
        'samples=${batch.samples.length} '
        'payload=${jsonEncode(batch.toJson())}',
      );
    }
  }
}
