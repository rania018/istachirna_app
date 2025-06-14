import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/user_profile_checker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    // Load user profile after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  // Load user profile data
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User is not logged in, don't navigate during build phase
      return;
    }

    try {
      setState(() => _isLoading = true);

      // First ensure profile exists
      await UserProfileChecker.ensureUserProfile();

      // Then get the profile data
      final profileData = await UserProfileChecker.getUserProfile();

      if (profileData != null) {
        setState(() {
          _userData = profileData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _userData = {
            'name': user.displayName ?? 'مستخدم',
            'email': user.email ?? '',
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error loading user profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل الملف الشخصي: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle logout
  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signOut();

      // No need to navigate - AuthWrapper will handle this
      // The StreamBuilder in AuthWrapper will detect the auth state change
      // and automatically navigate to the login screen
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    if (_userData == null) {
      return const Center(child: Text('لا توجد بيانات للملف الشخصي'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile image
          _userData!['photoURL'] != null
              ? CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(_userData!['photoURL']),
              )
              : const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
          const SizedBox(height: 20),
          Text(
            _userData!['name'] ?? 'مستخدم',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _userData!['email'] ?? '',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('البريد الإلكتروني'),
            subtitle: Text(_userData!['email'] ?? ''),
          ),
          if (_userData!['createdAt'] != null)
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('تاريخ التسجيل'),
              subtitle: Text(_formatTimestamp(_userData!['createdAt'])),
            ),
          const Divider(),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to format timestamp
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'غير متوفر';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'غير متوفر';
    } catch (e) {
      return 'غير متوفر';
    }
  }
}
