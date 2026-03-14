import 'package:flutter/material.dart';
import 'package:spotit/features/chat/data/models/chat_session_model.dart';

class ChatSessionCard extends StatelessWidget {
  final ChatSession session;
  final bool isUnread;
  final VoidCallback onTap;

  const ChatSessionCard({
    super.key,
    required this.session,
    required this.isUnread,
    required this.onTap,
  });

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

    final borderSide = isUnread
        ? const BorderSide(color: Color(0xFFF9A825), width: 1.5)
        : BorderSide(
            color: isDark ? Colors.transparent : Colors.grey.shade300,
            width: 1.0,
          );

    return GestureDetector(
      onTap: onTap,
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
            // Icon
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: const Icon(
                Icons.chat_rounded,
                color: Color(0xFFF9A825),
                size: 24.0,
              ),
            ),
            const SizedBox(width: 16.0),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'A Government official has texted you',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
