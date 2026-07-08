import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../managers/session_manager.dart';

/// Calls [SessionManager.onAppExit] when the player leaves the app.
///
/// Handoff: call `/leave` when the session ends or the player exits the app.
/// Uses `onDetach` only — backgrounding (`paused`) keeps the session alive so
/// motion can continue while the phone is locked or in a pocket.
class SessionLifecycleBridge extends StatefulWidget {
  const SessionLifecycleBridge({super.key, required this.child});

  final Widget child;

  @override
  State<SessionLifecycleBridge> createState() => _SessionLifecycleBridgeState();
}

class _SessionLifecycleBridgeState extends State<SessionLifecycleBridge> {
  AppLifecycleListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listener ??= AppLifecycleListener(
      onDetach: () {
        if (!mounted) return;
        context.read<SessionManager>().onAppExit();
      },
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
