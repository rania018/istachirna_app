import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileChecker {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if the current user has a profile in Firestore
  /// If not, create one with default values
  static Future<bool> ensureUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        developer.log('No authenticated user found');
        return false;
      }

      developer.log('Checking if user profile exists for: ${user.uid}');

      // Check if user document exists
      final docSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      if (!docSnapshot.exists) {
        developer.log('User profile does not exist, creating one');

        // Create user profile with default values
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? 'مستخدم',
          'email': user.email,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'isEmailVerified': user.emailVerified,
          'role': 'user',
          'settings': <String, dynamic>{
            'notifications': true,
            'theme': 'light',
            'language': 'ar',
          },
        });

        developer.log('User profile created successfully');
        return true;
      } else {
        developer.log('User profile already exists');

        // Check if settings is properly structured
        final existingData = docSnapshot.data();
        if (existingData != null && existingData.containsKey('settings')) {
          final settings = existingData['settings'];
          // If settings is a List or null, update it to be a proper Map
          if (settings == null || settings is List) {
            await _firestore.collection('users').doc(user.uid).update({
              'settings': <String, dynamic>{
                'notifications': true,
                'theme': 'light',
                'language': 'ar',
              },
            });
          }
        }

        // Update last login time
        await _firestore.collection('users').doc(user.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isOnline': true,
        });

        return true;
      }
    } catch (e) {
      developer.log('Error ensuring user profile: $e', error: e);
      return false;
    }
  }

  /// Get the current user's profile data from Firestore
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        developer.log('No authenticated user found');
        return null;
      }

      final docSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      if (!docSnapshot.exists) {
        developer.log('User profile does not exist for: ${user.uid}');
        return null;
      }

      return docSnapshot.data();
    } catch (e) {
      developer.log('Error getting user profile: $e', error: e);
      return null;
    }
  }

  /// Force creation of user profile in Firestore with complete data
  static Future<bool> forceCreateUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        developer.log('No authenticated user found');
        return false;
      }

      developer.log('Force creating user profile for: ${user.uid}');

      try {
        // First check if the user document exists
        final docSnapshot =
            await _firestore.collection('users').doc(user.uid).get();
        developer.log(
          'Retrieved document snapshot, exists: ${docSnapshot.exists}',
        );

        if (docSnapshot.exists) {
          developer.log('Document data: ${docSnapshot.data()}');
        }

        // Prepare user data
        final Map<String, dynamic> userData = {
          'name': user.displayName ?? 'مستخدم',
          'email': user.email,
          'photoURL': user.photoURL,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'isEmailVerified': user.emailVerified,
        };

        developer.log('Prepared basic user data: ${userData.keys}');

        // If document doesn't exist, add creation timestamp
        if (!docSnapshot.exists) {
          userData['createdAt'] = FieldValue.serverTimestamp();
          userData['role'] = 'user';

          // Make sure settings is a Map and not a List
          userData['settings'] = <String, dynamic>{
            'notifications': true,
            'theme': 'light',
            'language': 'ar',
          };

          developer.log('Added additional fields for new user');
        } else {
          // If document exists, check if settings is properly structured
          final existingData = docSnapshot.data();
          developer.log('Checking existing settings field');

          if (existingData != null && existingData.containsKey('settings')) {
            final settings = existingData['settings'];
            developer.log('Existing settings type: ${settings?.runtimeType}');

            // If settings is a List or null, replace it with a proper Map
            if (settings == null) {
              developer.log('Settings is null, creating new settings object');
              userData['settings'] = <String, dynamic>{
                'notifications': true,
                'theme': 'light',
                'language': 'ar',
              };
            } else if (settings is List) {
              developer.log('Settings is a List, converting to Map');
              userData['settings'] = <String, dynamic>{
                'notifications': true,
                'theme': 'light',
                'language': 'ar',
              };
            } else if (settings is Map) {
              developer.log('Settings is already a Map, no conversion needed');
            } else {
              developer.log(
                'Settings is an unexpected type: ${settings.runtimeType}',
              );
              userData['settings'] = <String, dynamic>{
                'notifications': true,
                'theme': 'light',
                'language': 'ar',
              };
            }
          } else {
            developer.log('No settings field found, creating one');
            userData['settings'] = <String, dynamic>{
              'notifications': true,
              'theme': 'light',
              'language': 'ar',
            };
          }
        }

        // Create or update user profile with merge option to preserve existing data
        developer.log('Saving user data to Firestore with merge option');
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userData, SetOptions(merge: true));

        developer.log('User profile force created/updated successfully');
        return true;
      } catch (e) {
        developer.log('Error in Firestore operations: $e', error: e);
        return false;
      }
    } catch (e) {
      developer.log('Error force creating user profile: $e', error: e);
      return false;
    }
  }
}
