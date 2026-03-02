import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Holds the shared notification data and unread count.
/// Data lives here (not in the page state) so it survives tab switches.
class NotificationBadge {
  NotificationBadge._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(2);

  /// The canonical list of notifications — shared across rebuilds.
  static final List<NotificationData> notifications = [
    NotificationData(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFFF9A825),
      title: 'Report Status Updated',
      description:
          'Your report "Large pothole on Main Street" has been marked as In Progress',
      time: '1h ago',
      isUnread: true,
    ),
    NotificationData(
      icon: Icons.chat_bubble_outline,
      iconColor: const Color(0xFFFFCA28),
      title: 'New Comment',
      description: 'A government official commented on your report',
      time: '2h ago',
      isUnread: true,
    ),
    NotificationData(
      icon: Icons.arrow_upward,
      iconColor: const Color(0xFFF9A825),
      title: 'Report Upvoted',
      description: 'Your report received 5 new upvotes',
      time: '1d ago',
      isUnread: false,
    ),
  ];

  static void markAllRead() {
    for (final n in notifications) {
      n.isUnread = false;
    }
    unreadCount.value = 0;
  }
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
