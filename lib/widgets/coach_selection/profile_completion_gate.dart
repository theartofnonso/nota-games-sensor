import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/services/account_profile_service.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/urls.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/utils/theme/theme.dart';
import 'package:trainware/utils/uri_utils.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/settings/logout_section.dart';

/// Wraps the main app for client users. Expects an existing row in [public.clients]
/// (created on the website). If the signed-in user has no client row, shows a
/// blocking bottom sheet that deep-links to the web and offers sign-out.
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

    setState(() => _phase = _ProfileGatePhase.webSignupRequired);
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
      case _ProfileGatePhase.webSignupRequired:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: TRKRTheme.darkTheme,
          darkTheme: TRKRTheme.darkTheme,
          home: const _WebClientSignupRequiredScreen(),
        );
    }
  }
}

enum _ProfileGatePhase { checking, ready, webSignupRequired }

class _WebClientSignupRequiredScreen extends StatefulWidget {
  const _WebClientSignupRequiredScreen();

  @override
  State<_WebClientSignupRequiredScreen> createState() =>
      _WebClientSignupRequiredScreenState();
}

class _WebClientSignupRequiredScreenState
    extends State<_WebClientSignupRequiredScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWebSignupSheet());
  }

  Future<void> _showWebSignupSheet() async {
    if (!mounted) return;
    final rootContext = context;
    await showAppActionBottomSheet<void>(
      context: rootContext,
      useRootNavigator: true,
      isDismissible: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Finish signing up on the web',
              style: Theme.of(rootContext).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Mobile sign-in is for members who already have an account. '
              'Go to notathletes.com to subscribe, choose your coach, and create your profile. '
              'Then return here and sign in with the same email.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => openUrl(url: trackrWebUrl, context: rootContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(rootContext)
                        .extension<TRKRColors>()
                        ?.vibrantAccent ??
                    Colors.green,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Open notathletes.com'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(rootContext, rootNavigator: true);
                if (nav.canPop()) {
                  nav.pop();
                }
                await performLogout();
              },
              child: Text(
                'Sign out',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: const TRKRLoadingScreen(),
    );
  }
}
