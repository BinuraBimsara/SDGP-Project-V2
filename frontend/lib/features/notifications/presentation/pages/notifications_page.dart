import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotit/features/notifications/notification_badge.dart';
import 'package:spotit/features/chat/data/models/chat_session_model.dart';
import 'package:spotit/features/chat/domain/repositories/chat_repository.dart';
import 'package:spotit/features/chat/presentation/pages/chat_screen.dart';
import 'package:spotit/features/chat/presentation/widgets/chat_session_card.dart';
import 'package:spotit/main.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late ChatRepository _chatRepo;
  String? _currentUserId;
  bool _hasInitialized = false;
  bool _isLoadingUpdates = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _chatRepo = ChatRepositoryProvider.of(context);
      _currentUserId = FirebaseAuth.instance.currentUser?.uid;
      _hasInitialized = true;
      _initializeNotifications();
    }
  }

  Future<void> _initializeNotifications({bool forceRefresh = false}) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _isLoadingUpdates = false);
      return;
    }

    if (mounted) setState(() => _isLoadingUpdates = true);
    await NotificationBadge.initializeForCitizen(
      uid,
      forceRefresh: forceRefresh,
    );
    if (mounted) setState(() => _isLoadingUpdates = false);
  }

  void _openChat(ChatSession chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chat.id,
          otherUserName: chat.officialName,
          isOfficial: false,
        ),
      ),
    );
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
            // Header Section
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
            // Content
            Expanded(
              child: ListView(
                children: [
                  // Chat messages section
                  if (_currentUserId != null)
                    StreamBuilder<List<ChatSession>>(
                      stream:
                          _chatRepo.streamChatSessionsAsCitizen(_currentUserId!),
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
                            ...chats.map((chat) => ChatSessionCard(
                                  session: chat,
                                  isUnread: !chat.isReadByCitizen,
                                  onTap: () => _openChat(chat),
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
                  // Existing static notifications
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Updates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: NotificationBadge.unreadCount,
                    builder: (context, _, __) {
                      final notifications = NotificationBadge.notifications;
                      return Column(
                        children: notifications.map((item) {
                          final cardBgColor =
                              isDark ? const Color(0xFF1E2124) : Colors.white;
                          final iconBgColor = isDark
                              ? const Color(0xFF2B2D31)
                              : Colors.blueGrey.shade50;
                          final borderSide = item.isUnread
                              ? const BorderSide(
                                  color: Color(0xFFF9A825), width: 1.5)
                              : BorderSide(
                                  color: isDark
                                      ? Colors.transparent
                                      : Colors.grey.shade300,
                                  width: 1.0);

                          return Container(
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
                                    color:
                                        Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: item.iconColor,
                                    size: 24.0,
                                  ),
                                ),
                                const SizedBox(width: 16.0),
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
                                          if (item.isUnread)
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: const BoxDecoration(
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
                                            item.time,
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              color: subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
