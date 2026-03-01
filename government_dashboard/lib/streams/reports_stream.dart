import 'dart:async';

import '../models/citizen_report.dart';

export '../models/citizen_report.dart';

/// Provides a reactive stream of [CitizenReport] data.
class ReportsStream {
  final _controller = StreamController<List<CitizenReport>>();
  final List<CitizenReport> _reports = [];

  ReportsStream() {
    _controller.add(List.unmodifiable(_reports));
  }

  /// A stream that emits the current list of citizen reports.
  Stream<List<CitizenReport>> get reportsStream => _controller.stream;

  /// Adds a new [CitizenReport] and pushes an updated snapshot.
  void addReport(CitizenReport report) {
    _reports.add(report);
    _controller.add(List.unmodifiable(_reports));
  }

  /// Closes the underlying stream controller.
  void close() {
    _controller.close();
  }
}
