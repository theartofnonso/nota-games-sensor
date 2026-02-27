import 'package:flutter/material.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/services/client_subscription_service.dart';
import 'package:trainware/utils/theme/theme.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';

import '../../screens/subscription/subscription_required_screen.dart';

/// Wraps the main app for client users. Both new and returning users go
/// through this check. If the client has no active subscription, shows a
/// full-screen paywall. Access is blocked until subscription is active
/// (purchase or restore).
class SubscriptionGate extends StatefulWidget {
  final Widget child;

  const SubscriptionGate({
    super.key,
    required this.child,
  });

  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate> {
  bool? _hasAccess;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccess());
  }

  Future<void> _checkAccess() async {
    if (!AppConfig.isClient) {
      if (mounted) setState(() => _hasAccess = true);
      return;
    }

    final service = ClientSubscriptionService.instance;
    // Only refresh if cache not yet populated by startup
    if (!service.isCachePopulated) {
      await service.refreshSubscriptionStatus();
      if (!mounted) return;
    }
    if (mounted) setState(() => _hasAccess = service.hasAccess);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasAccess == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const TRKRLoadingScreen(),
      );
    }

    if (!_hasAccess!) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: SubscriptionRequiredScreen(
          onComplete: () {
            setState(() => _hasAccess = true);
          },
        ),
      );
    }

    return widget.child;
  }
}
