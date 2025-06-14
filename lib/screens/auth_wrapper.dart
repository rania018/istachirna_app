import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/user_profile_checker.dart';
import 'email_verification_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

/// AuthWrapper is responsible for determining which screen to show based on the authentication state.
/// It uses a StreamBuilder to listen to auth state changes and redirects accordingly.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitializing = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    // Check for current user immediately
    _currentUser = _auth.currentUser;
    developer.log(
      'Initial auth state: ${_currentUser != null ? 'Logged in' : 'Not logged in'}',
    );

    if (_currentUser != null) {
      developer.log('User is already logged in: ${_currentUser!.uid}');
      // Ensure user profile exists
      UserProfileChecker.forceCreateUserProfile().then((success) {
        developer.log('Profile creation result: $success');
      });
    }

    // Add a small delay to show the splash screen
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen during initialization
    if (_isInitializing) {
      return const SplashScreen();
    }

    // Check current auth state directly instead of using StreamBuilder
    final user = _auth.currentUser;

    // If we have an authenticated user
    if (user != null) {
      developer.log(
        'User authenticated: ${user.uid}, Email verified: ${user.emailVerified}',
      );

      // Check if email is verified
      if (!user.emailVerified && user.email != null) {
        // If email is not verified, show verification screen
        return EmailVerificationScreen(email: user.email!);
      }

      // Email is verified, show home screen
      return const HomeScreen();
    }

    // Otherwise, show the login screen
    developer.log('User not authenticated, showing login screen');
    return const LoginScreen();
  }
}
