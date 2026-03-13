import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSession {
  final String id;
  final String officialId;
  final String citizenId;
  final String complaintId;
  final String officialName;
  final String citizenName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isReadByCitizen;
  final bool isReadByOfficial;

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

  factory ChatSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime time;
    if (data['lastMessageTime'] is Timestamp) {
      time = (data['lastMessageTime'] as Timestamp).toDate();
    } else if (data['lastMessageTimeClient'] is Timestamp) {
      time = (data['lastMessageTimeClient'] as Timestamp).toDate();
    } else {
      time = DateTime.now();
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
