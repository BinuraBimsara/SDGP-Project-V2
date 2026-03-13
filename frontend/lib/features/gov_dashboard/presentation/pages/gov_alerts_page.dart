import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotit/features/chat/data/models/chat_session_model.dart';
import 'package:spotit/features/chat/domain/repositories/chat_repository.dart';
import 'package:spotit/features/chat/presentation/pages/chat_screen.dart';
import 'package:spotit/features/chat/presentation/widgets/chat_session_card.dart';
import 'package:spotit/main.dart';

/// A notification / alert item for government officials.
class _GovAlert {
  final String reportTitle;
  final String replierName;
  final String replyText;
  final DateTime time;
  final String complaintId;

  _GovAlert({
    required this.reportTitle,
    required this.replierName,
    required this.replyText,
    required this.time,
    required this.complaintId,
  });
}

/// Alerts page for government officials.
/// Shows notifications when someone replies to the official's comments.
class GovAlertsPage extends StatefulWidget {
  const GovAlertsPage({super.key});

  @override
  State<GovAlertsPage> createState() => _GovAlertsPageState();
}

class _GovAlertsPageState extends State<GovAlertsPage> {
  List<_GovAlert> _alerts = [];
  bool _isLoading = true;
  late ChatRepository _chatRepo;
  bool _hasInitializedChat = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedChat) {
      _chatRepo = ChatRepositoryProvider.of(context);
      _hasInitializedChat = true;
    }
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;

      final firestore = FirebaseFirestore.instance;
      final complaintsSnap = await firestore
          .collection('complaints')
          .orderBy('timestamp', descending: true)
          .get();

      final List<_GovAlert> alerts = [];

      for (final complaintDoc in complaintsSnap.docs) {
        final complaintData = complaintDoc.data();
        final reportTitle =
            (complaintData['title'] as String?) ?? 'Untitled Report';

        // Get all comments for this complaint
        final commentsSnap = await complaintDoc.reference
            .collection('comments')
            .orderBy('timestamp', descending: false)
            .get();

        // Find IDs of comments made by an official
        // Match by authorId if logged in, otherwise match all isOfficial comments
        final officialCommentIds = <String>{};
        for (final commentDoc in commentsSnap.docs) {
          final data = commentDoc.data();
          final isOfficialComment = data['isOfficial'] == true;
          if (!isOfficialComment) continue;

          // If logged in, only match this user's official comments
          // If dev bypass (no uid), match all official comments
          if (uid != null && uid.isNotEmpty) {
            if (data['authorId'] == uid) {
              officialCommentIds.add(commentDoc.id);
            }
          } else {
            officialCommentIds.add(commentDoc.id);
          }
        }

        if (officialCommentIds.isEmpty) continue;

        // Find replies to those official comments
        for (final commentDoc in commentsSnap.docs) {
          final data = commentDoc.data();
          final parentId = data['parentCommentId'] as String?;
          if (parentId != null &&
              officialCommentIds.contains(parentId) &&
              data['isOfficial'] != true) {
            final ts = data['timestamp'];
            final time = ts is Timestamp ? ts.toDate() : DateTime.now();
            alerts.add(_GovAlert(
              reportTitle: reportTitle,
              replierName: (data['author'] as String?) ?? 'Someone',
              replyText: (data['text'] as String?) ?? '',
              time: time,
              complaintId: complaintDoc.id,
            ));
          }
        }
      }

      // Sort newest first
      alerts.sort((a, b) => b.time.compareTo(a.time));

      if (mounted) {
        setState(() {
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alerts',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_alerts.length} notification${_alerts.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _loadAlerts,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            // Alert List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF9A825),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAlerts,
                      color: const Color(0xFFF9A825),
                      child: ListView(
                        children: [
                          // Active chats section
                          _buildChatSessionsSection(
                              isDark, textColor, subtitleColor),
                          // Comment replies section
                          if (_alerts.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                'Comment Replies',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            ..._alerts.map((alert) => _buildAlertCard(
                                  alert,
                                  isDark,
                                  textColor,
                                  subtitleColor,
                                )),
                          ],
                          if (_alerts.isEmpty && !_hasInitializedChat)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 56,
                                    color: subtitleColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No alerts yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You\'ll be notified when someone\nreplies to your comments',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatSessionsSection(
      bool isDark, Color textColor, Color? subtitleColor) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<ChatSession>>(
      stream: _chatRepo.streamChatSessionsAsOfficial(uid),
      builder: (context, snapshot) {
        final chats = snapshot.data ?? [];
        if (chats.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Active Chats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            ...chats.map((chat) => ChatSessionCard(
                  session: chat,
                  isUnread: !chat.isReadByOfficial,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chat.id,
                        otherUserName: chat.citizenName,
                        isOfficial: true,
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildAlertCard(
    _GovAlert alert,
    bool isDark,
    Color textColor,
    Color? subtitleColor,
  ) {
    final cardBgColor = isDark ? const Color(0xFF1E2124) : Colors.white;
    final iconBgColor =
        isDark ? const Color(0xFF2B2D31) : Colors.blueGrey.shade50;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? Colors.transparent : Colors.grey.shade300,
          width: 1.0,
        ),
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
              Icons.reply_rounded,
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
                Text(
                  alert.reportTitle,
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6.0),
                Text(
                  '${alert.replierName} has replied to your comment',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: subtitleColor,
                    height: 1.4,
                  ),
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
                      _timeAgo(alert.time),
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
    );
  }
}
