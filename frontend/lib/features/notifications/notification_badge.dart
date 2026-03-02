import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Holds the shared notification data and unread count.
/// Data lives here (not in the page state) so it survives tab switches.
class NotificationBadge {
  NotificationBadge._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
}

class NotificationData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String time;
  bool isUnread;

  NotificationData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.time,
    this.isUnread = false,
  });
}
