/// When true, the app boots only into [MotionTrackingScreen] and skips auth,
/// Supabase, and the rest of the Trainware user journeys.
///
/// Set to `false` to restore the full app.
abstract final class NotaMotionMvpConfig {
  static const bool enabled = true;
}
