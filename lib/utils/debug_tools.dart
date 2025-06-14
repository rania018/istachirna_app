import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Debug tools to help troubleshoot user profile issues
class DebugTools {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if the current user has a profile in Firestore and print detailed debug info
  static Future<Map<String, dynamic>> debugUserProfile() async {
    final result = <String, dynamic>{
      'success': false,
      'authState': null,
      'firestoreState': null,
      'errors': [],
    };

    try {
      // Check authentication state
      final user = _auth.currentUser;
      if (user == null) {
        developer.log('DEBUG: No authenticated user found');
        result['authState'] = 'No authenticated user';
        result['errors'].add('No authenticated user');
        return result;
      }

      // Log auth details
      result['authState'] = {
        'uid': user.uid,
        'email': user.email,
        'emailVerified': user.emailVerified,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'phoneNumber': user.phoneNumber,
        'isAnonymous': user.isAnonymous,
      };

      developer.log('DEBUG: Auth state - ${result['authState']}');

      // Check Firestore profile
      try {
        final docSnapshot =
            await _firestore.collection('users').doc(user.uid).get();

        if (!docSnapshot.exists) {
          developer.log('DEBUG: User profile does not exist in Firestore');
          result['firestoreState'] = 'Profile does not exist';
          result['errors'].add('Profile missing in Firestore');

          // Create profile
          await _createUserProfile(user);

          // Check again
          final newSnapshot =
              await _firestore.collection('users').doc(user.uid).get();
          if (newSnapshot.exists) {
            result['firestoreState'] = 'Profile created successfully';
            result['profileData'] = newSnapshot.data();
            result['success'] = true;
          } else {
            result['errors'].add('Failed to create profile');
          }
        } else {
          developer.log('DEBUG: User profile exists in Firestore');
          result['firestoreState'] = 'Profile exists';
          result['profileData'] = docSnapshot.data();
          result['success'] = true;
        }
      } catch (e) {
        developer.log('DEBUG: Error checking Firestore profile: $e', error: e);
        result['firestoreState'] = 'Error: $e';
        result['errors'].add('Firestore error: $e');
      }
    } catch (e) {
      developer.log('DEBUG: Unexpected error: $e', error: e);
      result['errors'].add('Unexpected error: $e');
    }

    return result;
  }

  /// Create a user profile in Firestore with complete information
  static Future<bool> _createUserProfile(User user) async {
    try {
      developer.log('DEBUG: Creating user profile for ${user.uid}');

      await _firestore.collection('users').doc(user.uid).set({
        'name': user.displayName ?? 'مستخدم',
        'email': user.email,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'isEmailVerified': user.emailVerified,
        'role': 'user',
        'settings': {'notifications': true, 'theme': 'light', 'language': 'ar'},
      });

      developer.log('DEBUG: User profile created successfully');
      return true;
    } catch (e) {
      developer.log('DEBUG: Error creating user profile: $e', error: e);
      return false;
    }
  }

  /// Fix any issues with the user profile
  static Future<bool> fixUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        developer.log('DEBUG: No authenticated user to fix profile for');
        return false;
      }

      return await _createUserProfile(user);
    } catch (e) {
      developer.log('DEBUG: Error fixing user profile: $e', error: e);
      return false;
    }
  }

  /// Check if a specific user's profile exists in Firestore
  static Future<Map<String, dynamic>> checkUserProfileExists(String uid) async {
    final result = <String, dynamic>{
      'exists': false,
      'data': null,
      'error': null,
    };

    try {
      developer.log('Checking if user profile exists for: $uid');

      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (docSnapshot.exists) {
        developer.log('User profile exists for: $uid');
        result['exists'] = true;
        result['data'] = docSnapshot.data();
      } else {
        developer.log('User profile does not exist for: $uid');
        result['exists'] = false;
      }
    } catch (e) {
      developer.log('Error checking user profile: $e', error: e);
      result['error'] = e.toString();
    }

    return result;
  }
}
