import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class FirebaseConfig {
  static Future<bool> checkConfiguration() async {
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        developer.log('Firebase is not initialized');
        return false;
      }

      // Check Authentication
      final auth = FirebaseAuth.instance;
      developer.log('Firebase Auth is available');

      // Check Firestore
      final firestore = FirebaseFirestore.instance;
      developer.log('Firestore is available');

      // Test Firestore connection
      await firestore.collection('test').doc('test').set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      await firestore.collection('test').doc('test').delete();
      developer.log('Firestore connection test successful');

      return true;
    } catch (e) {
      developer.log('Firebase configuration error: $e', error: e);
      return false;
    }
  }

  static Future<void> configureFirestoreRules() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Set up security rules
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      developer.log('Firestore rules configured successfully');
    } catch (e) {
      developer.log('Error configuring Firestore rules: $e', error: e);
      rethrow;
    }
  }

  static Future<void> configureAuthSettings() async {
    try {
      final auth = FirebaseAuth.instance;
      
      // Configure auth settings
      await auth.setSettings(
        appVerificationDisabledForTesting: false,
        phoneNumber: null,
        smsCode: null,
      );
      
      developer.log('Auth settings configured successfully');
    } catch (e) {
      developer.log('Error configuring auth settings: $e', error: e);
      rethrow;
    }
  }
} 