import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/chat/data/models/chat_session_model.dart';
import 'package:spotit/features/chat/data/models/chat_message_model.dart';
import 'package:spotit/features/chat/domain/repositories/chat_repository.dart';

class FirestoreChatRepository implements ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _firestore.collection('chats');

  @override
  Future<ChatSession> getOrCreateChat({
    required String officialId,
    required String citizenId,
    required String complaintId,
    required String officialName,
    required String citizenName,
  }) async {
    // Deterministic doc ID prevents duplicate sessions.
    final chatId = '${officialId}_${citizenId}_$complaintId';
    final docRef = _chatsRef.doc(chatId);
    final doc = await docRef.get();

    if (doc.exists) {
      return ChatSession.fromFirestore(doc);
    }

    final now = DateTime.now();
    final session = ChatSession(
      id: chatId,
      officialId: officialId,
      citizenId: citizenId,
      complaintId: complaintId,
      officialName: officialName,
      citizenName: citizenName,
      lastMessage: '',
      lastMessageTime: now,
      isReadByCitizen: false,
      isReadByOfficial: true,
    );

    await docRef.set(session.toFirestore());
    final snap = await docRef.get();
    return ChatSession.fromFirestore(snap);
  }

  @override
  Stream<List<ChatSession>> streamChatSessionsAsOfficial(String officialId) {
    return _chatsRef
        .where('officialId', isEqualTo: officialId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatSession.fromFirestore(d)).toList());
  }

  @override
  Stream<List<ChatSession>> streamChatSessionsAsCitizen(String citizenId) {
    return _chatsRef
        .where('citizenId', isEqualTo: citizenId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatSession.fromFirestore(d)).toList());
  }

  @override
  Stream<List<ChatMessage>> streamMessages(String chatId) {
    return _chatsRef
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    required bool isOfficialSender,
  }) async {
    final batch = _firestore.batch();
    final chatDoc = _chatsRef.doc(chatId);
    final msgRef = chatDoc.collection('messages').doc();

    // Use client timestamp for immediate ordering + server timestamp for authoritative order.
    final clientTs = Timestamp.now();

    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'timestampClient': clientTs,
    });

    final updateData = <String, dynamic>{
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageTimeClient': clientTs,
    };

    if (isOfficialSender) {
      updateData['isReadByCitizen'] = false;
      updateData['isReadByOfficial'] = true;
    } else {
      updateData['isReadByOfficial'] = false;
      updateData['isReadByCitizen'] = true;
    }

    batch.update(chatDoc, updateData);
    await batch.commit();
  }

  @override
  Future<void> markReadByCitizen(String chatId) =>
      _chatsRef.doc(chatId).update({'isReadByCitizen': true});

  @override
  Future<void> markReadByOfficial(String chatId) =>
      _chatsRef.doc(chatId).update({'isReadByOfficial': true});

  @override
  Stream<int> streamUnreadCountForCitizen(String citizenId) {
    return _chatsRef
        .where('citizenId', isEqualTo: citizenId)
        .where('isReadByCitizen', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Stream<int> streamUnreadCountForOfficial(String officialId) {
    return _chatsRef
        .where('officialId', isEqualTo: officialId)
        .where('isReadByOfficial', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
