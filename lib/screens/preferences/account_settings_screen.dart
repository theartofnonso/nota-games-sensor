import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/enums/weight_unit.dart';
import 'package:trainware/services/account_profile_service.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/client_access_utils.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/navigation/app_floating_navigation_bar.dart';
import 'package:trainware/widgets/settings/delete_account_section.dart';
import 'package:trainware/widgets/settings/logout_section.dart';

/// Weight unit, account actions, subscription, log out, and delete account.
/// Opened from the Settings tab on the main shell.
class AccountSettingsScreen extends StatefulWidget {
  static const routeName = '/account-settings';

  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _loading = false;
  late WeightUnit _weightUnit;

  @override
  void initState() {
    super.initState();
    _weightUnit = WeightUnit.fromString(SharedPrefs().weightUnit);
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
                leading: IconButton(
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
                    if (!isCoach) ...[
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        leading: const FaIcon(
                          FontAwesomeIcons.userPen,
                          size: 18,
                        ),
                        title: const Text('Manage account'),
                        onTap: () => _showManageAccountBottomSheet(),
                      ),
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        leading: const FaIcon(
                          FontAwesomeIcons.crown,
                          size: 18,
                        ),
                        title: const Text('Manage subscription'),
                        onTap: () =>
                            showClientSubscriptionSheet(context: context),
                      ),
                    ],
                    _buildAccountSessionEntry(isCoach: isCoach),
                    SizedBox(
                      height:
                          bottomInset + kAppFloatingNavBarReserveHeight + 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Same pattern as legacy settings: open sheet, user picks an action, sheet
  /// dismisses first, then logout / delete flow runs (loading + confirmations).
  Widget _buildAccountSessionEntry({required bool isCoach}) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surfaceOpacity = theme.brightness == Brightness.dark
        ? onSurface.withValues(alpha: 0.08)
        : onSurface.withValues(alpha: 0.06);
    final contentColor = onSurface.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: surfaceOpacity,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showLogoutAndDeleteBottomSheet(isCoach: isCoach),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.userGear,
                  size: 18,
                  color: contentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: contentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutAndDeleteBottomSheet({required bool isCoach}) async {
    await showAppActionBottomSheet<void>(
      context: context,
      isDismissible: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(
                FontAwesomeIcons.arrowRightFromBracket,
                size: 18,
              ),
              horizontalTitleGap: 8,
              title: const Text('Log out'),
              onTap: () async {
                Navigator.of(context).pop();
                if (!mounted) return;
                await logoutWithConfirmation(
                  context,
                  setLoading: (v) => setState(() => _loading = v),
                );
              },
            ),
            if (!isCoach)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const FaIcon(
                  FontAwesomeIcons.userMinus,
                  size: 18,
                  color: Colors.red,
                ),
                horizontalTitleGap: 8,
                title: Text(
                  'Delete my account',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.red,
                      ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  if (!mounted) return;
                  // Let the account menu route finish closing so delete
                  // confirmation sheets present on the correct navigator.
                  await Future<void>.delayed(Duration.zero);
                  if (!mounted) return;
                  await requestAccountDeletion(
                    context,
                    setLoading: (v) => setState(() => _loading = v),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManageAccountBottomSheet() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showErrorBottomSheet(
        context: context,
        title: 'Unable to manage account',
        message: 'Please sign in again and try again.',
      );
      return;
    }

    final existingName = await _loadClientName(userId: user.id);
    if (!mounted) return;
    var draftName = existingName ?? '';
    bool isSaving = false;
    String? helperMessage;

    await showAppActionBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage account',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your name so coaches can identify you in chat.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: draftName,
                    onChanged: (value) => draftName = value,
                    decoration: const InputDecoration(
                      hintText: 'Name',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  if (helperMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      helperMessage!,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OpacityButtonWidgetTwo(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = draftName.trim();

                              if (name.isEmpty) {
                                setSheetState(() {
                                  helperMessage = 'Please enter your name.';
                                });
                                return;
                              }

                              setSheetState(() {
                                isSaving = true;
                                helperMessage = null;
                              });

                              final saved = await updateAccountProfile(
                                userId: user.id,
                                name: name,
                              );
                              if (!sheetContext.mounted) return;

                              if (saved) {
                                Navigator.of(sheetContext).pop();
                                if (mounted) {
                                  showSnackbar(
                                    context: context,
                                    message: 'Account details updated.',
                                  );
                                }
                              } else {
                                setSheetState(() {
                                  isSaving = false;
                                  helperMessage =
                                      'Could not update account right now. Please try again.';
                                });
                              }
                            },
                      label: isSaving ? 'Saving...' : 'Save',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String?> _loadClientName({required String userId}) async {
    try {
      final row = await Supabase.instance.client
          .from('clients')
          .select('name')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) return null;
      final name = row['name']?.toString().trim();
      if (name == null || name.isEmpty) return null;
      return name;
    } catch (_) {
      return null;
    }
  }
}
