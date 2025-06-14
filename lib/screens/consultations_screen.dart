import 'package:flutter/material.dart';

class ConsultationsScreen extends StatelessWidget {
  const ConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاستشارات')),
      body: const Center(child: Text('قائمة الاستشارات')),
    );
  }
}
