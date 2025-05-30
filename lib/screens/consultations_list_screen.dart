import 'package:flutter/material.dart';
import '../models/consultation.dart';
import '../services/consultation_service.dart';
import '../services/auth_service.dart';

class ConsultationsListScreen extends StatelessWidget {
  const ConsultationsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final consultationService = ConsultationService();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('يجب تسجيل الدخول أولاً'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('استشاراتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/new-consultation');
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Consultation>>(
        stream: consultationService.getUserConsultations(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final consultations = snapshot.data ?? [];

          if (consultations.isEmpty) {
            return const Center(
              child: Text('لا توجد استشارات حالياً'),
            );
          }

          return ListView.builder(
            itemCount: consultations.length,
            itemBuilder: (context, index) {
              final consultation = consultations[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListTile(
                  title: Text(consultation.title),
                  subtitle: Text(
                    consultation.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _buildStatusChip(consultation.status),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/consultation-details',
                      arguments: consultation,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/new-consultation');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'قيد الانتظار';
        break;
      case 'in_progress':
        color = Colors.blue;
        text = 'قيد المعالجة';
        break;
      case 'completed':
        color = Colors.green;
        text = 'مكتملة';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Chip(
      label: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }
} 