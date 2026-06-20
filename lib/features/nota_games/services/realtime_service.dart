import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/nota_games_config.dart';
import '../models/connected_player.dart';
import '../models/leaderboard_entry.dart';
import '../models/session_status.dart';

/// Owns `session:{id}:state` and `session:{id}:scores` realtime channels.
///
/// Subscribes to `session_state_change`, `leaderboard_update`, and
/// `presence_update` per backend handoff.
class RealtimeService {
  RealtimeChannel? _stateChannel;
  RealtimeChannel? _scoresChannel;

  final _statusController = StreamController<SessionStatus>.broadcast();
  final _leaderboardController =
      StreamController<List<LeaderboardEntry>>.broadcast();
  final _presenceController =
      StreamController<List<ConnectedPlayer>>.broadcast();

  String? _sessionId;
  bool _disconnected = false;
  Timer? _stubActivateTimer;

  Stream<SessionStatus> get statusStream => _statusController.stream;
  Stream<List<LeaderboardEntry>> get leaderboardStream =>
      _leaderboardController.stream;
  Stream<List<ConnectedPlayer>> get presenceStream =>
      _presenceController.stream;

  Future<void> connect(String sessionId) async {
    await disconnect();
    _sessionId = sessionId;
    _disconnected = false;

    if (NotaGamesConfig.useStubRealtime) {
      _connectStub();
      return;
    }

    await _connectSupabase(sessionId);
  }

  void _connectStub() {
    _statusController.add(SessionStatus.waiting);

    if (NotaGamesConfig.stubAutoActivateOnJoin) {
      _stubActivateTimer = Timer(NotaGamesConfig.stubActivateDelay, () {
        if (!_disconnected) {
          _statusController.add(SessionStatus.active);
        }
      });
    }

    if (kDebugMode) {
      debugPrint('NOTA stub realtime connected session=$_sessionId');
    }
  }

  Future<void> _connectSupabase(String sessionId) async {
    final client = Supabase.instance.client;

    _stateChannel = client.channel('session:$sessionId:state');
    _scoresChannel = client.channel('session:$sessionId:scores');

    _stateChannel!
        .onBroadcast(
          event: 'session_state_change',
          callback: (payload) {
            final status = payload['status'];
            if (status is String) {
              _statusController.add(SessionStatus.fromWire(status));
            }
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
    _disconnected = true;
    _stubActivateTimer?.cancel();
    _stubActivateTimer = null;

    if (_stateChannel != null) {
      await Supabase.instance.client.removeChannel(_stateChannel!);
      _stateChannel = null;
    }
    if (_scoresChannel != null) {
      await Supabase.instance.client.removeChannel(_scoresChannel!);
      _scoresChannel = null;
    }

    _sessionId = null;
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _leaderboardController.close();
    _presenceController.close();
  }
}
