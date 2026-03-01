import 'package:flutter_test/flutter_test.dart';
import 'package:government_dashboard/pages/admin_dashboard_page.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Admin Dashboard Page has a title and a list of complaints', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: AdminDashboardPage()));

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('Admin Dashboard Page displays complaint items', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: AdminDashboardPage()));

    // Assuming the mock data is set up to show at least one complaint
    expect(find.byType(ListTile), findsWidgets);
  });
}