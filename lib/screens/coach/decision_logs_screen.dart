import 'package:flutter/material.dart';
import 'package:trainware/widgets/decision_logs/decision_logs_list.dart';
import 'package:trainware/utils/general_utils.dart';

class DecisionLogsScreen extends StatelessWidget {
  static const routeName = '/decision-logs';

  final String clientId;

  const DecisionLogsScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'Decision log'.toUpperCase(),
          style: theme.textTheme.titleMedium,
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: DecisionLogsList(
            clientId: clientId,
            limit: 100,
            showTitle: false,
            showViewAll: false,
          ),
        ),
      ),
    );
  }
}
