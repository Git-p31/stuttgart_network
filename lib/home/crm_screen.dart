import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showCrmComingSoon(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((0.7 * 255).toInt()), // полупрозрачный фон
      builder: (context) {
        return Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black.withAlpha((0.8 * 255).toInt()),
            ),
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Colors.white.withAlpha((0.9 * 255).toInt()),
                ),
                const SizedBox(height: 24),
                Text(
                  'Раздел в разработке',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withAlpha((0.95 * 255).toInt()),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Скоро здесь появится CRM-система для управления участниками и служениями.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withAlpha((0.7 * 255).toInt()),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Главный экран')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _showCrmComingSoon(context),
          child: const Text('CRM'),
        ),
      ),
    );
  }
}
