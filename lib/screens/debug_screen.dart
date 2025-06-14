import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/debug_tools.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _debugResult;
  String _statusMessage = '';
  final TextEditingController _uidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _runDebugCheck();
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _runDebugCheck() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري فحص حالة المستخدم...';
    });

    try {
      final result = await DebugTools.debugUserProfile();
      setState(() {
        _debugResult = result;
        _statusMessage =
            result['success']
                ? 'تم العثور على الملف الشخصي بنجاح'
                : 'هناك مشاكل في الملف الشخصي';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء التشخيص: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fixUserProfile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري إصلاح الملف الشخصي...';
    });

    try {
      final success = await DebugTools.fixUserProfile();
      if (success) {
        await _runDebugCheck();
      } else {
        setState(() {
          _statusMessage = 'فشل إصلاح الملف الشخصي';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء الإصلاح: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkSpecificUser() async {
    if (_uidController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال معرف المستخدم'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري فحص المستخدم المحدد...';
    });

    try {
      final result = await DebugTools.checkUserProfileExists(
        _uidController.text.trim(),
      );

      setState(() {
        _debugResult = {
          'success': result['exists'],
          'authState': null,
          'firestoreState':
              result['exists'] ? 'Profile exists' : 'Profile does not exist',
          'errors': result['error'] != null ? [result['error']] : [],
          'profileData': result['data'],
        };

        _statusMessage =
            result['exists']
                ? 'تم العثور على الملف الشخصي للمستخدم المحدد'
                : 'لم يتم العثور على الملف الشخصي للمستخدم المحدد';

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء فحص المستخدم المحدد: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تشخيص الملف الشخصي')),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusMessage),
                  ],
                ),
              )
              : _buildDebugContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _runDebugCheck,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildDebugContent() {
    if (_debugResult == null) {
      return const Center(child: Text('لا توجد بيانات للعرض'));
    }

    final authState = _debugResult!['authState'];
    final firestoreState = _debugResult!['firestoreState'];
    final errors = _debugResult!['errors'] as List;
    final profileData = _debugResult!['profileData'];
    final success = _debugResult!['success'] as bool;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Check specific user section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'فحص مستخدم محدد:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _uidController,
                    decoration: const InputDecoration(
                      labelText: 'معرف المستخدم (UID)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _checkSpecificUser,
                    icon: const Icon(Icons.search),
                    label: const Text('فحص'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: success ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    success ? Icons.check_circle : Icons.error,
                    color: success ? Colors.green : Colors.red,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (authState != null) ...[
            const Text(
              'حالة المصادقة:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildAuthStateCard(authState),
            const SizedBox(height: 16),
          ],
          const Text(
            'حالة Firestore:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildFirestoreStateCard(firestoreState, profileData),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'الأخطاء:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildErrorsList(errors),
          ],
          const SizedBox(height: 16),
          if (!success)
            ElevatedButton.icon(
              onPressed: _fixUserProfile,
              icon: const Icon(Icons.build),
              label: const Text('إصلاح الملف الشخصي'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthStateCard(dynamic authState) {
    if (authState == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد بيانات المصادقة'),
        ),
      );
    }

    if (authState is String) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(authState),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('معرف المستخدم: ${authState['uid']}'),
            Text('البريد الإلكتروني: ${authState['email']}'),
            Text('البريد مؤكد: ${authState['emailVerified']}'),
            Text('الاسم: ${authState['displayName'] ?? 'غير متوفر'}'),
            Text(
              'الصورة: ${authState['photoURL'] != null ? 'متوفرة' : 'غير متوفرة'}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirestoreStateCard(dynamic firestoreState, dynamic profileData) {
    if (firestoreState == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد بيانات Firestore'),
        ),
      );
    }

    if (firestoreState is String && profileData == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(firestoreState),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('حالة: $firestoreState'),
            if (profileData != null) ...[
              const Divider(),
              const Text(
                'بيانات الملف الشخصي:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('الاسم: ${profileData['name']}'),
              Text('البريد الإلكتروني: ${profileData['email']}'),
              Text(
                'تاريخ الإنشاء: ${_formatTimestamp(profileData['createdAt'])}',
              ),
              Text(
                'آخر تسجيل دخول: ${_formatTimestamp(profileData['lastLoginAt'])}',
              ),
              Text('متصل: ${profileData['isOnline']}'),
              Text('البريد مؤكد: ${profileData['isEmailVerified']}'),
              Text('الدور: ${profileData['role']}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsList(List errors) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              errors
                  .map(
                    (error) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(error.toString())),
                        ],
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  // Helper method to format timestamp
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'غير متوفر';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
      }
      return 'غير متوفر';
    } catch (e) {
      return 'غير متوفر';
    }
  }
}
