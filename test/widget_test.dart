import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stuttgart_network/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Загружаем приложение
    await tester.pumpWidget(const KJMCApp());

    // Проверяем, что на старте нет ошибок и интерфейс загружен
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
