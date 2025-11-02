import 'package:flutter/material.dart';

class CrmScreen extends StatelessWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🛑 УБРАЛИ Scaffold и AppBar
    return const Center(
      child: Text('Здесь будет список профилей (CRM)'),
    );
  }
}