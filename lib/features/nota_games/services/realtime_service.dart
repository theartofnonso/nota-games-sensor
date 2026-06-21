import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/connected_player.dart';
import '../models/leaderboard_entry.dart';
import '../models/session_runtime_state.dart';

/// Owns `session:{id}:state` and `session:{id}:scores` realtime channels.
///
/// Subscribes to `session_state_change`, `leaderboard_update`, and
/// `presence_update` per backend handoff.
class RealtimeService {
  RealtimeChannel? _stateChannel;
  RealtimeChannel? _scoresChannel;

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

  Future<void> connect(String sessionId) async {
    await disconnect();

    final client = Supabase.instance.client;

    _stateChannel = client.channel('session:$sessionId:state');
    _scoresChannel = client.channel('session:$sessionId:scores');

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
    if (_stateChannel != null) {
      await Supabase.instance.client.removeChannel(_stateChannel!);
      _stateChannel = null;
    }
    if (_scoresChannel != null) {
      await Supabase.instance.client.removeChannel(_scoresChannel!);
      _scoresChannel = null;
    }
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _leaderboardController.close();
    _presenceController.close();
  }
}
