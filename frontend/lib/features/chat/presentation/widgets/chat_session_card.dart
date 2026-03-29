import 'package:flutter/material.dart';
import 'package:spotit/features/chat/data/models/chat_session_model.dart';

// A card widget that represents one chat conversation in the Notifications page.
// It shows the official's name, the last message preview, the time, and
// a green "Tap to reply" hint to make it clear citizens can respond.
class ChatSessionCard extends StatelessWidget {
  final ChatSession session;  // the chat data to display
  final bool isUnread;        // true if there are messages the user hasn't seen yet
  final VoidCallback onTap;   // called when the user taps the card

  const ChatSessionCard({
    super.key,
    required this.session,
    required this.isUnread,
    required this.onTap,
  });

  // Returns a short time string like "5m ago" or "3d ago"
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBgColor = isDark ? const Color(0xFF1E2124) : Colors.white;
    final iconBgColor =
        isDark ? const Color(0xFF2B2D31) : Colors.blueGrey.shade50;

    // Unread chats get a gold border to grab the user's attention
    final borderSide = isUnread
        ? const BorderSide(color: Color(0xFFF9A825), width: 1.5)
        : BorderSide(
            color: isDark ? Colors.transparent : Colors.grey.shade300,
            width: 1.0,
          );

    // Show the official's actual name, falling back to a generic label
    final displayName = session.officialName.isNotEmpty
        ? session.officialName
        : 'Government Official';

    return GestureDetector(
      onTap: onTap, // opens the ChatScreen when tapped
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.fromBorderSide(borderSide),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chat icon on the left
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: const Icon(
                Icons.chat_rounded,
                color: Color(0xFFF9A825), // gold
                size: 24.0,
              ),
            ),
            const SizedBox(width: 16.0),

            // Right side: name, message preview, time, and "Tap to reply"
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Message from $displayName',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Dot indicator — only shown when there are unread messages
                      if (isUnread)
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

                  // Last message preview (truncated to 2 lines)
                  if (session.lastMessage.isNotEmpty)
                    Text(
                      session.lastMessage,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: subtitleColor,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12.0),

                  Row(
                    children: [
                      // Time since last message
                      Icon(
                        Icons.access_time,
                        size: 14.0,
                        color: subtitleColor,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        _timeAgo(session.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12.0,
                          color: subtitleColor,
                        ),
                      ),
                      const Spacer(),

                      // Green "Tap to reply" hint — makes it clear the card is interactive
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
