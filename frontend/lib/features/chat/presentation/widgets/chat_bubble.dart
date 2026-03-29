import 'package:flutter/material.dart';
import 'package:spotit/features/chat/data/models/chat_message_model.dart';

// ChatBubble renders a single message in the conversation.
// It looks like a WhatsApp bubble — aligns right if it's your message,
// left if it's the other person's message.
class ChatBubble extends StatelessWidget {
  final ChatMessage message; // the message data to display
  final bool isMe;           // true if the current user sent this message

  const ChatBubble({super.key, required this.message, required this.isMe});

  // Returns a short human-friendly time label like "3m ago", "2h ago", "1d ago"
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}'; // show full date for old messages
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // My messages are green; the other person's are grey
    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF2E7D32) : const Color(0xFF2EAA5E)) // green
        : (isDark ? const Color(0xFF1E2124) : Colors.grey.shade200);   // grey

    // My messages always have white text; other person's text adapts to theme
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    // The timestamp is slightly faded compared to the message text
    final timeColor = isMe
        ? Colors.white.withAlpha(179)                   // semi-transparent white
        : (isDark ? Colors.grey[400] : Colors.grey[600]); // grey

    return Align(
      // My messages sit on the right, incoming messages on the left
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        // Cap bubble width at 75% of screen — very long messages don't stretch full width
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          left: isMe ? 56 : 16,   // my message has more left margin (pushed right)
          right: isMe ? 16 : 56,  // other message has more right margin (pushed left)
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          // Classic chat bubble shape: rounded on 3 corners, flat on the tail corner
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)  // my bubble: bottom-left fully rounded
                : const Radius.circular(4),  // their bubble: bottom-left slightly flat (the tail)
            bottomRight: isMe
                ? const Radius.circular(4)   // my bubble: bottom-right slightly flat (the tail)
                : const Radius.circular(16), // their bubble: bottom-right fully rounded
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end, // timestamp aligns to the right
          children: [
            // The message text itself
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
                height: 1.4, // 1.4 line height for readability
              ),
            ),
            const SizedBox(height: 4),
            // Small timestamp below the message
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
