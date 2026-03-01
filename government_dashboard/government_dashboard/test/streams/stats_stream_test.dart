import 'package:flutter_test/flutter_test.dart';
import 'package:government_dashboard/streams/stats_stream.dart';

void main() {
  group('StatsStream', () {
    late StatsStream statsStream;

    setUp(() {
      statsStream = StatsStream();
    });

    test('should emit initial stats', () async {
      expectLater(statsStream.statsStream, emitsInOrder([
        isA<List<GovernmentStat>>(),
      ]));
    });

    test('should emit updated stats', () async {
      statsStream.updateStats(mockStatsData);
      expectLater(statsStream.statsStream, emitsInOrder([
        isA<List<GovernmentStat>>(),
      ]));
    });
  });
}