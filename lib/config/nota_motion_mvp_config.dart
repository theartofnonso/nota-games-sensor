/// When true, the app boots only into [NotaGamesApp] and skips the Trainware
/// coach/client journeys. NOTA does not require login — open app, enter session
/// code, play.
///
/// Set to `false` to restore the full app.
abstract final class NotaMotionMvpConfig {
  static const bool enabled = true;
}
