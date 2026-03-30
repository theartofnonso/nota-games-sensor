import 'package:flutter/material.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/services/client_acquisition_signup_service.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/name_notes_bottom_sheet.dart';

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
  final result = await showNameNotesBottomSheet(
    context: context,
    title: 'Create your account',
    description: 'Train with ${coach.name}',
    primaryButtonLabel: 'Continue',
    nameFieldHint: 'Full name',
    emptyNameMessage: 'Please enter your full name',
    notesFieldHint: 'Email',
    notesFieldKeyboardType: TextInputType.emailAddress,
    notesFieldRequired: true,
    notesFieldInvalidMessage: 'Please enter a valid email',
    compact: true,
  );

  if (result == null) return;
  if (!context.mounted) return;

  final signupResult = await signupWithCoach(
    email: result.notes,
    fullName: result.name,
    coachId: coach.id,
  );

  if (!context.mounted) return;

  switch (signupResult) {
    case ClientAcquisitionSignupResult.success:
      onSuccess();
      break;
    case ClientAcquisitionSignupResult.successSignInRequired:
      await showBottomSheetWithSingleAction(
        context: context,
        title: 'You’re all set',
        description:
            'Your account was created. Please sign in with this email to continue.',
        action: () => Navigator.of(context).pop(),
        actionLabel: 'OK',
      );
      if (!context.mounted) return;
      onRequireSignIn();
      break;
    case ClientAcquisitionSignupResult.emailAlreadyExists:
      await showBottomSheetWithSingleAction(
        context: context,
        title: 'Account already exists',
        description:
            'Looks like you already have an account. Please sign in to continue.',
        action: () => Navigator.of(context).pop(),
        actionLabel: 'OK',
      );
      if (!context.mounted) return;
      onRequireSignIn();
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
}
