import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _isSendingEmail = false;
  Timer? _timer;
  Timer? _verificationTimer;
  int _timeLeft = 60;

  @override
  void initState() {
    super.initState();
    _checkEmailVerification();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _verificationTimer?.cancel();
    super.dispose();
  }

  // Start timer for resend cooldown
  void _startTimer() {
    _timeLeft = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        if (mounted) {
          setState(() {
            _timeLeft--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Check if email is verified
  Future<void> _checkEmailVerification() async {
    if (_auth.currentUser == null) return;

    setState(() => _isLoading = true);

    // Start a periodic check for email verification
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      try {
        // Get a fresh instance of the user instead of reloading
        final user = _auth.currentUser;

        // Sign out and sign in again to refresh the token
        if (user != null) {
          // Check if email is verified without reload
          final idTokenResult = await user.getIdTokenResult(true);
          final isVerified = idTokenResult.claims?['email_verified'] ?? false;

          if (isVerified || user.emailVerified) {
            timer.cancel();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تأكيد البريد الإلكتروني بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );

              // Force rebuild of AuthWrapper
              setState(() {});

              // Navigate back to let AuthWrapper handle redirection
              Navigator.pop(context);
            }
          }
        }
      } catch (e) {
        developer.log('Error checking email verification: $e', error: e);
      }
    });

    setState(() => _isLoading = false);
  }

  // Resend verification email
  Future<void> _resendVerificationEmail() async {
    if (_auth.currentUser == null) return;

    setState(() => _isSendingEmail = true);

    try {
      await _auth.currentUser!.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال رابط التحقق. يرجى التحقق من بريدك الإلكتروني',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _startTimer();
    } catch (e) {
      developer.log('Error sending verification email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في إرسال البريد الإلكتروني: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingEmail = false);
      }
    }
  }

  // Sign out
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      developer.log('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تسجيل الخروج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Manual verification check
  Future<void> _manualVerificationCheck() async {
    setState(() => _isLoading = true);

    try {
      // Get a fresh instance of the user
      final user = _auth.currentUser;

      if (user != null) {
        // Sign out and sign in again to refresh the token
        final credential = await _auth.signInWithEmailAndPassword(
          email: widget.email,
          password: '', // This will fail, but we'll catch it
        );

        if (credential.user?.emailVerified ?? false) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تأكيد البريد الإلكتروني بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لم يتم تأكيد البريد الإلكتروني بعد'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Expected to fail with wrong password, but we just want to refresh the token
      developer.log('Manual verification check: $e', error: e);

      // Try to get fresh user data
      final user = _auth.currentUser;
      if (user != null && user.emailVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تأكيد البريد الإلكتروني بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم تأكيد البريد الإلكتروني بعد'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد البريد الإلكتروني'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 100,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'تحقق من بريدك الإلكتروني',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لقد أرسلنا رابط تأكيد إلى بريدك الإلكتروني:',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.email,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'يرجى النقر على الرابط في البريد الإلكتروني لتأكيد عنوان بريدك الإلكتروني.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'إذا لم تجد البريد الإلكتروني، يرجى التحقق من مجلد الرسائل غير المرغوب فيها.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed:
                          _timeLeft == 0 && !_isSendingEmail
                              ? _resendVerificationEmail
                              : null,
                      icon:
                          _isSendingEmail
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.email),
                      label: Text(
                        _timeLeft > 0
                            ? 'إعادة إرسال الرابط (${_timeLeft}s)'
                            : 'إعادة إرسال رابط التأكيد',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _manualVerificationCheck,
                      child: const Text('لقد قمت بالتأكيد بالفعل'),
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: _signOut,
                      child: const Text(
                        'تسجيل الخروج والعودة إلى شاشة تسجيل الدخول',
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
