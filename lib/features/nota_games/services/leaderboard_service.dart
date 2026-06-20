import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/connected_player.dart';
import '../models/leaderboard_entry.dart';
import 'realtime_service.dart';

/// Holds leaderboard and presence from `session:{id}:scores`.
class LeaderboardService extends ChangeNotifier {
  List<LeaderboardEntry> _entries = const [];
  List<ConnectedPlayer> _connectedPlayers = const [];

  StreamSubscription<List<LeaderboardEntry>>? _leaderboardSub;
  StreamSubscription<List<ConnectedPlayer>>? _presenceSub;

  List<LeaderboardEntry> get entries => _entries;
  List<ConnectedPlayer> get connectedPlayers => _connectedPlayers;

  void attach(RealtimeService realtime) {
    detach();
    _leaderboardSub = realtime.leaderboardStream.listen((entries) {
      _entries = entries;
      notifyListeners();
    });
    _presenceSub = realtime.presenceStream.listen((players) {
      _connectedPlayers = players;
      notifyListeners();
    });
  }

  void detach() {
    _leaderboardSub?.cancel();
    _presenceSub?.cancel();
    _leaderboardSub = null;
    _presenceSub = null;
  }

  void clear() {
    _entries = const [];
    _connectedPlayers = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
