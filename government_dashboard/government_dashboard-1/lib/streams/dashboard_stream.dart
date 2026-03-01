import 'dart:async';

import '../models/dashboard_item.dart';

export '../models/dashboard_item.dart';

/// Provides a reactive stream of [DashboardItem] data.
class DashboardStream {
  final _controller = StreamController<List<DashboardItem>>();
  final List<DashboardItem> _items = [];

  DashboardStream() {
    // Emit initial (empty) snapshot so listeners get data immediately.
    _controller.add(List.unmodifiable(_items));
  }

  /// A stream that emits the current list of dashboard items whenever it changes.
  Stream<List<DashboardItem>> get dashboardDataStream => _controller.stream;

  /// Adds a new [DashboardItem] and pushes an updated snapshot to listeners.
  void addDashboardItem(DashboardItem item) {
    _items.add(item);
    _controller.add(List.unmodifiable(_items));
  }

  /// Closes the underlying stream controller.
  void close() {
    _controller.close();
  }
}
