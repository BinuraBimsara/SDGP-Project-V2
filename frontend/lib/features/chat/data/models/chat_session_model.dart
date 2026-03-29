import 'package:cloud_firestore/cloud_firestore.dart';

// ChatSession represents one conversation thread between a government official
// and a citizen about a specific complaint. It is stored as a document
// in the 'chats' collection in Firestore.
class ChatSession {
  final String id;            // the Firestore document ID (also used as chatId)
  final String officialId;    // UID of the government official
  final String citizenId;     // UID of the citizen
  final String complaintId;   // which complaint this chat is about
  final String officialName;  // display name of the official
  final String citizenName;   // display name of the citizen
  final String lastMessage;   // preview text shown on the chat card
  final DateTime lastMessageTime; // used to sort chats by most recent
  final bool isReadByCitizen;    // false when the official sent an unread message
  final bool isReadByOfficial;   // false when the citizen sent an unread message

  ChatSession({
    required this.id,
    required this.officialId,
    required this.citizenId,
    required this.complaintId,
    this.officialName = '',
    this.citizenName = '',
    this.lastMessage = '',
    required this.lastMessageTime,
    this.isReadByCitizen = false,
    this.isReadByOfficial = false,
  });

  // Converts a Firestore document snapshot into a ChatSession object.
  // We handle two timestamp fields because the server timestamp may not
  // have been written yet (Firestore pending-write state), so we fall
  // back to the client timestamp which is available immediately.
  factory ChatSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime time;
    if (data['lastMessageTime'] is Timestamp) {
      time = (data['lastMessageTime'] as Timestamp).toDate(); // server time
    } else if (data['lastMessageTimeClient'] is Timestamp) {
      time = (data['lastMessageTimeClient'] as Timestamp).toDate(); // client fallback
    } else {
      time = DateTime.now(); // last resort default
    }

    return ChatSession(
      id: doc.id,
      officialId: data['officialId'] as String? ?? '',
      citizenId: data['citizenId'] as String? ?? '',
      complaintId: data['complaintId'] as String? ?? '',
      officialName: data['officialName'] as String? ?? '',
      citizenName: data['citizenName'] as String? ?? '',
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageTime: time,
      isReadByCitizen: data['isReadByCitizen'] as bool? ?? false,
      isReadByOfficial: data['isReadByOfficial'] as bool? ?? false,
    );
  }

  // Converts this ChatSession object into a Map for saving to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'officialId': officialId,
      'citizenId': citizenId,
      'complaintId': complaintId,
      'officialName': officialName,
      'citizenName': citizenName,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'isReadByCitizen': isReadByCitizen,
      'isReadByOfficial': isReadByOfficial,
    };
  }

  // Creates a copy of this object with some fields replaced.
  // Used to update individual fields without mutating the original object.
  ChatSession copyWith({
    String? id,
    String? officialId,
    String? citizenId,
    String? complaintId,
    String? officialName,
    String? citizenName,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isReadByCitizen,
    bool? isReadByOfficial,
  }) {
    return ChatSession(
      id: id ?? this.id,
      officialId: officialId ?? this.officialId,
      citizenId: citizenId ?? this.citizenId,
      complaintId: complaintId ?? this.complaintId,
      officialName: officialName ?? this.officialName,
      citizenName: citizenName ?? this.citizenName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isReadByCitizen: isReadByCitizen ?? this.isReadByCitizen,
      isReadByOfficial: isReadByOfficial ?? this.isReadByOfficial,
    );
  }
}
