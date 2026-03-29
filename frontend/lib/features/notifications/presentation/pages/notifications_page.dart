// Firestore, Auth, and Flutter imports
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/notifications/notification_badge.dart';
import 'package:spotit/features/chat/data/models/chat_session_model.dart';
import 'package:spotit/features/chat/domain/repositories/chat_repository.dart';
import 'package:spotit/features/chat/presentation/pages/chat_screen.dart';
import 'package:spotit/features/chat/presentation/widgets/chat_session_card.dart';
import 'package:spotit/main.dart';

// The Notifications page is the "Alerts" tab for citizens.
// It shows two sections:
//   1. Messages — active chat sessions where an official messaged them
//   2. Updates  — activity notifications like status changes, comments, etc.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late ChatRepository _chatRepo;
  String? _currentUserId;
  bool _hasInitialized = false;    // prevents re-running setup on every rebuild
  bool _isLoadingUpdates = true;   // controls the loading spinner in Updates section

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies is used instead of initState because we need
    // access to the widget context to read the ChatRepositoryProvider
    if (!_hasInitialized) {
      _chatRepo = ChatRepositoryProvider.of(context); // get chat data source
      _currentUserId = FirebaseAuth.instance.currentUser?.uid;
      _hasInitialized = true;
      _initializeNotifications();
    }
  }

  // Loads notifications from Firestore via NotificationBadge (the static store)
  Future<void> _initializeNotifications({bool forceRefresh = false}) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _isLoadingUpdates = false);
      return;
    }

    if (mounted) setState(() => _isLoadingUpdates = true);

    // NotificationBadge loads and caches the data — this avoids re-fetching
    // unless forceRefresh is true (triggered by pull-to-refresh)
    await NotificationBadge.initializeForCitizen(
      uid,
      forceRefresh: forceRefresh,
    );
    if (mounted) setState(() => _isLoadingUpdates = false);
  }

  // Navigate to the chat screen for an existing chat session
  void _openChat(ChatSession chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chat.id,
          otherUserName: chat.officialName, // show the official's name in the header
          isOfficial: false, // this is a citizen — they can send messages too
        ),
      ),
    );
  }

  // Opens a chat from a notification card in the Updates section.
  // We need to fetch the chat document first to get the official's name.
  Future<void> _openChatFromNotification(NotificationData item) async {
    if (item.chatId.isEmpty) return; // can't open without a chat ID

    try {
      // Look up the chat in Firestore to get the official's display name
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(item.chatId)
          .get();

      if (!chatDoc.exists || !mounted) return;

      final data = chatDoc.data()!;
      final officialName =
          (data['officialName'] as String?) ?? 'Government Official';

      // Navigate to the chat window so the citizen can read and reply
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: item.chatId,
            otherUserName: officialName,
            isOfficial: false, // citizen mode — can send messages
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to open chat'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header row with title, unread count, and "mark all read" button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ValueListenableBuilder rebuilds only this text when the
                      // unread count changes, not the whole page
                      ValueListenableBuilder<int>(
                        valueListenable: NotificationBadge.unreadCount,
                        builder: (context, count, child) {
                          return Text(
                            '$count unread',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () async {
                      await NotificationBadge.markAllRead();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: Color(0xFFF9A825),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content area — refreshable by pulling down
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _initializeNotifications(forceRefresh: true),
                color: const Color(0xFFF9A825),
                child: ListView(
                  children: [

                    // SECTION 1: Messages
                    // StreamBuilder keeps this list live — when the official sends
                    // a new message, this section updates automatically
                    if (_currentUserId != null)
                      StreamBuilder<List<ChatSession>>(
                        stream: _chatRepo
                            .streamChatSessionsAsCitizen(_currentUserId!),
                        builder: (context, snapshot) {
                          final chats = snapshot.data ?? [];
                          if (chats.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text(
                                  'Messages',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              // Each chat session shown as a tappable card
                              ...chats.map((chat) => ChatSessionCard(
                                    session: chat,
                                    isUnread: !chat.isReadByCitizen,
                                    onTap: () => _openChat(chat), // opens ChatScreen
                                  )),
                              Divider(
                                color: isDark
                                    ? Colors.white.withAlpha(15)
                                    : Colors.black.withAlpha(20),
                                height: 24,
                              ),
                            ],
                          );
                        },
                      ),

                    // SECTION 2: Updates
                    // These come from Firestore users/{uid}/notifications
                    // and include status changes, comment replies, etc.
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        'Updates',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),

                    // ValueListenableBuilder rebuilds when updatesVersion changes
                    // (i.e. after NotificationBadge loads or refreshes data)
                    ValueListenableBuilder<int>(
                      valueListenable: NotificationBadge.updatesVersion,
                      builder: (context, _, __) {
                        final notifications = NotificationBadge.notifications;

                        // Show spinner while loading from Firestore
                        if (_isLoadingUpdates) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFF9A825),
                              ),
                            ),
                          );
                        }

                        // Empty state — shown when there are no notifications yet
                        if (notifications.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            child: Text(
                              'No updates yet. You will see report status changes, new comments, and upvote activity here.',
                              style: TextStyle(
                                fontSize: 13,
                                color: subtitleColor,
                                height: 1.5,
                              ),
                            ),
                          );
                        }

                        // Build one card for each notification
                        return Column(
                          children: notifications.map((item) {
                            final cardBgColor =
                                isDark ? const Color(0xFF1E2124) : Colors.white;
                            final iconBgColor = isDark
                                ? const Color(0xFF2B2D31)
                                : Colors.blueGrey.shade50;

                            // Unread notifications get a gold border, read ones a grey one
                            final borderSide = item.isUnread
                                ? const BorderSide(
                                    color: Color(0xFFF9A825), width: 1.5)
                                : BorderSide(
                                    color: isDark
                                        ? Colors.transparent
                                        : Colors.grey.shade300,
                                    width: 1.0);

                            // Only chat_message notifications are tappable
                            // (they open the actual chat window)
                            final isChatMessage =
                                item.type == 'chat_message' &&
                                    item.chatId.isNotEmpty;

                            return GestureDetector(
                              // Only attach a tap handler if it's a chat notification
                              onTap: isChatMessage
                                  ? () => _openChatFromNotification(item)
                                  : null,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.fromBorderSide(borderSide),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icon on the left side
                                    Container(
                                      padding: const EdgeInsets.all(12.0),
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        color: item.iconColor,
                                        size: 24.0,
                                      ),
                                    ),
                                    const SizedBox(width: 16.0),

                                    // Text content on the right side
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: TextStyle(
                                                    fontSize: 16.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ),
                                              // Gold dot on the right if unread
                                              if (item.isUnread)
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(0xFFF9A825),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6.0),
                                          Text(
                                            item.description,
                                            style: TextStyle(
                                              fontSize: 14.0,
                                              color: subtitleColor,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 12.0),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14.0,
                                                color: subtitleColor,
                                              ),
                                              const SizedBox(width: 4.0),
                                              Text(
                                                NotificationBadge.timeAgo(
                                                    item.createdAt),
                                                style: TextStyle(
                                                  fontSize: 12.0,
                                                  color: subtitleColor,
                                                ),
                                              ),
                                              // For chat messages show a green "Tap to reply" hint
                                              if (isChatMessage) ...[
                                                const Spacer(),
                                                const Icon(
                                                  Icons.reply_rounded,
                                                  size: 14.0,
                                                  color: Color(0xFF2EAA5E),
                                                ),
                                                const SizedBox(width: 4.0),
                                                const Text(
                                                  'Tap to reply',
                                                  style: TextStyle(
                                                    fontSize: 12.0,
                                                    color: Color(0xFF2EAA5E),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
