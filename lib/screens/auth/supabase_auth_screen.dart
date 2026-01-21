import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/dummy_mode_utils.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class SupabaseAuthScreen extends StatefulWidget {
  const SupabaseAuthScreen({super.key});

  @override
  State<SupabaseAuthScreen> createState() => _SupabaseAuthScreenState();
}

class _SupabaseAuthScreenState extends State<SupabaseAuthScreen> {
  bool _isLoading = false;
  bool _otpSent = false;
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  late final VideoPlayerController _videoController;

  @override
  void dispose() {
    _videoController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(
      'images/DTS_IRL_ESCAPISM_Joey_Bania_Clips_ID129.mp4',
    )
      ..setLooping(true)
      ..setVolume(0);
    _videoController.initialize().then((_) {
      if (!mounted) return;
      _videoController.play();
      setState(() {});
    });
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

    // Check if this is the test account - completely bypass auth and auto-login
    if (isTestAccountEmail(email)) {
      setState(() => _isLoading = true);

      try {
        // For test account, automatically sign in with password (no OTP needed)
        // The test account must exist in Supabase with password: 'testaccount123'
        await Supabase.instance.client.auth.signInWithPassword(
          email: testAccountEmail,
          password: 'testaccount123',
        );

        // Success! User will be automatically navigated by the auth state listener
        // No need to show snackbar or OTP screen - just silently log in
      } catch (error) {
        // If login fails, show error but don't fall back to OTP
        debugPrint('[Test Account] Login failed: $error');
        if (mounted) {
          showSnackbar(
            context: context,
            message:
                'Test account login failed. Please ensure the account exists in Supabase.',
            backgroundColor: Colors.red,
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _emailController.text.trim(),
        emailRedirectTo: null,
      );

      if (mounted) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        showSnackbar(
          context: context,
          message: 'Check your email for the verification code',
          backgroundColor: Theme.of(context).colors.vibrantAccent,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        showSnackbar(
          context: context,
          message: error.message,
          backgroundColor: Colors.red,
        );
      }
    } catch (error) {
      if (mounted) {
        showSnackbar(
          context: context,
          message: 'Unexpected error: $error',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOTP() async {
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

    try {
      // Normal OTP verification for regular users
      // (Test account should never reach here as it bypasses in _sendOTP)
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );

      // Success! User will be automatically navigated by the auth state listener
    } on AuthException catch (error) {
      if (mounted) {
        showSnackbar(
          context: context,
          message: error.message,
          backgroundColor: Colors.red,
        );
      }
    } catch (error) {
      if (mounted) {
        showSnackbar(
          context: context,
          message: 'Unexpected error: $error',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
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
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ----------------- VIDEO/GRADIENT BACKGROUND -----------------
          Positioned.fill(
            child: _videoController.value.isInitialized
                ? IgnorePointer(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController.value.size.width,
                        height: _videoController.value.size.height,
                        child: VideoPlayer(_videoController),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: themeGradient(context: context),
                    ),
                  ),
          ),
          // Gradient overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
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
                          'Not Athletes',
                          style: const TextStyle(
                            fontFamily: 'GroutpixFlow',
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Modern Email Input with integrated button
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
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: _resetForm,
                          child: Text(
                            'Use different email',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _sendOTP,
                          child: Text(
                            'Resend code',
                            style: TextStyle(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
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
        border: Border.all(
          color: colors.borderLight,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.only(left: 20, top: 6, bottom: 6, right: 6),
      child: Row(
        children: [
          Icon(
            Icons.email_outlined,
            color: colors.textSecondary,
            size: 20,
          ),
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
                hintStyle: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onSubmit,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.vibrantAccent,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'continue',
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
        border: Border.all(
          color: colors.borderLight,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.only(left: 20, top: 6, bottom: 6, right: 6),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: colors.textSecondary,
            size: 20,
          ),
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
              onChanged: (value) {
                if (value.length == 6) {
                  onSubmit();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onSubmit,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.vibrantAccent,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
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
