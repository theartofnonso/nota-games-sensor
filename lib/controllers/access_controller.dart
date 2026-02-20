import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages authentication state and selected client for coaches.
///
/// **Purpose:**
/// - Tracks user authentication state (isAuthenticated, userId)
/// - In coach app: tracks which client is currently selected for viewing
///   - `selectedClientId == null`: Coach is on the client selection screen
///   - `selectedClientId != null`: Coach is viewing that client's data
/// - Provides reactive state updates via ChangeNotifier
///
/// **Note:** Use `AppConfig.isCoach` directly to check app flavor.
/// In coach app, if `selectedClientId != null`, coach is viewing client data.
class ClientOverrideController extends ChangeNotifier {
  ClientOverrideController({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  bool _initialized = false;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _userId;
  String? _selectedClientId;
  String? _selectedClientName;
  String? _selectedClientEmail;
  String? _coachName;
  String? _coachId; // For client app: stores the coach's ID
  StreamSubscription<AuthState>? _authSub;

  /// Whether the controller is still initializing
  bool get isLoading => _isLoading;

  /// Whether the user is currently authenticated
  bool get isAuthenticated => _isAuthenticated;

  /// Current authenticated user ID, or null if not authenticated
  String? get userId => _userId;

  /// Whether a client is currently selected (coach viewing client data)
  /// In coach app: true when viewing a client, false when on client selection screen
  bool get hasSelectedClient => _selectedClientId != null;

  /// The ID of the currently selected client (null = on client selection screen)
  String? get selectedClientId => _selectedClientId;

  /// The name of the currently selected client
  String? get selectedClientName => _selectedClientName;

  /// The email of the currently selected client
  String? get selectedClientEmail => _selectedClientEmail;

  /// The name of the assigned coach (only set and used in client app)
  String? get coachName => _coachName;

  /// The ID of the assigned coach (only set in client app)
  String? get coachId => _coachId;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isLoading = true;
    notifyListeners();

    final session = _client.auth.currentSession;
    _isAuthenticated = session != null;
    _userId = session?.user.id;
    _isLoading = false;

    notifyListeners();

    _authSub = _client.auth.onAuthStateChange.listen(
      (data) async {
        final session = data.session;
        _isAuthenticated = session != null;
        _userId = session?.user.id;
        if (!_isAuthenticated) {
          _selectedClientId = null;
          _selectedClientName = null;
          _selectedClientEmail = null;
          _coachName = null;
          _coachId = null;
        }
        notifyListeners();
      },
      onError: (_) {
        _isAuthenticated = false;
        _userId = null;
        _selectedClientId = null;
        _selectedClientName = null;
        _selectedClientEmail = null;
        _coachName = null;
        _coachId = null;
        notifyListeners();
      },
    );
  }

  /// Sets the selected client - coach will view this client's data
  /// Only used in coach app when a coach selects a client to view
  void setSelectedClient({
    required String clientId,
    String? clientName,
    String? clientEmail,
  }) {
    _selectedClientId = clientId;
    _selectedClientName = clientName ?? _selectedClientName;
    _selectedClientEmail = clientEmail ?? _selectedClientEmail;
    notifyListeners();
  }

  /// Clears the selected client - coach returns to client selection screen
  void clearSelectedClient() {
    _selectedClientId = null;
    _selectedClientName = null;
    _selectedClientEmail = null;
    notifyListeners();
  }

  /// Sets the coach ID and name (for client app when fetching coach data)
  void setCoachData({required String coachId, required String coachName}) {
    _coachId = coachId;
    _coachName = coachName;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
