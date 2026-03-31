import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/repositories/supabase/supabase_coaches_repository.dart';
import 'package:trainware/screens/onboarding/coach_discovery_screen.dart';
import 'package:trainware/services/account_profile_service.dart';
import 'package:trainware/services/assigned_coach_service.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/utils/theme/theme.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

/// Wraps the main app for client users. Expects a row in [public.clients].
/// If the user is signed in but has no client row, we **keep the session** and
/// guide them to **Discover coaches** to finish onboarding (same flow as pre-auth).
class ProfileCompletionGate extends StatefulWidget {
  final Widget child;

  const ProfileCompletionGate({super.key, required this.child});

  @override
  State<ProfileCompletionGate> createState() => _ProfileCompletionGateState();
}

class _ProfileCompletionGateState extends State<ProfileCompletionGate> {
  _ProfileGatePhase _phase = _ProfileGatePhase.checking;

  /// While [_phase] is [noClientProfile], user chose "Discover coaches" (stay signed in).
  bool _finishOnboardingDiscovery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProfileStatus());
  }

  Future<void> _checkProfileStatus() async {
    if (!AppConfig.isClient) {
      if (mounted) setState(() => _phase = _ProfileGatePhase.ready);
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _phase = _ProfileGatePhase.ready);
      return;
    }

    if (SharedPrefs().profileSetupComplete) {
      if (mounted) setState(() => _phase = _ProfileGatePhase.ready);
      return;
    }

    final exists = await clientProfileExists(userId);
    if (!mounted) return;

    if (exists) {
      SharedPrefs().profileSetupComplete = true;
      // Startup / earlier auth refresh often ran before coach_clients existed; reload
      // so home subscribe card and shell see the assigned coach without opening paywall.
      unawaited(AssignedCoachService.instance.refreshFromRemote());
      setState(() {
        _phase = _ProfileGatePhase.ready;
        _finishOnboardingDiscovery = false;
      });
      return;
    }

    setState(() {
      _phase = _ProfileGatePhase.noClientProfile;
      _finishOnboardingDiscovery = false;
    });
  }

  Future<void> _recheckAfterCoachSignup() async {
    if (!mounted) return;
    SharedPrefs().profileSetupComplete = false;
    setState(() {
      _phase = _ProfileGatePhase.checking;
      _finishOnboardingDiscovery = false;
    });
    await _checkProfileStatus();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _ProfileGatePhase.checking:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: TRKRTheme.darkTheme,
          darkTheme: TRKRTheme.darkTheme,
          home: const TRKRLoadingScreen(),
        );
      case _ProfileGatePhase.ready:
        return widget.child;
      case _ProfileGatePhase.noClientProfile:
        if (_finishOnboardingDiscovery) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            theme: TRKRTheme.darkTheme,
            darkTheme: TRKRTheme.darkTheme,
            home: Builder(
              builder: (nestedContext) {
                return CoachDiscoveryScreen(
                  coachesFuture: SupabaseCoachesRepository().fetchCoaches(),
                  onBack:
                      () => setState(() => _finishOnboardingDiscovery = false),
                  onAcquisitionComplete: () => _recheckAfterCoachSignup(),
                  onNeedSignIn: () {
                    showSnackbar(
                      context: nestedContext,
                      message:
                          'That email is already in use. Use the same email you '
                          'signed in with to finish setup, or pick another coach.',
                    );
                  },
                );
              },
            ),
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: TRKRTheme.darkTheme,
          darkTheme: TRKRTheme.darkTheme,
          home: _FinishOnboardingLanding(
            onDiscoverCoaches:
                () => setState(() => _finishOnboardingDiscovery = true),
          ),
        );
    }
  }
}

enum _ProfileGatePhase { checking, ready, noClientProfile }

/// Explains finish-onboarding; primary action opens coach discovery (session kept).
class _FinishOnboardingLanding extends StatefulWidget {
  const _FinishOnboardingLanding({required this.onDiscoverCoaches});

  final VoidCallback onDiscoverCoaches;

  @override
  State<_FinishOnboardingLanding> createState() =>
      _FinishOnboardingLandingState();
}

class _FinishOnboardingLandingState extends State<_FinishOnboardingLanding> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSheet());
  }

  Future<void> _showSheet() async {
    if (!mounted) return;
    await showAppActionBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Finish your setup',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.start,
            ),
            Text(
              'You’re signed in, but your membership isn’t complete yet. '
              'Choose a coach and complete signup to create your client profile.',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                label: 'Discover coaches',
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  widget.onDiscoverCoaches();
                },
                buttonColor: Theme.of(context).colors.vibrantAccent,
                showArrowRight: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: const TRKRLoadingScreen());
  }
}
