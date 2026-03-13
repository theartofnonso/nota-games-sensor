import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/services/account_profile_service.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/utils/theme/theme.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';

/// Wraps the main app for client users. Both new and returning users go
/// through this check. If the client has no profile (new user after OTP),
/// creates the profile immediately with name derived from email.
class ProfileCompletionGate extends StatefulWidget {
  final Widget child;

  const ProfileCompletionGate({
    super.key,
    required this.child,
  });

  @override
  State<ProfileCompletionGate> createState() => _ProfileCompletionGateState();
}

class _ProfileCompletionGateState extends State<ProfileCompletionGate> {
  bool? _needsProfileCompletion;
  bool _createFailed = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProfileStatus());
  }

  Future<void> _checkProfileStatus() async {
    if (!AppConfig.isClient) {
      if (mounted) setState(() => _needsProfileCompletion = false);
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    if (userId == null) {
      if (mounted) setState(() => _needsProfileCompletion = false);
      return;
    }

    // Returning user: skip network check when we've passed this gate before
    if (SharedPrefs().profileSetupComplete) {
      if (mounted) setState(() => _needsProfileCompletion = false);
      return;
    }

    final exists = await clientProfileExists(userId);
    if (exists) {
      SharedPrefs().profileSetupComplete = true;
      if (mounted) {
        setState(() => _needsProfileCompletion = false);
      }
      return;
    }

    // New user: create profile with name derived from email
    if (mounted) {
      setState(() {
        _needsProfileCompletion = true;
        _isCreating = true;
        _createFailed = false;
      });
    }

    // Prefer email from auth flow (user-typed); fallback to Supabase
    final email = takeEmailFromAuth() ?? user?.email?.trim() ?? '';
    final name = nameFromEmail(email);
    final ok = await createAccountProfile(userId: userId, name: name);
    if (ok) SharedPrefs().profileSetupComplete = true;

    if (!mounted) return;
    setState(() {
      _isCreating = false;
      _needsProfileCompletion = !ok;
      _createFailed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needsProfileCompletion == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const TRKRLoadingScreen(),
      );
    }
    if (!_needsProfileCompletion!) {
      return widget.child;
    }

    if (_isCreating) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const TRKRLoadingScreen(),
      );
    }

    if (_createFailed) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: _ProfileCreationRetryScreen(
          onRetry: () {
            setState(() => _createFailed = false);
            _checkProfileStatus();
          },
        ),
      );
    }

    return widget.child;
  }
}

/// Shown when profile creation fails; user can retry.
class _ProfileCreationRetryScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProfileCreationRetryScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Could not create your account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please check your connection and try again.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .extension<TRKRColors>()
                          ?.vibrantAccent ??
                          Colors.green,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
