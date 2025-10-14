import 'dart:io';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/colors.dart';
import 'package:tracker_app/graphQL/queries.dart';
import 'package:tracker_app/screens/request_screens/notifications_request.dart';
import 'package:tracker_app/shared_prefs.dart';
import 'package:tracker_app/urls.dart';

import '../../controllers/exercise_and_routine_controller.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/uri_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/dividers/label_divider.dart';
import '../../widgets/information_containers/information_container_with_background_image.dart';

enum WeightUnit {
  kg("kg"),
  lbs("lbs");

  const WeightUnit(this.display);

  final String display;

  static WeightUnit fromString(String string) {
    return WeightUnit.values.firstWhere((value) => value.name == string);
  }
}

enum HeightUnit {
  ftIn("ft"),
  cm("cm");

  const HeightUnit(this.display);

  final String display;

  static HeightUnit fromString(String string) {
    return HeightUnit.values.firstWhere((value) => value.name == string);
  }
}

class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings-screen';

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _loading = false;

  late WeightUnit _weightUnit;

  String _appVersion = "";

  bool _notificationEnabled = false;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    final userEmail = SharedPrefs().userEmail.isNotEmpty
        ? SharedPrefs().userEmail
        : "Apple Sign in";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 28),
          onPressed: context.pop,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          minimum: EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InformationContainerWithBackgroundImage(
                  image: 'images/recovery_girl.PNG',
                  subtitle:
                      "Loving TRNR? Your feedback helps us grow and improve.",
                  color: Colors.black,
                  onTap: _openStoreListing,
                  alignmentGeometry: Alignment.center,
                ),
                const SizedBox(
                  height: 20,
                ),
                if (Platform.isIOS)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LabelDivider(
                                label: "Notifications",
                                labelColor:
                                    isDarkMode ? Colors.white : Colors.black,
                                dividerColor: sapphireLighter,
                                fontSize: 14,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  "Allow us to remind you about long-running workouts if you’ve become distracted. We’ll also send reminders on your training days.",
                                  textAlign: TextAlign.start,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w400,
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.black)),
                            ]),
                      ),
                      ListTile(
                        onTap: _turnOnNotification,
                        dense: true,
                        horizontalTitleGap: 0,
                        leading: Text(
                            _notificationEnabled
                                ? "Notification is on"
                                : "Turn on notifications",
                            textAlign: TextAlign.start,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black)),
                        trailing: FaIcon(
                          FontAwesomeIcons.solidBell,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ListTile(
                  tileColor: Colors.transparent,
                  title: Text("Weight",
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text("Choose kg or lbs"),
                  trailing: CupertinoSlidingSegmentedControl<WeightUnit>(
                    backgroundColor:
                        isDarkMode ? sapphireDark : Colors.grey.shade400,
                    thumbColor: isDarkMode ? sapphireDark80 : Colors.white,
                    groupValue: _weightUnit,
                    children: {
                      WeightUnit.kg: SizedBox(
                          width: 30,
                          child: Text(WeightUnit.kg.display,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center)),
                      WeightUnit.lbs: SizedBox(
                          width: 30,
                          child: Text(WeightUnit.lbs.display,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center)),
                    },
                    onValueChanged: (WeightUnit? value) {
                      if (value != null) {
                        setState(() {
                          _weightUnit = value;
                        });
                        toggleWeightUnit(unit: value);
                      }
                    },
                  ),
                ),
                ListTile(
                    onTap: _sendFeedback,
                    leading: FaIcon(FontAwesomeIcons.solidPaperPlane,
                        color: isDarkMode ? Colors.white70 : Colors.black38),
                    title: Text("Feedback",
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text("help us improve")),
                ListTile(
                    onTap: _visitTRKR,
                    leading: FaIcon(FontAwesomeIcons.instagram,
                        color: isDarkMode ? Colors.white70 : Colors.black38),
                    title: Text("TRNR in the wild",
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text("follow us on socials")),
                ListTile(
                    onTap: _logout,
                    leading: FaIcon(FontAwesomeIcons.arrowRightFromBracket,
                        color: isDarkMode ? Colors.white70 : Colors.black38),
                    title: Text("Logout",
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(userEmail)),
                ListTile(
                    onTap: _delete,
                    leading: FaIcon(FontAwesomeIcons.xmark,
                        color: isDarkMode ? Colors.white70 : Colors.black38),
                    title: Text("Delete Account",
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(userEmail)),
                Center(
                  child: Text(_appVersion,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLoadingScreen() {
    setState(() {
      _loading = true;
    });
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _openStoreListing() {
    final InAppReview inAppReview = InAppReview.instance;

    inAppReview.openStoreListing(appStoreId: appStoreId);
  }

  void _sendFeedback() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'hello@trkr.fit', // Replace with the recipient's email
      queryParameters: {
        'subject': 'Feedback for TRNR', // Set the email subject
      },
    );

    await openUrl(url: emailUri.toString(), context: context);
  }

  void _clearAppData() async {
    Posthog().reset();
    await Amplify.DataStore.clear();
    SharedPrefs().clear();
    await FlutterLocalNotificationsPlugin().cancelAll();
    if (mounted) {
      Provider.of<ExerciseAndRoutineController>(context, listen: false).clear();
    }
  }

  void _visitTRKR() {
    displayBottomSheet(
        context: context,
        child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.globe, size: 18),
            horizontalTitleGap: 6,
            title: Text("On the web",
                style: Theme.of(context).textTheme.bodyLarge),
            onTap: () {
              Navigator.of(context).pop();
              openUrl(url: trackrWebUrl, context: context);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.instagram, size: 20),
            horizontalTitleGap: 6,
            title: Text("On Instagram",
                style: Theme.of(context).textTheme.bodyLarge),
            onTap: () {
              Navigator.of(context).pop();
              openUrl(url: instagramUrl, context: context);
            },
          )
        ]));
  }

  void _turnOnNotification() async {
    if (!_notificationEnabled) {
      await navigateWithSlideTransition(
          context: context,
          child: NotificationsRequestScreen(onRequest: () {
            requestNotificationPermission().then((status) {
              setState(() {
                _notificationEnabled = status;
              });
              if (mounted) {
                context.pop();
              }
            });
          }));
    }
  }

  void _checkNotificationPermission() async {
    final result = await checkIosNotificationPermission();
    setState(() {
      _notificationEnabled = result.isEnabled;
    });
  }

  void _logout() async {
    showBottomSheetWithMultiActions(
        context: context,
        title: "Log out?",
        description: "Are you sure you want to log out?",
        leftAction: Navigator.of(context).pop,
        rightAction: () async {
          Navigator.of(context).pop();
          _showLoadingScreen();
          _clearAppData();
          await Amplify.Auth.signOut();
          if (mounted) {
            context.go('/'); // Replace '/welcome' with your initial route
          }
        },
        leftActionLabel: 'Cancel',
        rightActionLabel: 'Logout',
        isRightActionDestructive: true);
  }

  void _delete() async {
    showBottomSheetWithMultiActions(
        context: context,
        title: "Delete account?",
        description:
            "Are you sure you want to delete your account? This action cannot be undone.",
        leftAction: Navigator.of(context).pop,
        rightAction: () async {
          Navigator.of(context).pop();
          _showLoadingScreen();

          final deletedExercises = await batchDeleteUserData(
              document: deleteUserExerciseData,
              documentKey: "deleteUserExerciseData");
          final deletedRoutineTemplates = await batchDeleteUserData(
              document: deleteUserRoutineTemplateData,
              documentKey: "deleteUserRoutineTemplateData");
          final deletedRoutineLogs = await batchDeleteUserData(
              document: deleteUserRoutineLogData,
              documentKey: "deleteUserRoutineLogData");
          if (deletedExercises &&
              deletedRoutineTemplates &&
              deletedRoutineLogs) {
            _hideLoadingScreen();
            _clearAppData();
            await Amplify.Auth.deleteUser();
            if (mounted) {
              context.go('/'); // Replace '/welcome' with your initial route
            }
          } else {
            _hideLoadingScreen();
            if (mounted) {
              showSnackbar(
                  context: context,
                  message: "Something went wrong. Please try again.");
            }
          }
        },
        leftActionLabel: 'Cancel',
        rightActionLabel: 'Delete',
        isRightActionDestructive: true);
  }

  void _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
    setState(() {
      _appVersion = "APP VERSION: $version (BUILD $buildNumber)";
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weightUnit = WeightUnit.fromString(SharedPrefs().weightUnit);
    _getAppVersion();
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    /// Uncomment this to enable notifications
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkNotificationPermission();
      });
    }
  }
}
