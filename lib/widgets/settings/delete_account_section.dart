import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/notathletes_user_deletion_service.dart';
import '../../utils/dialog_utils.dart';
import '../bottom_sheets/app_bottom_sheet.dart';
import '../buttons/opacity_button_widget_two.dart';

/// Client-only: danger-zone section that contains the delete account action.
/// Visually separated so the entry point is clear and intentional.
class DeleteAccountSection extends StatelessWidget {
  final VoidCallback onDeleteTap;

  const DeleteAccountSection({
    super.key,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surfaceOpacity = theme.brightness == Brightness.dark
        ? onSurface.withValues(alpha: 0.08)
        : onSurface.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: surfaceOpacity,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onDeleteTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.userMinus,
                  size: 18,
                  color: Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete my account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.red,
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
}

const String _deleteAccountConfirmationPhrase = 'Delete my account';

/// Matches [confirmLogoutBottomSheet] and other action sheets (padding + type scale).
const EdgeInsets _deleteSheetPadding = EdgeInsets.all(26);

String _deleteAccountSubscriptionReminder(BuildContext context) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS:
      return 'If you subscribe in the App Store, deleting your account does not '
          'cancel your subscription or stop renewal. To avoid further charges, '
          'open Settings → Apple ID → Subscriptions, find this app, and cancel there.';
    case TargetPlatform.android:
      return 'If you subscribe on Google Play, deleting your account does not '
          'cancel your subscription. Open the Play Store → profile menu → '
          'Payments & subscriptions to cancel.';
    default:
      return 'If you subscribe through the App Store or Google Play, deleting '
          'your account does not cancel billing. Cancel the subscription in '
          'your device’s store settings.';
  }
}

String _deleteAccountSubscriptionReminderShort(BuildContext context) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS:
      return 'Reminder: cancel any App Store subscription in Settings → Subscriptions.';
    case TargetPlatform.android:
      return 'Reminder: cancel any Play Store subscription in Payments & subscriptions.';
    default:
      return 'Reminder: cancel store subscriptions separately if you are subscribed.';
  }
}

/// Runs the full account deletion flow: two confirmation sheets, then
/// Agora → Supabase delete → sign out. Calls [setLoading] with
/// true/false so the parent can show a loading overlay.
Future<void> requestAccountDeletion(
  BuildContext context, {
  required void Function(bool) setLoading,
}) async {
  final proceeded = await showAppActionBottomSheet<bool>(
    context: context,
    isDismissible: true,
    child: Padding(
      padding: _deleteSheetPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Delete account',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            'Your account and all associated data (workouts, plans, nutrition logs) will be permanently deleted. This cannot be undone.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 12),
          Text(
            _deleteAccountSubscriptionReminder(context),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: () => Navigator.of(context).pop(true),
              label: 'Proceed',
              buttonColor: Colors.red,
              showArrowRight: false,
            ),
          ),
        ],
      ),
    ),
  );
  if (proceeded != true) return;

  if (!context.mounted) return;
  final confirmed = await _showDeleteAccountConfirmSheet(context);
  if (confirmed != true) return;

  const defaultErrorMessage =
      'Something went wrong. Please try again or contact support at notathletes.com.';

  setLoading(true);
  final outcome = await deleteAccountAndSignOut();
  if (!context.mounted) return;
  setLoading(false);
  if (!outcome.ok) {
    showErrorBottomSheet(
      context: context,
      title: 'Could not delete account',
      message: outcome.errorMessage ?? defaultErrorMessage,
    );
    return;
  }
}

Future<bool?> _showDeleteAccountConfirmSheet(BuildContext context) async {
  String typed = '';
  return showAppBottomSheet<bool>(
    context: context,
    isDraggable: false,
    isScrollControlled: true,
    isDismissible: true,
    child: StatefulBuilder(
      builder: (context, setSheetState) {
        final matches = typed.trim() == _deleteAccountConfirmationPhrase;
        return Padding(
          padding: _deleteSheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm deletion',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 8),
              Text(
                'To confirm, type "$_deleteAccountConfirmationPhrase" below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 12),
              TextField(
                style: Theme.of(context).textTheme.bodyLarge,
                onChanged: (value) => setSheetState(() => typed = value),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: _deleteAccountConfirmationPhrase,
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                      ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _deleteAccountSubscriptionReminderShort(context),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.35,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.72),
                    ),
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OpacityButtonWidgetTwo(
                  onPressed: matches
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  label: 'Delete my account',
                  buttonColor: Colors.red,
                  showArrowRight: false,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

