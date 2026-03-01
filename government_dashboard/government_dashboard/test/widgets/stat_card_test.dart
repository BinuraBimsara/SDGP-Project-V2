import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:government_dashboard/widgets/stat_card.dart';

void main() {
  testWidgets('StatCard displays correct data', (WidgetTester tester) async {
    // Arrange
    final statCard = StatCard(
      title: 'Total Reports',
      value: 150,
      icon: Icons.report,
    );

    // Act
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: statCard)));

    // Assert
    expect(find.text('Total Reports'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.byIcon(Icons.report), findsOneWidget);
  });

  testWidgets('StatCard displays empty value', (WidgetTester tester) async {
    // Arrange
    final statCard = StatCard(
      title: 'Pending Reports',
      value: 0,
      icon: Icons.pending,
    );

    // Act
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: statCard)));

    // Assert
    expect(find.text('Pending Reports'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(Icons.pending), findsOneWidget);
  });
}