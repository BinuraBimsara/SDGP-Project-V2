import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/chat/data/models/chat_session_model.dart';
import 'package:spotit/features/chat/data/models/chat_message_model.dart';
import 'package:spotit/features/chat/domain/repositories/chat_repository.dart';

// This class connects to Firestore and carries out all chat-related database work.
// It implements the ChatRepository interface, which defines what operations are available.
// Using an interface means we could swap this out for a different data source
// (e.g. a local mock) without changing any UI code.
class FirestoreChatRepository implements ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Shortcut to the 'chats' collection in Firestore
  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _firestore.collection('chats');

  // Gets an existing chat session between a specific official and citizen for a complaint,
  // or creates a new one if it doesn't exist yet.
  // The chat ID is deterministic (always the same for the same 3 participants),
  // so two officials can't accidentally create duplicate chats with the same citizen.
  @override
  Future<ChatSession> getOrCreateChat({
    required String officialId,
    required String citizenId,
    required String complaintId,
    required String officialName,
    required String citizenName,
  }) async {
    // Build a predictable document ID from the three participants
    final chatId = '${officialId}_${citizenId}_$complaintId';
    final docRef = _chatsRef.doc(chatId);
    final doc = await docRef.get();

    // If the chat already exists, just return it without creating a duplicate
    if (doc.exists) {
      return ChatSession.fromFirestore(doc);
    }

    // Create a new chat session document in Firestore
    final now = DateTime.now();
    final session = ChatSession(
      id: chatId,
      officialId: officialId,
      citizenId: citizenId,
      complaintId: complaintId,
      officialName: officialName,
      citizenName: citizenName,
      lastMessage: '',         // no messages yet
      lastMessageTime: now,
      isReadByCitizen: false,  // citizen hasn't opened the chat yet
      isReadByOfficial: true,  // official just created it so they've "seen" it
    );

    await docRef.set(session.toFirestore());
    final snap = await docRef.get(); // re-fetch to get the server timestamp
    return ChatSession.fromFirestore(snap);
  }

  // Returns a live stream of all chat sessions where this user is the official.
  // The stream updates automatically when new chats are created or messages are sent.
  @override
  Stream<List<ChatSession>> streamChatSessionsAsOfficial(String officialId) {
    return _chatsRef
        .where('officialId', isEqualTo: officialId) // filter to this official's chats
        .orderBy('lastMessageTime', descending: true) // newest chat at the top
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatSession.fromFirestore(d)).toList());
  }

  // Returns a live stream of all chat sessions where this user is the citizen
  @override
  Stream<List<ChatSession>> streamChatSessionsAsCitizen(String citizenId) {
    return _chatsRef
        .where('citizenId', isEqualTo: citizenId) // filter to this citizen's chats
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatSession.fromFirestore(d)).toList());
  }

  // Returns a live stream of all messages in a specific chat, ordered oldest first.
  // This is what the ChatScreen uses to show the conversation.
  @override
  Stream<List<ChatMessage>> streamMessages(String chatId) {
    return _chatsRef
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // oldest first so the conversation reads naturally
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  // Sends a message by writing it to Firestore.
  // Uses a batch write to do two things atomically (both succeed or both fail):
  //   1. Add the message document under chats/{chatId}/messages
  //   2. Update lastMessage and read status on the parent chat document
  @override
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required bool isOfficialSender,
  }) async {
    final batch = _firestore.batch();
    final chatDoc = _chatsRef.doc(chatId);
    final msgRef = chatDoc.collection('messages').doc(); // auto-generated ID

    // Client timestamp is used for immediate ordering before server responds
    final clientTs = Timestamp.now();

    // Write the message document
    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(), // authoritative server time
      'timestampClient': clientTs,               // fallback for immediate display
    });

    // Update the parent chat with the latest message and mark unread for the other side
    final updateData = <String, dynamic>{
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageTimeClient': clientTs,
    };

    if (isOfficialSender) {
      // Official sent the message — citizen hasn't read it yet
      updateData['isReadByCitizen'] = false;
      updateData['isReadByOfficial'] = true;
    } else {
      // Citizen sent the message — official hasn't read it yet
      updateData['isReadByOfficial'] = false;
      updateData['isReadByCitizen'] = true;
    }

    batch.update(chatDoc, updateData);
    await batch.commit(); // execute both writes together
  }

  // Called when the citizen opens a chat — marks it as read on their side
  @override
  Future<void> markReadByCitizen(String chatId) =>
      _chatsRef.doc(chatId).update({'isReadByCitizen': true});

  // Called when the official opens a chat — marks it as read on their side
  @override
  Future<void> markReadByOfficial(String chatId) =>
      _chatsRef.doc(chatId).update({'isReadByOfficial': true});

  // Returns a live count of how many chats the citizen hasn't opened yet.
  // Used to show the red badge number on the Alerts nav tab.
  @override
  Stream<int> streamUnreadCountForCitizen(String citizenId) {
    return _chatsRef
        .where('citizenId', isEqualTo: citizenId)
        .where('isReadByCitizen', isEqualTo: false) // only unread ones
        .snapshots()
        .map((snap) => snap.docs.length); // count is just how many documents match
  }

  // Same but for officials — counts their unread chats
  @override
  Stream<int> streamUnreadCountForOfficial(String officialId) {
    return _chatsRef
        .where('officialId', isEqualTo: officialId)
        .where('isReadByOfficial', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
