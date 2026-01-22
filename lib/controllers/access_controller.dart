import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/supabase/supabase_coach_repository.dart';
import '../shared_prefs.dart';

class AccessController extends ChangeNotifier {
  AccessController({
    SupabaseClient? client,
    SupabaseCoachRepository? coachRepository,
  })  : _client = client ?? Supabase.instance.client,
        _coachRepository = coachRepository ?? SupabaseCoachRepository();

  final SupabaseClient _client;
  final SupabaseCoachRepository _coachRepository;

  bool _initialized = false;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isCoach = false;
  bool _didHydrateCache = false;
  String? _hydratedUserId;
  String? _userId;
  String? _clientOverrideId;
  String? _clientOverrideName;
  StreamSubscription<AuthState>? _authSub;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isCoach => _isCoach;
  bool get didHydrateCache => _didHydrateCache;
  String? get userId => _userId;
  bool get isClientMode => _clientOverrideId != null;
  String? get clientOverrideId => _clientOverrideId;
  String? get clientOverrideName => _clientOverrideName;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isLoading = true;
    notifyListeners();

    final session = _client.auth.currentSession;
    _isAuthenticated = session != null;
    _userId = session?.user.id;
    _hydrateCoachCache(userId: _userId);
    _isLoading = false;
    notifyListeners();
    if (_isAuthenticated && _userId != null) {
      _refreshCoachStatusAsync(userId: _userId!);
    }

    _authSub = _client.auth.onAuthStateChange.listen(
      (data) async {
        final session = data.session;
        _isAuthenticated = session != null;
        _userId = session?.user.id;
        _isCoach = false;
        _hydrateCoachCache(userId: _userId);
        if (!_isAuthenticated) {
          _clientOverrideId = null;
          _clientOverrideName = null;
        }
        notifyListeners();
        if (_isAuthenticated && _userId != null) {
          _refreshCoachStatusAsync(userId: _userId!);
        }
      },
      onError: (_) {
        _isAuthenticated = false;
        _userId = null;
        _isCoach = false;
        _clientOverrideId = null;
        _clientOverrideName = null;
        notifyListeners();
      },
    );
  }

  void setClientOverride({required String clientId, String? clientName}) {
    _clientOverrideId = clientId;
    _clientOverrideName = clientName ?? _clientOverrideName;
    notifyListeners();
  }

  void clearClientOverride() {
    _clientOverrideId = null;
    _clientOverrideName = null;
    notifyListeners();
  }

  Future<void> _refreshCoachStatus({required String userId}) async {
    try {
      _isCoach = await _coachRepository
          .isCoach(userId: userId)
          .timeout(const Duration(seconds: 5));
      _saveCoachCache(isCoach: _isCoach, userId: userId);
    } catch (_) {
      _isCoach = false;
    }
  }

  void _refreshCoachStatusAsync({required String userId}) {
    // Fire-and-forget so auth UI doesn't block on role lookup.
    _refreshCoachStatus(userId: userId).then((_) {
      notifyListeners();
    });
  }

  void _hydrateCoachCache({required String? userId}) {
    if (_didHydrateCache && _hydratedUserId == userId) return;
    if (userId == null || userId.isEmpty) return;
    _didHydrateCache = true;
    _hydratedUserId = userId;
    final cachedUserId = SharedPrefs().getCoachModeUserId();
    final cached = SharedPrefs().getCoachMode();
    if (cached != null && cachedUserId == userId) {
      _isCoach = cached;
    }
  }

  void _saveCoachCache({required bool isCoach, required String userId}) {
    SharedPrefs().setCoachMode(isCoach);
    SharedPrefs().setCoachModeUserId(userId);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
