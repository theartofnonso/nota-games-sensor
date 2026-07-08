import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leaderboard_update.dart';
import '../models/player_session.dart';
import '../models/presence_update.dart';
import '../models/session_state_change.dart';

/// Owns `session:{id}:state`, `session:{id}:scores`, and `session:{id}:presence`.
class RealtimeService {
  RealtimeChannel? _stateChannel;
  RealtimeChannel? _scoresChannel;
  RealtimeChannel? _presenceChannel;

  final _stateController =
      StreamController<SessionStateChange>.broadcast();
  final _leaderboardController =
      StreamController<LeaderboardUpdate>.broadcast();
  final _presenceController =
      StreamController<PresenceUpdate>.broadcast();

  Stream<SessionStateChange> get stateStream => _stateController.stream;
  Stream<LeaderboardUpdate> get leaderboardStream =>
      _leaderboardController.stream;
  Stream<PresenceUpdate> get presenceStream => _presenceController.stream;

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

    _scoresChannel = client
        .channel('session:$sessionId:scores')
        .onBroadcast(
          event: 'leaderboard_update',
          callback: _onLeaderboardBroadcast,
        )
        .onBroadcast(
          event: 'presence_update',
          callback: _onPresenceBroadcast,
        );

    _presenceChannel = client.channel('session:$sessionId:presence');

    await _subscribeChannel(_stateChannel!, 'state');
    await _subscribeChannel(_scoresChannel!, 'scores');
    await _subscribePresence(session);
  }

  void _onStateBroadcast(Map<String, dynamic> payload) {
    if (kDebugMode) {
      debugPrint('NOTA session_state_change raw: $payload');
    }
    final change = SessionStateChange.fromBroadcast(payload);
    if (kDebugMode) {
      debugPrint(
        'NOTA session_state_change parsed: sensorActive=${change.sensorActive} '
        'sessionEnded=${change.sessionEnded} phase=${change.phase}',
      );
    }
    _stateController.add(change);
  }

  void _onLeaderboardBroadcast(Map<String, dynamic> payload) {
    try {
      final update = LeaderboardUpdate.fromJson(payload);
      _leaderboardController.add(update);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTA leaderboard_update parse error: $e');
      }
    }
  }

  void _onPresenceBroadcast(Map<String, dynamic> payload) {
    try {
      final update = PresenceUpdate.fromJson(payload);
      _presenceController.add(update);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTA presence_update parse error: $e');
      }
    }
  }

  Future<void> _subscribeChannel(
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

  Future<void> _subscribePresence(PlayerSession session) async {
    final presenceChannel = _presenceChannel!;
    final team = session.team;
    final presencePayload = <String, dynamic>{
      'playerId': session.playerId,
      'playerName': session.playerName,
      'teamId': team?.id,
      'teamName': team?.name,
      'teamColor': team?.color,
      'joinedAt': DateTime.now().millisecondsSinceEpoch,
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
    _leaderboardController.close();
    _presenceController.close();
  }
}
