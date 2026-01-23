import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';

class AccessController extends ChangeNotifier {
  AccessController({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  bool _initialized = false;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isRoleResolved = true;
  String? _userId;
  String? _clientOverrideId;
  String? _clientOverrideName;
  StreamSubscription<AuthState>? _authSub;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isCoach => AppConfig.isCoach;
  bool get isRoleResolved => _isRoleResolved;
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
    _isRoleResolved = true;
    _isLoading = false;
    notifyListeners();

    _authSub = _client.auth.onAuthStateChange.listen(
      (data) async {
        final session = data.session;
        _isAuthenticated = session != null;
        _userId = session?.user.id;
        _isRoleResolved = true;
        if (!_isAuthenticated) {
          _clientOverrideId = null;
          _clientOverrideName = null;
          _isRoleResolved = true;
        }
        notifyListeners();
      },
      onError: (_) {
        _isAuthenticated = false;
        _userId = null;
        _clientOverrideId = null;
        _clientOverrideName = null;
        _isRoleResolved = true;
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

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
