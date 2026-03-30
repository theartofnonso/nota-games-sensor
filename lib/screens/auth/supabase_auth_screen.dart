import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/dummy_mode_utils.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/utils/coach_access_utils.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

class SupabaseAuthScreen extends StatefulWidget {
  const SupabaseAuthScreen({super.key, this.onDiscoverCoaches});

  /// Client app: returns to pre-auth coach discovery (e.g. after opening Sign in from welcome).
  final VoidCallback? onDiscoverCoaches;

  @override
  State<SupabaseAuthScreen> createState() => _SupabaseAuthScreenState();
}

class _SupabaseAuthScreenState extends State<SupabaseAuthScreen> {
  bool _isLoading = false;
  bool _otpSent = false;
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showSnackbar(
        context: context,
        message: 'Please enter your email',
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (!email.contains('@')) {
      showSnackbar(
        context: context,
        message: 'Please enter a valid email',
        backgroundColor: Colors.orange,
      );
      return;
    }

    // Access check now happens after authentication succeeds.
    setState(() => _isLoading = true);

    if (AppConfig.isCoach) {
      final canProceed = await requireCoachAccess(
        context: context,
        email: email,
      );
      if (!mounted) return;
      if (!canProceed) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // Check if this is a demo account - bypass OTP and auto-login.
    if (isTestAccountEmail(email)) {
      final password = getDemoPassword(email);
      if (password == null) {
        setState(() => _isLoading = false);
        return;
      }

      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        // Success! User will be automatically navigated by the auth state listener
      } catch (error) {
        debugPrint('[Demo Account] Login failed: $error');
        if (mounted) {
          showSnackbar(
            context: context,
            message:
                'Demo account login failed. Please ensure the account exists in Supabase.',
            backgroundColor: Colors.red,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
      );
      if (kDebugMode) {
        debugPrint('[Auth] OTP sent to $email');
      }

      if (mounted) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
      }
    } on AuthException catch (error) {
      debugPrint(
        '[Auth] AuthException on sendOTP: ${error.message} (statusCode: ${error.statusCode})',
      );
      if (mounted) {
        showSnackbar(
          context: context,
          message: 'We could not send a code right now. Please try again.',
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (mounted) {
        showSnackbar(
          context: context,
          message: 'Unexpected error: $error',
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      showSnackbar(
        context: context,
        message: 'Please enter a valid 6-digit code',
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);

    if (kDebugMode) {
      debugPrint('[Auth] Verifying OTP for $email, code: $otp');
    }

    try {
      // Verify OTP
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );

      // Success! Profile gate checks clients table (expect row from website)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } on AuthException catch (error) {
      debugPrint(
        '[Auth] AuthException on verifyOTP: ${error.message} (statusCode: ${error.statusCode})',
      );
      if (mounted) {
        showSnackbar(
          context: context,
          message: 'We could not verify that code. Please try again.',
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (mounted) {
        showSnackbar(
          context: context,
          message: 'Unexpected error: $error',
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _otpSent = false;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TRKRColors>()!;
    final isDarkMode = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ----------------- GRADIENT BACKGROUND -----------------
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: themeGradient(context: context),
                ),
              ),
            ),

            // ----------------- CONTENT --------------------
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            AppConfig.appName,
                            style: const TextStyle(
                              fontFamily: 'GroutpixFlow',
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (!_otpSent)
                          _ModernEmailInput(
                            controller: _emailController,
                            onSubmit: _sendOTP,
                            isLoading: _isLoading,
                            isDarkMode: isDarkMode,
                          ),

                        // OTP field (shown after email submitted)
                        if (_otpSent) ...[
                          _ModernOTPInput(
                            controller: _otpController,
                            onSubmit: _verifyOTP,
                            isLoading: _isLoading,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Enter the 6-digit code sent to ${_emailController.text.trim()}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OpacityButtonWidgetTwo(
                              label: 'Use different email',
                              onPressed: _resetForm,
                              showArrowRight: false,
                              outlineColor: colors.borderLight,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OpacityButtonWidgetTwo(
                              label: 'Resend code',
                              onPressed: _isLoading ? null : _sendOTP,
                              showArrowRight: false,
                              outlineColor: colors.borderLight,
                            ),
                          ),
                        ],
                        if (AppConfig.isClient &&
                            widget.onDiscoverCoaches != null) ...[
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OpacityButtonWidgetTwo(
                              label: 'Discover coaches',
                              onPressed: widget.onDiscoverCoaches,
                              buttonColor: colors.vibrantAccent,
                              showArrowRight: false,
                              outlineColor: colors.borderLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernEmailInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isLoading;
  final bool isDarkMode;

  const _ModernEmailInput({
    required this.controller,
    required this.onSubmit,
    required this.isLoading,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TRKRColors>()!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: colors.borderLight, width: 1),
      ),
      padding: const EdgeInsets.only(left: 20, top: 6, bottom: 6, right: 6),
      child: Row(
        children: [
          Icon(Icons.email_outlined, color: colors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'your@email.com',
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 15),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onSubmit,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.vibrantAccent,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child:
                    isLoading
                        ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                        : FaIcon(
                          FontAwesomeIcons.arrowRight,
                          color: Colors.black,
                          size: 16,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernOTPInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isLoading;
  final bool isDarkMode;

  const _ModernOTPInput({
    required this.controller,
    required this.onSubmit,
    required this.isLoading,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TRKRColors>()!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: colors.borderLight, width: 1),
      ),
      padding: const EdgeInsets.only(left: 20, top: 6, bottom: 6, right: 6),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: colors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 15,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 15,
                  letterSpacing: 4,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onSubmit,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.vibrantAccent,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child:
                    isLoading
                        ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                        : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'verify',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FaIcon(
                              FontAwesomeIcons.arrowRight,
                              color: Colors.black,
                              size: 14,
                            ),
                          ],
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
