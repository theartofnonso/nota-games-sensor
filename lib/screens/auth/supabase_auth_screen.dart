import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/colors.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email'),
          backgroundColor: Colors.orange,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email for the verification code'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _otpController.text.trim(),
        type: OtpType.email,
      );

      // Success! User will be automatically navigated by the auth state listener
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $error'),
            backgroundColor: Colors.red,
          ),
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                        color: theme.colorScheme.primary.withOpacity(0.7),
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
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF212121) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.only(left: 20, top: 6, bottom: 6, right: 6),
      child: Row(
        children: [
          Icon(
            Icons.email_outlined,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade800,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'your@email.com',
                hintStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
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
                  color: const Color(0xFF3A5C4A),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade300),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'continue',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FaIcon(
                            FontAwesomeIcons.arrowRight,
                            color: Colors.grey.shade300,
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
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF212121) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.only(left: 20, top: 6, bottom: 6, right: 6),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade800,
                fontSize: 15,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
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
                  color: const Color(0xFF3A5C4A),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade300),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'verify',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FaIcon(
                            FontAwesomeIcons.arrowRight,
                            color: Colors.grey.shade300,
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
