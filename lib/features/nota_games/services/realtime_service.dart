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

    _stateChannel = client.channel('session:$sessionId:state');
    _scoresChannel = client.channel('session:$sessionId:scores');
    _presenceChannel = client.channel('session:$sessionId:presence');

    _stateChannel!
        .onBroadcast(
          event: 'session_state_change',
          callback: (payload) {
            _stateController.add(
              SessionRuntimeState.fromSessionStateChange(payload),
            );
          },
        )
        .subscribe();

    _scoresChannel!
        .onBroadcast(
          event: 'leaderboard_update',
          callback: (payload) {
            final entries = _parseLeaderboard(payload);
            if (entries != null) {
              _leaderboardController.add(entries);
            }
          },
        )
        .onBroadcast(
          event: 'presence_update',
          callback: (payload) {
            final players = _parsePresence(payload);
            if (players != null) {
              _presenceController.add(players);
            }
          },
        )
        .subscribe();

    final presenceChannel = _presenceChannel!;
    final presencePayload = <String, dynamic>{
      'playerId': session.playerId,
      'playerName': session.playerName,
      'joinedAt': DateTime.now().millisecondsSinceEpoch,
      if (session.teamId != null) 'teamId': session.teamId,
      if (session.duoId != null) 'duoId': session.duoId,
    };

    final presenceReady = Completer<void>();
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
        if (!presenceReady.isCompleted) {
          presenceReady.complete();
        }
      } else if (status == RealtimeSubscribeStatus.channelError &&
          !presenceReady.isCompleted) {
        presenceReady.completeError(
          error ?? StateError('presence channel error'),
        );
      }
    });

    await presenceReady.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        if (kDebugMode) {
          debugPrint('NOTA presence subscribe timed out');
        }
      },
    );
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
