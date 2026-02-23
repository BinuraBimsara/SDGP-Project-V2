import 'package:flutter_test/flutter_test.dart';
import 'package:spotit/features/complaints/data/repositories/dummy_complaint_repository.dart';
import 'package:spotit/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(SpotItApp(repository: DummyComplaintRepository()));
    expect(find.text('SpotIT'), findsOneWidget);
  });
}
