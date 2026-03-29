import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:spotit/features/chat/data/repositories/firestore_chat_repository.dart';

// NotificationBadge is a static class (like a singleton) that holds all
// notification state for the app. It is not a widget — it's a data store
// that any widget can read from using NotificationBadge.unreadCount etc.
//
// It handles two types of notifications for citizens:
//   1. Chat notifications — from unread messages in the chats collection
//   2. Activity notifications — from users/{uid}/notifications in Firestore
//      (e.g. complaint status changed, new comment)
class NotificationBadge {
  // Private constructor prevents anyone from creating an instance
  NotificationBadge._();

  // ValueNotifier lets widgets rebuild automatically when this value changes.
  // unreadCount = chat unread + activity unread combined
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  // Incrementing this number tells ValueListenableBuilder to rebuild the list
  static final ValueNotifier<int> updatesVersion = ValueNotifier<int>(0);

  // Separate counters so we can update either without losing the other
  static int _staticUnreadCount = 0; // unread activity notifications
  static int _chatUnreadCount = 0;   // unread chat messages

  static String? _activeCitizenUid;    // the UID of the citizen currently using the app
  static bool _isCitizenLoading = false;     // prevents double-loading
  static bool _isCitizenInitialized = false; // tracks if we already loaded

  // Holds the active Firestore stream subscription for chat unread counts
  static StreamSubscription<int>? _chatUnreadSub;

  // The list of notification items shown on the Notifications page
  static final List<NotificationData> notifications = [];

  // Called when a citizen logs in. Starts listening to how many unread
  // chat messages they have, and kicks off loading their notifications.
  static void startChatUnreadListener(String userId) {
    initializeForCitizen(userId); // load Firestore notifications

    _chatUnreadSub?.cancel(); // cancel any previous listener first
    final chatRepo = FirestoreChatRepository();

    // Stream that emits a new count every time an unread chat changes
    _chatUnreadSub =
        chatRepo.streamUnreadCountForCitizen(userId).listen((count) {
      _chatUnreadCount = count;
      // Update the badge total so the nav bar icon badge refreshes
      unreadCount.value = _staticUnreadCount + _chatUnreadCount;
    });
  }

  // Same concept but for government officials — listens to their chat unread count
  static void startOfficialChatUnreadListener(String userId) {
    _chatUnreadSub?.cancel();
    final chatRepo = FirestoreChatRepository();

    _chatUnreadSub =
        chatRepo.streamUnreadCountForOfficial(userId).listen((count) {
      _chatUnreadCount = count;
      unreadCount.value = _staticUnreadCount + _chatUnreadCount;
    });
  }

  // Stop listening — called when the user logs out or the home page is disposed
  static void stopChatUnreadListener() {
    _chatUnreadSub?.cancel();
    _chatUnreadSub = null;
  }

  // Loads the citizen's activity notifications from Firestore into memory.
  // forceRefresh = true will reload even if we already loaded before (used on pull-to-refresh)
  static Future<void> initializeForCitizen(
    String userId, {
    bool forceRefresh = false,
  }) async {
    // Don't load if we're already loading
    if (_isCitizenLoading) return;

    // Don't reload if these are already loaded for the same user, unless forced
    if (!forceRefresh && _isCitizenInitialized && _activeCitizenUid == userId) {
      return;
    }

    _isCitizenLoading = true;
    _activeCitizenUid = userId;

    try {
      // Fetch the most recent 100 notifications from Firestore
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true) // newest first
          .limit(100)
          .get();

      // Convert each Firestore document into a NotificationData object
      final loaded = snap.docs.map((doc) {
        final data = doc.data();
        final title = (data['title'] as String?) ?? 'Notification';
        final body = (data['body'] as String?) ?? '';
        final type = (data['type'] as String?) ?? '';       // e.g. 'chat_message'
        final chatId = (data['chatId'] as String?) ?? '';   // which chat to open
        final complaintId = (data['complaintId'] as String?) ?? '';

        // Choose the icon and colour based on what kind of notification this is
        IconData icon = Icons.notifications_none_rounded; // default icon
        Color iconColor = const Color(0xFFF9A825);         // default orange

        if (type == 'chat_message') {
          icon = Icons.chat_rounded;           // green chat icon for messages
          iconColor = const Color(0xFF2EAA5E);
        } else if (title.toLowerCase().contains('status')) {
          icon = Icons.check_circle_outline;   // checkmark for status updates
        } else if (title.toLowerCase().contains('comment')) {
          icon = Icons.chat_bubble_outline;    // speech bubble for comments
        } else if (title.toLowerCase().contains('upvote')) {
          icon = Icons.arrow_upward;           // arrow for upvote activity
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
          isUnread: !isRead, // flip the flag — unread means read == false
          type: type,
          chatId: chatId,
          complaintId: complaintId,
        );
      }).toList();

      // Replace the old list with the freshly loaded one
      notifications
        ..clear()
        ..addAll(loaded);

      // Count how many are unread and update the badge
      _staticUnreadCount = notifications.where((n) => n.isUnread).length;
      unreadCount.value = _staticUnreadCount + _chatUnreadCount;

      // Increment version so any ValueListenableBuilder showing the list rebuilds
      updatesVersion.value++;
      _isCitizenInitialized = true;
    } finally {
      // Always clear the loading flag even if something went wrong above
      _isCitizenLoading = false;
    }
  }

  // Convenience method for triggering a forced reload
  static Future<void> refreshCitizenNotifications(String userId) {
    return initializeForCitizen(userId, forceRefresh: true);
  }

  // Marks every notification as read — both in memory and in Firestore via Cloud Functions
  static Future<void> markAllRead() async {
    final uid = _activeCitizenUid;

    // If no UID is set, just clear locally without a Firestore call
    if (uid == null || uid.isEmpty) {
      for (final n in notifications) {
        n.isUnread = false;
      }
      _staticUnreadCount = 0;
      unreadCount.value = _chatUnreadCount;
      updatesVersion.value++;
      return;
    }

    // Call the Cloud Function that marks all notifications as read in Firestore
    final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('markAllNotificationsRead');
    await callable.call({'limit': 500}); // up to 500 notifications at once

    // Also update locally so the UI reflects the change straight away
    for (final n in notifications) {
      n.isUnread = false;
    }
    _staticUnreadCount = 0;
    unreadCount.value = _chatUnreadCount; // chat unread count stays the same
    updatesVersion.value++;
  }

  // Helper to safely convert Firestore Timestamp, DateTime, or String to DateTime
  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate(); // Firestore timestamp
    if (value is DateTime) return value;           // already a DateTime
    if (value is String) return DateTime.tryParse(value); // ISO string
    return null;
  }

  // Returns a human-friendly string like "5m ago" or "2d ago"
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}'; // for older notifications
  }
}

// A single notification item — holds all the data needed to display one card
// on the Notifications page and decide what happens when it's tapped
class NotificationData {
  final String id;          // Firestore document ID
  final IconData icon;      // the icon shown on the card
  final Color iconColor;    // the icon's colour
  final String title;       // e.g. "Message from John"
  final String description; // e.g. "Your complaint has been resolved"
  final DateTime createdAt; // when the notification was created
  bool isUnread;            // mutable — changes when user marks as read

  // Tells us what kind of notification this is so we know how to handle taps
  final String type; // 'chat_message', 'new_complaint', etc.

  // Only set for chat_message type — the ID of the chat to open when tapped
  final String chatId;

  // The complaint this notification relates to
  final String complaintId;

  NotificationData({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.createdAt,
    this.isUnread = false,
    this.type = '',
    this.chatId = '',
    this.complaintId = '',
  });
}
