import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/player_session.dart';
import '../models/session_runtime_state.dart';
import '../services/leaderboard_service.dart';
import '../services/motion_service.dart';
import '../services/realtime_service.dart';
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

  SessionRuntimeState _runtimeState = SessionRuntimeState.initial;
  PlayerSession? _session;
  String? _joinError;
  StreamSubscription<SessionRuntimeState>? _stateSub;
  bool _tearingDown = false;

  SessionRuntimeState get runtimeState => _runtimeState;
  bool get isMotionEligible => _runtimeState.isMotionEligible;
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
    _tearingDown = false;
    notifyListeners();

    try {
      final playerSession = await _sessionService.join(
        sessionId.trim(),
        playerName: playerName.trim(),
      );
      _session = playerSession;
      _motionService.configure(playerSession);

      await _realtimeService.connect(playerSession);
      _leaderboardService.attach(_realtimeService);

      await _stateSub?.cancel();
      _stateSub = _realtimeService.stateStream.listen(
        _onSessionState,
        onError: (Object e) {
          if (kDebugMode) {
            debugPrint('NOTA state stream error: $e');
          }
        },
      );

      if (playerSession.initialGameState != null) {
        _applyRuntimeState(playerSession.initialGameState!);
      } else {
        _runtimeState = SessionRuntimeState.initial;
        notifyListeners();
      }
    } on SessionJoinForbiddenException {
      _joinError = 'This session has already ended.';
      _session = null;
      notifyListeners();
    } on SessionNotFoundException {
      _joinError = 'Session not found. Check the QR code and try again.';
      _session = null;
      notifyListeners();
    } on SessionServiceException catch (e) {
      _joinError = e.message;
      _session = null;
      notifyListeners();
    }
  }

  void _onSessionState(SessionRuntimeState state) {
    _applyRuntimeState(state);
  }

  void _applyRuntimeState(SessionRuntimeState state) {
    _runtimeState = state;

    if (state.sessionEnded) {
      unawaited(_onSessionEnded());
    } else if (state.sensorActive) {
      unawaited(_motionService.start());
    } else {
      unawaited(_motionService.pause());
    }

    notifyListeners();
  }

  /// Player-initiated leave (`DELETE /sessions/:id/leave`).
  Future<void> leaveSession() async {
    await _tearDownActiveSession();
    _session = null;
    _runtimeState = SessionRuntimeState.initial;
    _joinError = null;
    notifyListeners();
  }

  Future<void> _onSessionEnded() async {
    if (_tearingDown) return;
    await _tearDownActiveSession();
  }

  Future<void> _tearDownActiveSession() async {
    if (_tearingDown) return;
    _tearingDown = true;

    await _motionService.stop();
    await _realtimeService.disconnect();
    await _stateSub?.cancel();
    _stateSub = null;
    _leaderboardService.detach();

    final session = _session;
    if (session != null) {
      try {
        await _sessionService.leave(
          session.sessionId,
          playerId: session.playerId,
        );
      } on SessionServiceException catch (e) {
        if (kDebugMode) {
          debugPrint('NOTA leave error: ${e.message}');
        }
      }
    }
  }

  /// Clears session state after the results screen (re-join flow).
  void resetAfterResults() {
    _session = null;
    _runtimeState = SessionRuntimeState.initial;
    _joinError = null;
    _tearingDown = false;
    _leaderboardService.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _realtimeService.dispose();
    _motionService.dispose();
    _leaderboardService.dispose();
    super.dispose();
  }
}
