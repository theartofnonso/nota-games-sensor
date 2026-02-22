import 'package:flutter/material.dart';
import '../services/client_subscription_service.dart';

enum ClientFeatureGate {
  startWorkoutSession,
  resumeWorkoutSession,
  logMeal,
  generic,
}

String _defaultBlockedMessageForFeature(ClientFeatureGate feature) {
  switch (feature) {
    case ClientFeatureGate.startWorkoutSession:
      return 'You need an active subscription to start a workout session.';
    case ClientFeatureGate.resumeWorkoutSession:
      return 'You need an active subscription to resume workout sessions.';
    case ClientFeatureGate.logMeal:
      return 'You need an active subscription to log meals and nutrition.';
    case ClientFeatureGate.generic:
      return 'You need an active subscription to use this feature.';
  }
}

Future<bool> ensureClientSubscriptionAccess({
  required BuildContext context,
  String blockedMessage =
      'You need an active subscription to use this feature.',
}) async {
  return ClientSubscriptionService.instance.ensureAccess(
    context: context,
    blockedMessage: blockedMessage,
  );
}

Future<bool> guardClientFeature({
  required BuildContext context,
  required ClientFeatureGate feature,
  String? blockedMessage,
}) {
  return ensureClientSubscriptionAccess(
    context: context,
    blockedMessage: blockedMessage ?? _defaultBlockedMessageForFeature(feature),
  );
}

Future<void> showClientSubscriptionSheet({
  required BuildContext context,
}) async {
  await ClientSubscriptionService.instance.showPaywall(context: context);
}
