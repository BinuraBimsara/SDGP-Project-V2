import 'package:flutter_test/flutter_test.dart';
import 'package:government_dashboard/streams/dashboard_stream.dart';

void main() {
  group('DashboardStream', () {
    late DashboardStream dashboardStream;

    setUp(() {
      dashboardStream = DashboardStream();
    });

    test('should emit initial data', () {
      expectLater(dashboardStream.dashboardDataStream, emitsInOrder([
        isA<List<DashboardItem>>(),
      ]));
    });

    test('should emit updated data when new data is added', () async {
      dashboardStream.addDashboardItem(DashboardItem(id: '1', title: 'Test Item', value: 100));
      expectLater(dashboardStream.dashboardDataStream, emitsInOrder([
        isA<List<DashboardItem>>(),
      ]));
    });

    tearDown(() {
      dashboardStream.close();
    });
  });
}