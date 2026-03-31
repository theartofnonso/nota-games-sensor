import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/services/client_acquisition_signup_service.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/name_notes_bottom_sheet.dart';

String _fullNameFromSessionUser(User? user) {
  if (user == null) return '';
  final meta = user.userMetadata;
  if (meta == null) return '';
  for (final key in ['full_name', 'name', 'display_name', 'fullName']) {
    final v = meta[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

/// Bottom sheet: full name + email (same UI as routine plan name/description sheet)
/// → [signupWithCoach].
///
/// [onRequireSignIn] — email already registered, or account created without a session
/// (backend returned `{ success: true }` without `refreshToken`); parent should show sign-in.
/// [onSuccess] — session established via `refreshToken`; parent continues authenticated flow.
Future<void> showTrainWithCoachSheet({
  required BuildContext context,
  required CoachDto coach,
  required VoidCallback onRequireSignIn,
  required VoidCallback onSuccess,
}) async {
  final sessionUser = Supabase.instance.client.auth.currentUser;
  final initialEmail = sessionUser?.email?.trim() ?? '';
  final initialName = _fullNameFromSessionUser(sessionUser);
  final signedIn = sessionUser != null && initialEmail.isNotEmpty;

  await showNameNotesBottomSheet(
    context: context,
    title: signedIn ? 'Finish your setup' : 'Create your account',
    description: signedIn
        ? 'Train with ${coach.name} — confirm your details to create your client profile.'
        : 'Train with ${coach.name}',
    primaryButtonLabel: 'Continue',
    nameFieldHint: 'Full name',
    emptyNameMessage: 'Please enter your full name',
    notesFieldHint: 'Email',
    notesFieldKeyboardType: TextInputType.emailAddress,
    notesFieldRequired: true,
    notesFieldInvalidMessage: 'Please enter a valid email',
    initialName: initialName,
    initialNotes: initialEmail,
    compact: true,
    onPrimaryAsync: (data, popSheet) async {
      final signupResult = await signupWithCoach(
        email: data.notes,
        fullName: data.name,
        coachId: coach.id,
      );
      if (!context.mounted) return;

      switch (signupResult) {
        case ClientAcquisitionSignupResult.success:
          popSheet();
          onSuccess();
          break;
        case ClientAcquisitionSignupResult.successSignInRequired:
          popSheet();
          await showBottomSheetWithSingleAction(
            context: context,
            title: 'You’re all set',
            description:
                'Your account was created. Please sign in with this email to continue.',
            action: () => Navigator.of(context).pop(),
            actionLabel: 'OK',
          );
          if (context.mounted) onRequireSignIn();
          break;
        case ClientAcquisitionSignupResult.emailAlreadyExists:
          popSheet();
          await showBottomSheetWithSingleAction(
            context: context,
            title: 'Account already exists',
            description:
                'Looks like you already have an account. Please sign in to continue.',
            action: () => Navigator.of(context).pop(),
            actionLabel: 'OK',
          );
          if (context.mounted) onRequireSignIn();
          break;
        case ClientAcquisitionSignupResult.invalidRequest:
          showSnackbar(
            context: context,
            message: 'Please check your details and try again.',
            backgroundColor: Colors.red,
          );
          break;
        case ClientAcquisitionSignupResult.serverError:
          showSnackbar(
            context: context,
            message:
                'We could not create your account. Please try again or use Sign in if you already have an account.',
            backgroundColor: Colors.red,
          );
          break;
      }
    },
  );
}
