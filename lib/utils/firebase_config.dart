import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  /// Main configure method that sets up all Firebase services
  static Future<void> configure() async {
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        developer.log('Firebase is not initialized');
        return;
      }

      // Configure Firestore
      await configureFirestoreRules();

      // Configure Auth
      await configureAuthSettings();

      developer.log('Firebase configuration completed successfully');
    } catch (e) {
      developer.log('Error during Firebase configuration: $e', error: e);
      // Don't rethrow - just log the error to avoid app crashes
    }
  }

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

      return true;
    } catch (e) {
      developer.log('Firebase configuration error: $e', error: e);
      return false;
    }
  }

  static Future<void> configureFirestoreRules() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Set up cache settings
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Enable offline persistence
      await firestore
          .enablePersistence(const PersistenceSettings(synchronizeTabs: true))
          .catchError((e) {
            // This might fail if already enabled or in a web environment
            developer.log(
              'Note: Firestore persistence already enabled or not supported: $e',
            );
          });

      developer.log('Firestore settings configured successfully');
    } catch (e) {
      developer.log('Error configuring Firestore settings: $e', error: e);
      // Don't rethrow - just log the error to avoid app crashes
    }
  }

  static Future<void> configureAuthSettings() async {
    try {
      final auth = FirebaseAuth.instance;

      // Configure auth settings
      await auth.setSettings(
        appVerificationDisabledForTesting: false,
        userAccessGroup: null,
        phoneNumber: null,
        smsCode: null,
        forceRecaptchaFlow: false,
      );

      // Set persistence mode
      await auth.setPersistence(Persistence.LOCAL);

      developer.log('Auth settings configured successfully');
    } catch (e) {
      developer.log('Error configuring auth settings: $e', error: e);
      // Don't rethrow - just log the error to avoid app crashes
    }
  }
}
