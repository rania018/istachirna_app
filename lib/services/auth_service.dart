import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'dart:async';
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

  // Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Validate password strength
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
      String email, String password) async {
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

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      developer.log('Sign in successful for user: ${userCredential.user?.uid}');
      
      // Update last login time and check if user is disabled
      if (userCredential.user != null) {
        if (!userCredential.user!.emailVerified) {
          await userCredential.user!.sendEmailVerification();
          throw AuthException('الرجاء تفعيل البريد الإلكتروني أولاً');
        }

        await _retryOperation(() => _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isOnline': true,
        }));
        developer.log('Updated last login time for user: ${userCredential.user?.uid}');
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
      developer.log('Unexpected error during sign in', error: e);
      throw AuthException('حدث خطأ غير متوقع: $e');
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, String name) async {
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
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      developer.log('User registration successful: ${userCredential.user?.uid}');

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Create user profile in Firestore
      if (userCredential.user != null) {
        try {
          await _retryOperation(() => _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'name': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'isOnline': true,
            'isEmailVerified': false,
            'role': 'user',
            'settings': {
              'notifications': true,
              'theme': 'light',
              'language': 'ar',
            },
          }));
          developer.log('User profile created in Firestore');

          // Ensure the user is signed in
          if (_auth.currentUser == null) {
            developer.log('User not signed in after registration, attempting to sign in...');
            await signInWithEmailAndPassword(email, password);
          }
        } catch (e) {
          developer.log('Error creating user profile in Firestore', error: e);
          // If Firestore fails, delete the auth user to maintain consistency
          await userCredential.user?.delete();
          throw AuthException('حدث خطأ في إنشاء الملف الشخصي: $e');
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log('Firebase Auth Error during registration: ${e.code} - ${e.message}', error: e);
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
      developer.log('Unexpected error during registration', error: e);
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
      
      final doc = await _retryOperation(() => _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get());
      
      if (!doc.exists) {
        developer.log('No profile found for user: ${currentUser!.uid}');
        return null;
      }
      
      developer.log('Profile fetched successfully');
      return doc.data();
    } catch (e) {
      developer.log('Error fetching user profile', error: e);
      if (e.toString().contains('unavailable') || e.toString().contains('transient')) {
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
      await _retryOperation(() => _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }));
      developer.log('Profile updated successfully');
    } catch (e) {
      developer.log('Error updating user profile', error: e);
      if (e.toString().contains('unavailable') || e.toString().contains('transient')) {
        throw AuthException('فشل الاتصال بالخادم. يرجى المحاولة مرة أخرى');
      }
      throw AuthException('حدث خطأ في تحديث بيانات المستخدم: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      if (currentUser != null) {
        // Update user status to offline
        await _retryOperation(() => _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        }));
      }
      
      developer.log('Attempting to sign out user: ${currentUser?.uid}');
      await _auth.signOut();
      await _googleSignIn.signOut();
      developer.log('Sign out successful');
    } catch (e) {
      developer.log('Error during sign out', error: e);
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
      developer.log('Password updated successfully for user: ${currentUser!.uid}');
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
      await _retryOperation(() => _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .delete());

      // Delete user account
      await currentUser!.delete();
      developer.log('Account deleted successfully for user: ${currentUser!.uid}');
    } catch (e) {
      developer.log('Error deleting account', error: e);
      throw AuthException('حدث خطأ في حذف الحساب: $e');
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
} 