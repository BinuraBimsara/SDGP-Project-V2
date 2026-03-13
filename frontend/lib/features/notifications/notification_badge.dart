import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spotit/features/chat/data/repositories/firestore_chat_repository.dart';

/// Holds the shared notification data and unread count.
/// Data lives here (not in the page state) so it survives tab switches.
class NotificationBadge {
  NotificationBadge._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(2);

  static int _staticUnreadCount = 2;
  static int _chatUnreadCount = 0;

  static StreamSubscription<int>? _chatUnreadSub;

  /// Start listening for chat unread counts (for citizens).
  static void startChatUnreadListener(String userId) {
    _chatUnreadSub?.cancel();
    final chatRepo = FirestoreChatRepository();
    _chatUnreadSub =
        chatRepo.streamUnreadCountForCitizen(userId).listen((count) {
      _chatUnreadCount = count;
      unreadCount.value = _staticUnreadCount + _chatUnreadCount;
    });
  }

  /// Start listening for chat unread counts (for officials).
  static void startOfficialChatUnreadListener(String userId) {
    _chatUnreadSub?.cancel();
    final chatRepo = FirestoreChatRepository();
    _chatUnreadSub =
        chatRepo.streamUnreadCountForOfficial(userId).listen((count) {
      _chatUnreadCount = count;
      unreadCount.value = _staticUnreadCount + _chatUnreadCount;
    });
  }

  /// Stop the chat unread listener.
  static void stopChatUnreadListener() {
    _chatUnreadSub?.cancel();
    _chatUnreadSub = null;
  }

  /// The canonical list of notifications -- shared across rebuilds.
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
    _staticUnreadCount = 0;
    unreadCount.value = _chatUnreadCount;
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
