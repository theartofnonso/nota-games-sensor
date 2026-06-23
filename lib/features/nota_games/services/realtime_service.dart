import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/connected_player.dart';
import '../models/leaderboard_entry.dart';
import '../models/player_session.dart';
import '../models/session_runtime_state.dart';

/// Owns `session:{id}:state`, `session:{id}:scores`, and `session:{id}:presence`.
class RealtimeService {
  RealtimeChannel? _stateChannel;
  RealtimeChannel? _scoresChannel;
  RealtimeChannel? _presenceChannel;

  final _stateController =
      StreamController<SessionRuntimeState>.broadcast();
  final _leaderboardController =
      StreamController<List<LeaderboardEntry>>.broadcast();
  final _presenceController =
      StreamController<List<ConnectedPlayer>>.broadcast();

  Stream<SessionRuntimeState> get stateStream => _stateController.stream;
  Stream<List<LeaderboardEntry>> get leaderboardStream =>
      _leaderboardController.stream;
  Stream<List<ConnectedPlayer>> get presenceStream =>
      _presenceController.stream;

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
          callback: (payload) {
            final entries = _parseLeaderboard(_unwrapPayload(payload));
            if (entries != null) {
              _leaderboardController.add(entries);
            }
          },
        )
        .onBroadcast(
          event: 'presence_update',
          callback: (payload) {
            final players = _parsePresence(_unwrapPayload(payload));
            if (players != null) {
              _presenceController.add(players);
            }
          },
        );

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

  Map<String, dynamic> _unwrapPayload(Map<String, dynamic> payload) {
    final nested = payload['payload'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return payload;
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

  List<LeaderboardEntry>? _parseLeaderboard(Map<String, dynamic> payload) {
    final raw = payload['leaderboard'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<ConnectedPlayer>? _parsePresence(Map<String, dynamic> payload) {
    final raw = payload['connectedPlayers'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => ConnectedPlayer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
