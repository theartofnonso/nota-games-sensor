import 'package:flutter/material.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/services/client_subscription_service.dart';

/// Full-screen subscription paywall. Blocks access until user subscribes or
/// restores. No close button; user must complete subscription flow.
class SubscriptionRequiredScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const SubscriptionRequiredScreen({
    super.key,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isClient) {
      return const SizedBox.shrink();
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: ClientSubscriptionService.instance.buildBlockingPaywall(
        onComplete: onComplete,
        ),
      ),
    );
  }
}
