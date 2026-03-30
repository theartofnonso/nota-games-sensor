import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/enums/weight_unit.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';
import 'package:trainware/widgets/navigation/app_floating_navigation_bar.dart';
import 'package:trainware/widgets/settings/delete_account_section.dart';
import 'package:trainware/widgets/settings/logout_section.dart';

/// Weight unit, log out, and delete account.
/// Opened from the Settings tab on the main shell.
class AccountSettingsScreen extends StatefulWidget {
  static const routeName = '/account-settings';

  /// When true, hide close; bottom nav handles leaving the screen.
  final bool embeddedInShell;

  const AccountSettingsScreen({
    super.key,
    this.embeddedInShell = false,
  });

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _loading = false;
  late WeightUnit _weightUnit;
  String _appVersionLabel = '';

  @override
  void initState() {
    super.initState();
    _weightUnit = WeightUnit.fromString(SharedPrefs().weightUnit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAppVersion());
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLabel =
            'Version ${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (mounted) setState(() => _appVersionLabel = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return TRKRLoadingScreen(
        action: () {
          if (mounted) {
            setState(() => _loading = false);
          }
        },
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isCoach = AppConfig.isCoach;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBar(
                title: const Text('Account & preferences'),
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: !widget.embeddedInShell,
                leading: widget.embeddedInShell
                    ? null
                    : IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.solidCircleXmark,
                          size: 28,
                        ),
                        onPressed: () => context.pop(),
                      ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 30.0),
                      tileColor: Colors.transparent,
                      title: Text(
                        'Weight',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: const Text('Choose kg or lbs'),
                      trailing: CupertinoSlidingSegmentedControl<WeightUnit>(
                        backgroundColor: isDarkMode
                            ? Theme.of(context).colors.sapphireDark
                            : Colors.grey.shade400,
                        thumbColor: isDarkMode
                            ? Theme.of(context).colors.sapphireDark80
                            : Colors.white,
                        groupValue: _weightUnit,
                        children: {
                          WeightUnit.kg: SizedBox(
                            width: 30,
                            child: Text(
                              WeightUnit.kg.display,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          WeightUnit.lbs: SizedBox(
                            width: 30,
                            child: Text(
                              WeightUnit.lbs.display,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        },
                        onValueChanged: (WeightUnit? value) {
                          if (value != null) {
                            setState(() => _weightUnit = value);
                            toggleWeightUnit(unit: value);
                          }
                        },
                      ),
                    ),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      leading: const FaIcon(
                        FontAwesomeIcons.arrowRightFromBracket,
                        size: 18,
                      ),
                      title: const Text('Log out'),
                      onTap: () async {
                        await logoutWithConfirmation(
                          context,
                          setLoading: (v) => setState(() => _loading = v),
                        );
                      },
                    ),
                    if (!isCoach)
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        leading: const FaIcon(
                          FontAwesomeIcons.userMinus,
                          size: 18,
                          color: Colors.red,
                        ),
                        title: Text(
                          'Delete my account',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.red,
                                  ),
                        ),
                        onTap: () async {
                          await requestAccountDeletion(
                            context,
                            setLoading: (v) => setState(() => _loading = v),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  bottomInset + kAppFloatingNavBarReserveHeight + 16,
                ),
                child: _appVersionLabel.isEmpty
                    ? const SizedBox(height: 14)
                    : Text(
                        _appVersionLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
