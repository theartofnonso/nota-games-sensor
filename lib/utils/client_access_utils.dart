import 'package:flutter/material.dart';
import '../services/client_subscription_service.dart';

Future<void> showClientSubscriptionSheet({
  required BuildContext context,
}) async {
  await ClientSubscriptionService.instance.showPaywall(context: context);
}
