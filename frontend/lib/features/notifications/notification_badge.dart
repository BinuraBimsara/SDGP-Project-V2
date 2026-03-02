import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Holds the shared notification data and unread count.
/// Data lives here (not in the page state) so it survives tab switches.
class NotificationBadge {
  NotificationBadge._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
}
