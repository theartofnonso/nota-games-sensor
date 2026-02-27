import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/coach_mapping_utils.dart';
import 'package:trainware/utils/theme/theme.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';

import '../../screens/coach/coach_selection_screen.dart';

/// Wraps the main app for client users. Both new and returning users go
/// through this check. If the client has no coach assigned (and for mock flow,
/// hasn't completed coach selection), shows CoachSelectionScreen until they select.
class CoachSelectionGate extends StatefulWidget {
  final Widget child;

  const CoachSelectionGate({
    super.key,
    required this.child,
  });

  @override
  State<CoachSelectionGate> createState() => _CoachSelectionGateState();
}

class _CoachSelectionGateState extends State<CoachSelectionGate> {
  bool? _needsCoachSelection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCoachStatus());
  }

  Future<void> _checkCoachStatus() async {
    if (!AppConfig.isClient) {
      if (mounted) setState(() => _needsCoachSelection = false);
      return;
    }

    final userId =
        Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _needsCoachSelection = false);
      return;
    }

    final coach = await fetchCoachForClient(userId);
    final hasCompletedSelection = SharedPrefs().coachSelectionComplete;

    if (mounted) {
      setState(() {
        _needsCoachSelection = coach == null && !hasCompletedSelection;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsCoachSelection == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const TRKRLoadingScreen(),
      );
    }

    if (_needsCoachSelection!) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: CoachSelectionScreen(
          onComplete: () {
            setState(() => _needsCoachSelection = false);
          },
        ),
      );
    }

    return widget.child;
  }
}
