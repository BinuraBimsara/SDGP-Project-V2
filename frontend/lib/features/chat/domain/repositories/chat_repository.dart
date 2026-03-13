import 'package:spotit/features/chat/data/models/chat_session_model.dart';
import 'package:spotit/features/chat/data/models/chat_message_model.dart';

abstract class ChatRepository {
  /// Find existing chat between official and citizen for a complaint,
  /// or create a new one.
  Future<ChatSession> getOrCreateChat({
    required String officialId,
    required String citizenId,
    required String complaintId,
    required String officialName,
    required String citizenName,
  });

  /// Stream all chat sessions where the user is the official.
  Stream<List<ChatSession>> streamChatSessionsAsOfficial(String officialId);

  /// Stream all chat sessions where the user is the citizen.
  Stream<List<ChatSession>> streamChatSessionsAsCitizen(String citizenId);

  /// Stream all messages in a chat, ordered by timestamp ascending.
  Stream<List<ChatMessage>> streamMessages(String chatId);

  /// Send a message to a chat. Updates lastMessage/lastMessageTime on the session.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  });

  /// Mark a chat as read by the citizen.
  Future<void> markReadByCitizen(String chatId);

  /// Mark a chat as read by the official.
  Future<void> markReadByOfficial(String chatId);

  /// Stream the count of unread chats for a citizen.
  Stream<int> streamUnreadCountForCitizen(String citizenId);

  /// Stream the count of unread chats for an official.
  Stream<int> streamUnreadCountForOfficial(String officialId);
}
