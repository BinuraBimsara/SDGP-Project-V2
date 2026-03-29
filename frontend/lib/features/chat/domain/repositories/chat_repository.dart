import 'package:spotit/features/chat/data/models/chat_session_model.dart';
import 'package:spotit/features/chat/data/models/chat_message_model.dart';

// ChatRepository is an abstract interface (like a contract).
// It defines WHAT operations our chat feature needs, but not HOW they work.
// The actual implementation is in FirestoreChatRepository.
//
// Why use an interface? If we ever switch databases (e.g. from Firestore to
// a REST API), we just write a new class that implements this interface and
// swap it in main.dart — without changing any UI code.
abstract class ChatRepository {

  // Gets an existing chat between a citizen and an official about one complaint.
  // If no chat exists yet, creates one.
  // The chatId is constructed as officialId_citizenId_complaintId so it's always unique per pair.
  Future<ChatSession> getOrCreateChat({
    required String officialId,
    required String citizenId,
    required String complaintId,
    required String officialName,
    required String citizenName,
  });

  // Returns a real-time stream of the official's chat sessions.
  // Each time a new message is sent or a chat is created, the list updates automatically.
  Stream<List<ChatSession>> streamChatSessionsAsOfficial(String officialId);

  // Returns a real-time stream of the citizen's chat sessions
  Stream<List<ChatSession>> streamChatSessionsAsCitizen(String citizenId);

  // Returns a real-time stream of messages in a specific chat.
  // Ordered oldest first so the conversation reads naturally (like WhatsApp).
  Stream<List<ChatMessage>> streamMessages(String chatId);

  // Writes a new message to Firestore and updates the chat's lastMessage preview.
  // isOfficialSender is used to set the correct read flags on the chat document.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required bool isOfficialSender,
  });

  // Called when the citizen opens a chat — clears their unread badge
  Future<void> markReadByCitizen(String chatId);

  // Called when the official opens a chat — clears their unread badge
  Future<void> markReadByOfficial(String chatId);

  // Emits the number of chats that have unread messages for a citizen.
  // The nav tab badge listens to this stream and updates in real-time.
  Stream<int> streamUnreadCountForCitizen(String citizenId);

  // Same thing but for the government official side
  Stream<int> streamUnreadCountForOfficial(String officialId);
}
