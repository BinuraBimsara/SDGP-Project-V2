import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:spotit/features/chat/data/repositories/firestore_chat_repository.dart';

/// Shared notification store used by nav badges and the notifications page.
///
/// Citizen update notifications are read from:
/// `users/{uid}/notifications`
class NotificationBadge {
  NotificationBadge._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> updatesVersion = ValueNotifier<int>(0);

  static int _staticUnreadCount = 0;
  static int _chatUnreadCount = 0;
  static String? _activeCitizenUid;
  static bool _isCitizenLoading = false;
  static bool _isCitizenInitialized = false;

  static StreamSubscription<int>? _chatUnreadSub;

  static final List<NotificationData> notifications = [];

  /// Start listening for chat unread counts (for citizens).
  static void startChatUnreadListener(String userId) {
    initializeForCitizen(userId);

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

  static Future<void> initializeForCitizen(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (_isCitizenLoading) return;
    if (!forceRefresh && _isCitizenInitialized && _activeCitizenUid == userId) {
      return;
    }

    _isCitizenLoading = true;
    _activeCitizenUid = userId;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final loaded = snap.docs.map((doc) {
        final data = doc.data();
        final title = (data['title'] as String?) ?? 'Notification';
        final body = (data['body'] as String?) ?? '';

        IconData icon = Icons.notifications_none_rounded;
        Color iconColor = const Color(0xFFF9A825);
        if (title.toLowerCase().contains('status')) {
          icon = Icons.check_circle_outline;
        } else if (title.toLowerCase().contains('comment')) {
          icon = Icons.chat_bubble_outline;
        } else if (title.toLowerCase().contains('upvote')) {
          icon = Icons.arrow_upward;
        }

        final createdAt = _asDateTime(data['createdAt']) ?? DateTime.now();
        final isRead = (data['read'] as bool?) ?? false;

        return NotificationData(
          id: doc.id,
          icon: icon,
          iconColor: iconColor,
          title: title,
          description: body,
          createdAt: createdAt,
          isUnread: !isRead,
        );
      }).toList();

      notifications
        ..clear()
        ..addAll(loaded);

      _staticUnreadCount = notifications.where((n) => n.isUnread).length;
      unreadCount.value = _staticUnreadCount + _chatUnreadCount;
      updatesVersion.value++;
      _isCitizenInitialized = true;
    } finally {
      _isCitizenLoading = false;
    }
  }

  static Future<void> refreshCitizenNotifications(String userId) {
    return initializeForCitizen(userId, forceRefresh: true);
  }

  static Future<void> markAllRead() async {
    final uid = _activeCitizenUid;
    if (uid == null || uid.isEmpty) {
      for (final n in notifications) {
        n.isUnread = false;
      }
      _staticUnreadCount = 0;
      unreadCount.value = _chatUnreadCount;
      updatesVersion.value++;
      return;
    }

    final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('markAllNotificationsRead');
    await callable.call({'limit': 500});

    for (final n in notifications) {
      n.isUnread = false;
    }
    _staticUnreadCount = 0;
    unreadCount.value = _chatUnreadCount;
    updatesVersion.value++;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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
