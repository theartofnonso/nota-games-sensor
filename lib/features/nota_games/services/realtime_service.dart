import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/player_session.dart';
import '../models/session_runtime_state.dart';

/// Owns `session:{id}:state`, `session:{id}:scores`, and `session:{id}:presence`.
class RealtimeService {
  RealtimeChannel? _stateChannel;
  RealtimeChannel? _scoresChannel;
  RealtimeChannel? _presenceChannel;

  final _stateController =
      StreamController<SessionRuntimeState>.broadcast();

  Stream<SessionRuntimeState> get stateStream => _stateController.stream;

  Future<void> connect(PlayerSession session) async {
    await disconnect();

    final client = Supabase.instance.client;
    final sessionId = session.sessionId;

    _stateChannel = client
        .channel('session:$sessionId:state')
        .onBroadcast(
          event: 'session_state_change',
          callback: _onStateBroadcast,
        );

    // Scores channel — subscribed per handoff; scoreboard is handled by the web app.
    _scoresChannel = client
        .channel('session:$sessionId:scores')
        .onBroadcast(event: 'leaderboard_update', callback: (_) {})
        .onBroadcast(event: 'presence_update', callback: (_) {});

    _presenceChannel = client.channel('session:$sessionId:presence');

    await _waitForSubscribed(_stateChannel!, 'state');
    await _waitForSubscribed(_scoresChannel!, 'scores');
    await _trackPresence(session);
  }

  void _onStateBroadcast(Map<String, dynamic> payload) {
    if (kDebugMode) {
      debugPrint('NOTA session_state_change raw: $payload');
    }
    final state = SessionRuntimeState.fromSessionStateChange(payload);
    if (kDebugMode) {
      debugPrint(
        'NOTA session_state_change parsed: sensorActive=${state.sensorActive} '
        'sessionEnded=${state.sessionEnded} phase=${state.phase}',
      );
    }
    _stateController.add(state);
  }

  Future<void> _waitForSubscribed(
    RealtimeChannel channel,
    String label,
  ) async {
    final ready = Completer<void>();
    channel.subscribe((status, error) {
      if (kDebugMode) {
        debugPrint('NOTA $label channel status: $status ${error ?? ''}');
      }
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (!ready.isCompleted) ready.complete();
      } else if (status == RealtimeSubscribeStatus.channelError &&
          !ready.isCompleted) {
        ready.completeError(error ?? StateError('$label channel error'));
      }
    });

    try {
      await ready.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTA $label channel subscribe failed: $e');
      }
    }
  }

  Future<void> _trackPresence(PlayerSession session) async {
    final presenceChannel = _presenceChannel!;
    final presencePayload = <String, dynamic>{
      'playerId': session.playerId,
      'playerName': session.playerName,
      'joinedAt': DateTime.now().millisecondsSinceEpoch,
      if (session.teamId != null) 'teamId': session.teamId,
    };

    final ready = Completer<void>();
    presenceChannel.subscribe((status, error) async {
      if (error != null && kDebugMode) {
        debugPrint('NOTA presence subscribe error: $error');
      }
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await presenceChannel.track(presencePayload);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('NOTA presence track error: $e');
          }
        }
        if (!ready.isCompleted) ready.complete();
      } else if (status == RealtimeSubscribeStatus.channelError &&
          !ready.isCompleted) {
        ready.completeError(
          error ?? StateError('presence channel error'),
        );
      }
    });

    try {
      await ready.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTA presence subscribe failed: $e');
      }
    }
  }

  Future<void> disconnect() async {
    final client = Supabase.instance.client;

    if (_presenceChannel != null) {
      try {
        await _presenceChannel!.untrack();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('NOTA presence untrack error: $e');
        }
      }
      await client.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
    if (_scoresChannel != null) {
      await client.removeChannel(_scoresChannel!);
      _scoresChannel = null;
    }
    if (_stateChannel != null) {
      await client.removeChannel(_stateChannel!);
      _stateChannel = null;
    }
  }

  void dispose() {
    unawaited(disconnect());
    _stateController.close();
  }
}
