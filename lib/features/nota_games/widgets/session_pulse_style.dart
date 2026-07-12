import '../models/session_state_change.dart';

/// Team colour only during active work sensing; gray otherwise.
bool useTeamPulseColor(SessionStateChange gameState) =>
    gameState.sensorActive && gameState.phase != SessionPhase.rest;
