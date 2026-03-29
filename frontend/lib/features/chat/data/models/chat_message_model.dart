import 'package:cloud_firestore/cloud_firestore.dart';

// ChatMessage represents a single message in a conversation.
// It is stored as a document inside chats/{chatId}/messages in Firestore.
class ChatMessage {
  final String id;        // the Firestore document ID of this message
  final String senderId;  // UID of the person who sent this message
  final String text;      // the actual message text
  final DateTime timestamp; // when the message was sent (for ordering)

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  // Reads a Firestore document and creates a ChatMessage from it.
  // We use two timestamp fields to handle a Firestore edge case:
  // when a message is written, the server timestamp may not be available
  // immediately (it shows as null in pending-write state). The client
  // timestamp is set locally, so it's available right away.
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime ts;
    if (data['timestamp'] is Timestamp) {
      ts = (data['timestamp'] as Timestamp).toDate(); // from the Firestore server
    } else if (data['timestampClient'] is Timestamp) {
      ts = (data['timestampClient'] as Timestamp).toDate(); // local fallback
    } else {
      ts = DateTime.now(); // last resort default
    }

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      timestamp: ts,
    );
  }

  // Converts this message to a Map so it can be saved to Firestore.
  // Both timestamps are written — server timestamp for accuracy,
  // client timestamp as a fallback while the server timestamp is pending.
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'timestampClient': Timestamp.fromDate(timestamp),
    };
  }
}
