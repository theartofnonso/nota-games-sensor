import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/services/account_profile_service.dart';
import 'package:trainware/services/notathletes_user_deletion_service.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/utils/theme/theme.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

/// Wraps the main app for client users. Expects a row in [public.clients]. If the
/// signed-in user has no client row (e.g. signed in with OTP before training with
/// a coach), shows a blocking sheet: remove the orphan auth user via the same
/// backend as account deletion, sign out, then return them to the pre-auth welcome
/// flow (Discover coaches).
class ProfileCompletionGate extends StatefulWidget {
  final Widget child;

  const ProfileCompletionGate({super.key, required this.child});

  @override
  State<ProfileCompletionGate> createState() => _ProfileCompletionGateState();
}

class _ProfileCompletionGateState extends State<ProfileCompletionGate> {
  _ProfileGatePhase _phase = _ProfileGatePhase.checking;

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
      setState(() => _phase = _ProfileGatePhase.ready);
      return;
    }

    setState(() => _phase = _ProfileGatePhase.noClientProfile);
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
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: TRKRTheme.darkTheme,
          darkTheme: TRKRTheme.darkTheme,
          home: const _NoClientProfileScreen(),
        );
    }
  }
}

enum _ProfileGatePhase { checking, ready, noClientProfile }

class _NoClientProfileScreen extends StatefulWidget {
  const _NoClientProfileScreen();

  @override
  State<_NoClientProfileScreen> createState() => _NoClientProfileScreenState();
}

class _NoClientProfileScreenState extends State<_NoClientProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSheet());
  }

  Future<void> _showSheet() async {
    if (!mounted) return;
    final rootContext = context;
    await showAppActionBottomSheet<void>(
      context: rootContext,
      useRootNavigator: true,
      isDismissible: false,
      child: _NoClientProfileSheet(rootContext: rootContext),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: const TRKRLoadingScreen());
  }
}

class _NoClientProfileSheet extends StatefulWidget {
  const _NoClientProfileSheet({required this.rootContext});

  final BuildContext rootContext;

  @override
  State<_NoClientProfileSheet> createState() => _NoClientProfileSheetState();
}

class _NoClientProfileSheetState extends State<_NoClientProfileSheet> {
  bool _submitting = false;

  static const _defaultError =
      'Something went wrong. Please try again or contact support at notathletes.com.';

  static const _description =
      'We don’t have a client profile for this account yet. '
      'Members get started by choosing a coach in the app.\n\n'
      'We’ll remove this sign-in so you can start fresh. Tap below to find a coach.';

  Future<void> _onFindCoach() async {
    setState(() => _submitting = true);
    final outcome = await deleteAccountAndSignOut(
      afterBackendDelete: () async {
        if (!widget.rootContext.mounted) return;
        final nav = Navigator.of(widget.rootContext, rootNavigator: true);
        if (nav.canPop()) {
          nav.pop();
        }
      },
    );
    if (!mounted) return;

    setState(() => _submitting = false);

    if (!outcome.ok) {
      if (!context.mounted) return;
      await showErrorBottomSheet(
        context: context,
        title: 'Could not reset',
        message: outcome.errorMessage ?? _defaultError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colors;

    // Same layout as [showBottomSheetWithSingleAction] (dialog_utils.dart).
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You’re new here',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          Text(
            _description,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child:
                _submitting
                    ? SizedBox(
                      height: 48,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.vibrantAccent,
                          ),
                        ),
                      ),
                    )
                    : OpacityButtonWidgetTwo(
                      label: 'Find a coach',
                      onPressed: _onFindCoach,
                      buttonColor: colors.vibrantAccent,
                      outlineColor: colors.borderLight,
                      showArrowRight: false,
                    ),
          ),
        ],
      ),
    );
  }
}
