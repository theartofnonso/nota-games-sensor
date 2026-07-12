import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/player_session.dart';
import '../models/session_state_change.dart';
import '../services/motion_service.dart';
import '../services/realtime_service.dart';
import '../services/session_service.dart';

/// Central state machine — the only place that decides when motion starts or stops.
class SessionManager extends ChangeNotifier {
  SessionManager({
    required SessionService sessionService,
    required RealtimeService realtimeService,
    required MotionService motionService,
  })  : _sessionService = sessionService,
        _realtimeService = realtimeService,
        _motionService = motionService;

  final SessionService _sessionService;
  final RealtimeService _realtimeService;
  final MotionService _motionService;

  SessionStateChange _gameState = SessionStateChange.initial;
  PlayerSession? _session;
  String? _joinError;

  StreamSubscription<SessionStateChange>? _stateSub;
  bool _tearingDown = false;

  SessionStateChange get gameState => _gameState;
  PlayerSession? get session => _session;
  String? get joinError => _joinError;

  bool get hasSession => _session != null;

  MotionService get motionService => _motionService;

  /// `POST /sessions/:id/join` then subscribe to Realtime channels.
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

      if (playerSession.gameState != null) {
        _applyGameState(playerSession.gameState!);
      } else {
        _gameState = SessionStateChange.initial;
        notifyListeners();
      }

      await _cancelSubscriptions();
      _stateSub = _realtimeService.stateStream.listen(
        _onSessionState,
        onError: (Object e) {
          if (kDebugMode) debugPrint('NOTA state stream error: $e');
        },
      );

      await _realtimeService.connect(playerSession);
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

  void _onSessionState(SessionStateChange change) {
    _applyGameState(change);
  }

  void _applyGameState(SessionStateChange change) {
    _gameState = change;

    if (change.sessionEnded) {
      unawaited(_onSessionEnded());
    } else if (change.sensorActive) {
      unawaited(_motionService.start());
    } else {
      unawaited(_motionService.pause());
    }

    notifyListeners();
  }

  /// Player-initiated leave (`DELETE /sessions/:id/leave`).
  Future<void> leaveSession() async {
    await _tearDownActiveSession();
    _returnToJoinScreen();
  }

  /// Silent teardown when the app is closed — handoff: `/leave` on app exit.
  Future<void> onAppExit() async {
    if (_session == null || _tearingDown) return;
    await _tearDownActiveSession();
    _session = null;
    _gameState = SessionStateChange.initial;
  }

  Future<void> _onSessionEnded() async {
    if (_tearingDown) return;
    await _tearDownActiveSession();
    _returnToJoinScreen();
  }

  void _returnToJoinScreen() {
    _session = null;
    _gameState = SessionStateChange.initial;
    _joinError = null;
    _tearingDown = false;
    notifyListeners();
  }

  Future<void> _tearDownActiveSession() async {
    if (_tearingDown) return;
    _tearingDown = true;

    await _motionService.stop();
    await _realtimeService.disconnect();
    await _cancelSubscriptions();

    final session = _session;
    if (session != null) {
      try {
        await _sessionService.leave(
          session.sessionId,
          playerId: session.playerId,
        );
      } on SessionServiceException catch (e) {
        if (kDebugMode) debugPrint('NOTA leave error: ${e.message}');
      }
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _stateSub?.cancel();
    _stateSub = null;
  }

  @override
  void dispose() {
    if (_session != null && !_tearingDown) {
      unawaited(onAppExit());
    }
    unawaited(_cancelSubscriptions());
    _realtimeService.dispose();
    _motionService.dispose();
    super.dispose();
  }
}
