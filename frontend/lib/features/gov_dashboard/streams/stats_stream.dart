import 'dart:async';

import '../models/government_stat.dart';

export '../models/government_stat.dart';
export '../data/mock_stats_data.dart';

/// Provides a reactive stream of [GovernmentStat] data.
class StatsStream {
  final _controller = StreamController<List<GovernmentStat>>();
  List<GovernmentStat> _stats = [];

  StatsStream() {
    // Emit initial (empty) snapshot.
    _controller.add(List.unmodifiable(_stats));
  }

  /// A stream that emits the current list of government stats.
  Stream<List<GovernmentStat>> get statsStream => _controller.stream;

  /// Replaces the current stats with [newStats] and pushes an update.
  void updateStats(List<GovernmentStat> newStats) {
    _stats = List<GovernmentStat>.from(newStats);
    _controller.add(List.unmodifiable(_stats));
  }

  /// Closes the underlying stream controller.
  void close() {
    _controller.close();
  }
}
