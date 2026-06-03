import 'package:flutter/foundation.dart';

import 'motion_payload.dart';

/// Publishes motion samples for dashboards / team views.
///
/// Today this is a no-op transport (debug log only). Swap the body of
/// [publishMotionData] for your transport without touching UI or controller code:
/// - Supabase Realtime channel: `channel.sendBroadcastMessage(event: 'motion', payload: …)`
/// - Firebase Realtime Database / Firestore with `onSnapshot` on the dashboard
/// - WebSocket `sink.add(jsonEncode(payload.toJson()))`
abstract final class MotionPublisher {
  MotionPublisher._();

  /// Latest payload per player — useful for an in-app debug dashboard later.
  static final Map<String, MotionPayload> latestByPlayerId = {};

  /// Call on every accelerometer tick while tracking.
  static void publishMotionData(MotionPayload payload) {
    latestByPlayerId[payload.playerId] = payload;

    // TODO(NOTA): Replace with real-time backend publish (Supabase / Firebase / WS).
    if (kDebugMode) {
      debugPrint(
        'NOTA motion ${payload.playerId.substring(0, 8)}… '
        'mag=${payload.acceleration.magnitude.toStringAsFixed(2)} '
        'smooth=${payload.acceleration.smoothedMagnitude.toStringAsFixed(2)} '
        'score=${payload.session.score.toStringAsFixed(1)}',
      );
    }
  }
}
