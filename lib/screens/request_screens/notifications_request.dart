import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../utils/general_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class NotificationsRequestScreen extends StatefulWidget {
  final VoidCallback onRequest;

  const NotificationsRequestScreen({super.key, required this.onRequest});

  @override
  State<NotificationsRequestScreen> createState() =>
      _NotificationsRequestScreenState();
}

class _NotificationsRequestScreenState
    extends State<NotificationsRequestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
            icon: const FaIcon(FontAwesomeIcons.solidCircleXmark, size: 28),
            onPressed: Navigator.of(context).pop),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: themeGradient(context: context)),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FaIcon(
                FontAwesomeIcons.solidBell,
                size: 50,
              ),
              const SizedBox(height: 50),
              Text(
                "Stay Alert",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Text(
                "Allow us to remind you about long-running workouts if you’ve become distracted. We’ll also send reminders on your training days.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26.0),
                child: OpacityButtonWidgetTwo(
                  label: "Turn on notifications",
                  buttonColor: Theme.of(context).colors.vibrantAccent,
                  onPressed: widget.onRequest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
