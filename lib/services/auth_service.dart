import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Initialize auth state persistence
  Future<void> initializeAuth() async {
    try {
      developer.log('Initializing auth...');

      // Check if user is already logged in
      final user = _auth.currentUser;
      if (user != null) {
        developer.log('User already logged in: ${user.uid}');

        // Update user's online status
        await _safeUpdateUserDocument(user.uid, {
          'isOnline': true,
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      developer.log('Error initializing auth: $e', error: e);
    }
  }

  // Helper method for retrying Firestore operations
  Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= _maxRetries ||
            !(e.toString().contains('unavailable') ||
                e.toString().contains('transient'))) {
          rethrow;
        }
        developer.log('Retrying operation after error: $e (Attempt $attempts)');
        await Future.delayed(_retryDelay * attempts);
      }
    }
  }

  // Safely update user document in Firestore
  Future<void> _safeUpdateUserDocument(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      developer.log('Safely updating user document for: $userId');
      developer.log('Update data keys: ${data.keys.toList()}');

      // Check if document exists first
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();

      developer.log('Document exists: ${docSnapshot.exists}');

      // Check if settings field is being updated and ensure it's a Map
      if (data.containsKey('settings')) {
        final settings = data['settings'];
        developer.log(
          'Settings field found in update data, type: ${settings?.runtimeType}',
        );

        if (settings == null) {
          // If settings is null, provide default values
          developer.log('Settings is null, providing default values');
          data['settings'] = <String, dynamic>{
            'notifications': true,
            'theme': 'light',
            'language': 'ar',
          };
        } else if (settings is List) {
          // If settings is a List, convert it to a Map
          developer.log('Settings is a List, converting to Map');
          data['settings'] = <String, dynamic>{
            'notifications': true,
            'theme': 'light',
            'language': 'ar',
          };
        } else if (settings is Map) {
          developer.log('Settings is already a Map: ${settings.runtimeType}');
        } else {
          developer.log(
            'Settings is an unexpected type: ${settings.runtimeType}',
          );
        }
      } else {
        developer.log('No settings field in update data');
      }

      if (docSnapshot.exists) {
        // Check if existing document has a settings field that's a List
        final existingData = docSnapshot.data();
        if (existingData != null) {
          developer.log(
            'Existing document data keys: ${existingData.keys.toList()}',
          );

          if (existingData.containsKey('settings')) {
            final settings = existingData['settings'];
            developer.log('Existing settings type: ${settings?.runtimeType}');

            if (settings is List) {
              // If settings is a List, update it to be a Map
              developer.log('Existing settings is a List, will update to Map');
              data['settings'] = <String, dynamic>{
                'notifications': true,
                'theme': 'light',
                'language': 'ar',
              };
            }
          } else {
            developer.log('No settings field in existing document');
          }
        }

        // Update existing document
        developer.log('Updating existing document');
        await _firestore.collection('users').doc(userId).update(data);
      } else {
        // Create new document
        // Ensure required fields are present
        developer.log('Creating new document');

        if (!data.containsKey('createdAt')) {
          developer.log('Adding createdAt field');
          data['createdAt'] = FieldValue.serverTimestamp();
        }
        if (!data.containsKey('role')) {
          developer.log('Adding role field');
          data['role'] = 'user';
        }
        if (!data.containsKey('settings')) {
          developer.log('Adding settings field');
          data['settings'] = <String, dynamic>{
            'notifications': true,
            'theme': 'light',
            'language': 'ar',
          };
        }

        developer.log(
          'Setting document data with fields: ${data.keys.toList()}',
        );
        await _firestore.collection('users').doc(userId).set(data);
      }

      developer.log('Successfully updated/created user document for: $userId');
    } catch (e) {
      developer.log('Error updating user document: $e', error: e);
      // Don't rethrow to avoid breaking the authentication flow
    }
  }

  // Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Validate password
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل';
    }
    return null;
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      developer.log('Attempting to sign in with email: $email');

      // Validate email format
      if (!_isValidEmail(email)) {
        throw AuthException('البريد الإلكتروني غير صالح');
      }

      // Validate password
      if (password.isEmpty) {
        throw AuthException('الرجاء إدخال كلمة المرور');
      }

      developer.log('Proceeding with Firebase sign-in');

      // Try sign in with standard approach
      UserCredential? userCredential;
      try {
        developer.log('Calling Firebase signInWithEmailAndPassword');
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        developer.log('Firebase sign-in call completed');
      } on FirebaseAuthException catch (e) {
        developer.log(
          'Firebase Auth Exception during sign-in: ${e.code} - ${e.message}',
          error: e,
        );
        if (e.code == 'invalid-credential' ||
            e.toString().contains('RecaptchaCallWrapper')) {
          developer.log(
            'reCAPTCHA issue detected, trying alternative approach',
            error: e,
          );

          // Try to sign out first if there's any existing session
          try {
            await _auth.signOut();
            developer.log('Signed out current user to try fresh sign-in');
          } catch (e) {
            developer.log('Error signing out: $e', error: e);
          }

          // Try again with fresh auth instance
          developer.log('Retrying sign-in after sign-out');
          userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          developer.log('Retry sign-in successful');
        } else {
          rethrow;
        }
      }

      developer.log('Sign in successful for user: ${userCredential.user?.uid}');

      // Update last login time and check if user is disabled
      if (userCredential.user != null) {
        developer.log('Updating user login status in Firestore');
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
              'lastLoginAt': FieldValue.serverTimestamp(),
              'isOnline': true,
            });
        developer.log('User login status updated');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log('Firebase Auth Error: ${e.code} - ${e.message}', error: e);
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'لم يتم العثور على مستخدم بهذا البريد الإلكتروني';
          break;
        case 'wrong-password':
          message = 'كلمة المرور غير صحيحة';
          break;
        case 'invalid-email':
          message = 'البريد الإلكتروني غير صالح';
          break;
        case 'user-disabled':
          message = 'تم تعطيل هذا المستخدم';
          break;
        case 'too-many-requests':
          message = 'تم تجاوز عدد محاولات تسجيل الدخول. يرجى المحاولة لاحقاً';
          break;
        default:
          message = 'حدث خطأ في تسجيل الدخول: ${e.message}';
      }
      throw AuthException(message);
    } catch (e) {
      developer.log('Unexpected error during sign in: $e', error: e);
      throw AuthException('حدث خطأ غير متوقع: $e');
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      developer.log('Attempting to register user with email: $email');

      // Validate input
      if (email.isEmpty || password.isEmpty || name.isEmpty) {
        throw AuthException('جميع الحقول مطلوبة');
      }

      if (!_isValidEmail(email)) {
        throw AuthException('البريد الإلكتروني غير صالح');
      }

      final passwordError = _validatePassword(password);
      if (passwordError != null) {
        throw AuthException(passwordError);
      }

      if (name.length < 3) {
        throw AuthException('الاسم يجب أن يكون 3 أحرف على الأقل');
      }

      // Check if email is already in use
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        throw AuthException('البريد الإلكتروني مستخدم بالفعل');
      }

      // Create the user account
      developer.log('Creating user account with Firebase Auth');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      developer.log(
        'User registration successful: ${userCredential.user?.uid}',
      );

      // Send email verification
      await userCredential.user?.sendEmailVerification();
      developer.log('Email verification sent');

      // Create user profile in Firestore
      if (userCredential.user != null) {
        try {
          developer.log('Creating user profile in Firestore');

          // Create a properly structured Map for settings
          final Map<String, dynamic> settings = {
            'notifications': true,
            'theme': 'light',
            'language': 'ar',
          };

          developer.log('Settings created as Map<String, dynamic>: $settings');

          final Map<String, dynamic> userData = {
            'name': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'isOnline': true,
            'isEmailVerified': false,
            'role': 'user',
            'settings': settings,
          };

          developer.log('User data prepared: ${userData.keys}');

          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(userData);
          developer.log('User profile created in Firestore');

          // Ensure the user is signed in
          if (_auth.currentUser == null) {
            developer.log(
              'User not signed in after registration, attempting to sign in...',
            );
            await signInWithEmailAndPassword(email, password);
          }
        } catch (e) {
          developer.log(
            'Error creating user profile in Firestore: $e',
            error: e,
          );
          // If Firestore fails, delete the auth user to maintain consistency
          await userCredential.user?.delete();
          throw AuthException('حدث خطأ في إنشاء الملف الشخصي: $e');
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log(
        'Firebase Auth Error during registration: ${e.code} - ${e.message}',
        error: e,
      );
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'البريد الإلكتروني مستخدم بالفعل';
          break;
        case 'invalid-email':
          message = 'البريد الإلكتروني غير صالح';
          break;
        case 'operation-not-allowed':
          message = 'تسجيل الحساب غير مفعل';
          break;
        case 'weak-password':
          message = 'كلمة المرور ضعيفة جداً';
          break;
        default:
          message = 'حدث خطأ في إنشاء الحساب: ${e.message}';
      }
      throw AuthException(message);
    } catch (e) {
      developer.log('Unexpected error during registration: $e', error: e);
      throw AuthException('حدث خطأ غير متوقع: $e');
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) {
        developer.log('No current user found');
        return null;
      }

      developer.log('Fetching profile for user: ${currentUser!.uid}');

      final doc = await _retryOperation(
        () => _firestore.collection('users').doc(currentUser!.uid).get(),
      );

      if (!doc.exists) {
        developer.log('No profile found for user: ${currentUser!.uid}');
        return null;
      }

      developer.log('Profile fetched successfully');
      return doc.data();
    } catch (e) {
      developer.log('Error fetching user profile', error: e);
      if (e.toString().contains('unavailable') ||
          e.toString().contains('transient')) {
        throw AuthException('فشل الاتصال بالخادم. يرجى المحاولة مرة أخرى');
      }
      throw AuthException('حدث خطأ في جلب بيانات المستخدم: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String name) async {
    try {
      if (currentUser == null) {
        developer.log('No current user found for profile update');
        throw AuthException('المستخدم غير مسجل الدخول');
      }

      if (name.length < 3) {
        throw AuthException('الاسم يجب أن يكون 3 أحرف على الأقل');
      }

      developer.log('Updating profile for user: ${currentUser!.uid}');
      await _safeUpdateUserDocument(currentUser!.uid, {
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      developer.log('Profile updated successfully');
    } catch (e) {
      developer.log('Error updating user profile', error: e);
      if (e.toString().contains('unavailable') ||
          e.toString().contains('transient')) {
        throw AuthException('فشل الاتصال بالخادم. يرجى المحاولة مرة أخرى');
      }
      throw AuthException('حدث خطأ في تحديث بيانات المستخدم: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      developer.log('Starting sign out process');
      final user = _auth.currentUser;
      if (user != null) {
        // Try to update the user's online status
        try {
          developer.log('Updating user status to offline in Firestore');
          await _firestore.collection('users').doc(user.uid).update({
            'isOnline': false,
            'lastLogoutAt': FieldValue.serverTimestamp(),
          });
          developer.log('User status updated to offline');
        } catch (e) {
          developer.log(
            'Error updating user status during sign out: $e',
            error: e,
          );
          // Continue with sign out even if the update fails
        }
      }

      // Sign out from Firebase Auth
      developer.log('Signing out from Firebase Auth');
      await _auth.signOut();

      // Sign out from Google
      try {
        developer.log('Signing out from Google');
        await _googleSignIn.signOut();
        developer.log('Google sign out successful');
      } catch (e) {
        developer.log('Error signing out from Google: $e', error: e);
        // Continue even if Google sign-out fails
      }

      developer.log('Sign out process completed successfully');
    } catch (e) {
      developer.log('Error during sign out: $e', error: e);
      throw AuthException('حدث خطأ في تسجيل الخروج: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      if (!_isValidEmail(email)) {
        throw AuthException('البريد الإلكتروني غير صالح');
      }

      await _auth.sendPasswordResetEmail(email: email);
      developer.log('Password reset email sent to: $email');
    } catch (e) {
      developer.log('Error sending password reset email', error: e);
      throw AuthException('حدث خطأ في إرسال رابط إعادة تعيين كلمة المرور: $e');
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      if (currentUser == null) {
        throw AuthException('المستخدم غير مسجل الدخول');
      }

      final passwordError = _validatePassword(newPassword);
      if (passwordError != null) {
        throw AuthException(passwordError);
      }

      await currentUser!.updatePassword(newPassword);
      developer.log(
        'Password updated successfully for user: ${currentUser!.uid}',
      );
    } catch (e) {
      developer.log('Error updating password', error: e);
      throw AuthException('حدث خطأ في تحديث كلمة المرور: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      if (currentUser == null) {
        throw AuthException('المستخدم غير مسجل الدخول');
      }

      // Delete user data from Firestore
      await _retryOperation(
        () => _firestore.collection('users').doc(currentUser!.uid).delete(),
      );

      // Delete user account
      await currentUser!.delete();
      developer.log(
        'Account deleted successfully for user: ${currentUser!.uid}',
      );
    } catch (e) {
      developer.log('Error deleting account', error: e);
      throw AuthException('حدث خطأ في حذف الحساب: $e');
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      developer.log('Starting Google Sign-In process');

      // Configure Google Sign In options with silent sign-in first
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        signInOption: SignInOption.standard,
      );

      // Try silent sign in first
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.signInSilently();
        if (googleUser != null) {
          developer.log('Silent sign-in successful');
        }
      } catch (e) {
        developer.log('Silent sign-in failed: $e');
      }

      // If silent sign-in failed, try interactive sign-in
      if (googleUser == null) {
        try {
          googleUser = await googleSignIn.signIn();
        } catch (e) {
          developer.log('Interactive sign-in failed: $e');

          // If Google Play Services error occurs, try Firebase auth directly
          if (e.toString().contains('Failed to get service from broker') ||
              e.toString().contains('DEVELOPER_ERROR') ||
              e.toString().contains('Unknown calling package name')) {
            // Show a message to the user
            throw AuthException(
              'تعذر الاتصال بخدمات Google. يرجى التحقق من إعدادات الجهاز.',
            );
          }
          rethrow;
        }
      }

      if (googleUser == null) {
        developer.log('Google Sign-In was cancelled by user');
        return null;
      }

      developer.log('Google Sign-In successful, getting auth details');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      developer.log(
        'Firebase authentication successful for Google user: ${userCredential.user?.uid}',
      );

      // Check if this is a new user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser && userCredential.user != null) {
        developer.log(
          'Creating new user profile in Firestore for Google sign-in',
        );

        // Create a properly structured Map for settings
        final Map<String, dynamic> settings = {
          'notifications': true,
          'theme': 'light',
          'language': 'ar',
        };

        developer.log('Settings created as Map<String, dynamic>: $settings');

        // Create user profile in Firestore
        final Map<String, dynamic> userData = {
          'name': userCredential.user!.displayName ?? 'User',
          'email': userCredential.user!.email,
          'photoURL': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'isEmailVerified': userCredential.user!.emailVerified,
          'role': 'user',
          'settings': settings,
        };

        developer.log('User data prepared: ${userData.keys}');

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData);
        developer.log('New user profile created in Firestore for Google user');
      } else if (userCredential.user != null) {
        // Update existing user's last login
        developer.log('Updating existing Google user profile');
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
              'lastLoginAt': FieldValue.serverTimestamp(),
              'isOnline': true,
              'photoURL': userCredential.user!.photoURL,
              'name': userCredential.user!.displayName ?? 'User',
            });
        developer.log('Updated last login time for existing Google user');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log(
        'Firebase Auth Error during Google Sign-In: ${e.code} - ${e.message}',
        error: e,
      );
      String message;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message = 'يوجد حساب آخر بنفس البريد الإلكتروني';
          break;
        case 'invalid-credential':
          message = 'بيانات الاعتماد غير صالحة';
          break;
        case 'operation-not-allowed':
          message = 'تسجيل الدخول باستخدام Google غير مفعل';
          break;
        case 'user-disabled':
          message = 'تم تعطيل هذا المستخدم';
          break;
        case 'user-not-found':
          message = 'لم يتم العثور على المستخدم';
          break;
        case 'wrong-password':
          message = 'كلمة المرور غير صحيحة';
          break;
        case 'invalid-verification-code':
          message = 'رمز التحقق غير صالح';
          break;
        case 'invalid-verification-id':
          message = 'معرف التحقق غير صالح';
          break;
        default:
          message = 'حدث خطأ في تسجيل الدخول: ${e.message}';
      }
      throw AuthException(message);
    } catch (e) {
      developer.log('Unexpected error during Google Sign-In', error: e);
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException(
        'حدث خطأ غير متوقع في تسجيل الدخول باستخدام Google: $e',
      );
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
