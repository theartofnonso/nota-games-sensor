import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/player_session.dart';
import '../models/session_status.dart';
import '../services/leaderboard_service.dart';
import '../services/motion_service.dart';
import '../services/realtime_service.dart';
import '../core/api_client.dart';
import '../services/session_service.dart';

/// Central state machine — the only place that decides when motion starts or stops.
class SessionManager extends ChangeNotifier {
  SessionManager({
    required SessionService sessionService,
    required RealtimeService realtimeService,
    required MotionService motionService,
    required LeaderboardService leaderboardService,
  })  : _sessionService = sessionService,
        _realtimeService = realtimeService,
        _motionService = motionService,
        _leaderboardService = leaderboardService;

  final SessionService _sessionService;
  final RealtimeService _realtimeService;
  final MotionService _motionService;
  final LeaderboardService _leaderboardService;

  SessionStatus _status = SessionStatus.waiting;
  PlayerSession? _session;
  String? _joinError;
  StreamSubscription<SessionStatus>? _statusSub;

  SessionStatus get status => _status;
  PlayerSession? get session => _session;
  String? get joinError => _joinError;
  bool get hasSession => _session != null;

  MotionService get motionService => _motionService;
  LeaderboardService get leaderboardService => _leaderboardService;

  /// `POST /sessions/:id/join` then connect realtime channels.
  Future<void> joinSession(
    String sessionId, {
    required String playerName,
  }) async {
    _joinError = null;
    notifyListeners();

    try {
      final playerSession = await _sessionService.join(
        sessionId.trim(),
        playerName: playerName.trim(),
      );
      _session = playerSession;
      _motionService.configure(playerSession);

      await _realtimeService.connect(playerSession.sessionId);
      _leaderboardService.attach(_realtimeService);

      await _statusSub?.cancel();
      _statusSub = _realtimeService.statusStream.listen(
        _onSessionStatus,
        onError: (Object e) {
          if (kDebugMode) {
            debugPrint('NOTA status stream error: $e');
          }
        },
      );

      _status = SessionStatus.waiting;
      notifyListeners();
    } on SessionJoinForbiddenException {
      _joinError = 'Could not join this session. Check the code and try again.';
      _session = null;
      notifyListeners();
    } on SessionUnauthorizedException {
      _joinError = 'Could not authenticate. Please restart the app.';
      _session = null;
      notifyListeners();
    } on SessionServiceException catch (e) {
      _joinError = e.message;
      _session = null;
      notifyListeners();
    }
  }

  void _onSessionStatus(SessionStatus status) {
    _status = status;

    switch (status) {
      case SessionStatus.active:
        unawaited(_motionService.start());
      case SessionStatus.paused:
      case SessionStatus.passBreak:
        unawaited(_motionService.pause());
      case SessionStatus.ended:
        unawaited(_onSessionEnded());
      case SessionStatus.waiting:
        unawaited(_motionService.pause());
    }

    notifyListeners();
  }

  /// Player-initiated leave (`DELETE /sessions/:id/leave`).
  Future<void> leaveSession() async {
    await _tearDownActiveSession();
    _session = null;
    _status = SessionStatus.waiting;
    _joinError = null;
    notifyListeners();
  }

  Future<void> _onSessionEnded() async {
    await _tearDownActiveSession();
  }

  Future<void> _tearDownActiveSession() async {
    await _motionService.stop();
    final sessionId = _session?.sessionId;
    if (sessionId != null) {
      await _sessionService.leave(sessionId);
    }
    await _realtimeService.disconnect();
    await _statusSub?.cancel();
    _statusSub = null;
    _leaderboardService.detach();
  }

  /// Clears session state after the results screen (re-join flow).
  void resetAfterResults() {
    _session = null;
    _status = SessionStatus.waiting;
    _joinError = null;
    _leaderboardService.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _realtimeService.dispose();
    _motionService.dispose();
    _leaderboardService.dispose();
    super.dispose();
  }
}
