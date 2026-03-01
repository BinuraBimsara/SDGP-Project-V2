import 'package:flutter_test/flutter_test.dart';
import 'package:government_dashboard/pages/home_page.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Home Page has a title and a list of reports', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HomePage()));

    // Verify if the title is present
    expect(find.text('Home'), findsOneWidget);

    // Verify if the report list is present
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('Home Page has voting buttons for reports', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HomePage()));

    // Assuming there are voting buttons in the report list
    expect(find.byIcon(Icons.thumb_up), findsWidgets);
    expect(find.byIcon(Icons.thumb_down), findsWidgets);
  });
}