import 'package:flutter/material.dart';
import 'package:spotit/features/chat/data/models/chat_message_model.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatBubble({super.key, required this.message, required this.isMe});

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

    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF2E7D32) : const Color(0xFF2EAA5E))
        : (isDark ? const Color(0xFF1E2124) : Colors.grey.shade200);

    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    final timeColor = isMe
        ? Colors.white.withAlpha(179)
        : (isDark ? Colors.grey[400] : Colors.grey[600]);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          left: isMe ? 56 : 16,
          right: isMe ? 16 : 56,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeAgo(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: timeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
