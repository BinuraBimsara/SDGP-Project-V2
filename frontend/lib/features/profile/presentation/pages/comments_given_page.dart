import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/home/presentation/pages/complaint_detail_page.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/main.dart';

/// A model representing a user comment alongside the parent complaint.
class CommentWithPost {
  final String commentId;
  final String commentText;
  final DateTime commentTimestamp;
  final Complaint complaint;

  CommentWithPost({
    required this.commentId,
    required this.commentText,
    required this.commentTimestamp,
    required this.complaint,
  });
}

/// Page that shows all comments given by the current user alongside
/// the complaint they were posted on — similar to Instagram's comment history.
class CommentsGivenPage extends StatefulWidget {
  const CommentsGivenPage({super.key});

  @override
  State<CommentsGivenPage> createState() => _CommentsGivenPageState();
}

class _CommentsGivenPageState extends State<CommentsGivenPage> {
  List<CommentWithPost> _comments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserComments();
  }

  Future<void> _loadUserComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'You must be signed in to view comments.';
      });
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final authorName = user.displayName ?? user.email ?? '';

      // Fetch all complaints
      final complaintsSnap = await firestore
          .collection('complaints')
          .orderBy('timestamp', descending: true)
          .get();

      final List<CommentWithPost> results = [];

      for (final complaintDoc in complaintsSnap.docs) {
        // Query this complaint's comments subcollection for current user
        final commentsSnap = await complaintDoc.reference
            .collection('comments')
            .where('author', isEqualTo: authorName)
            .orderBy('timestamp', descending: true)
            .get();

        if (commentsSnap.docs.isEmpty) continue;

        final complaint = Complaint.fromFirestore(complaintDoc);

        for (final commentDoc in commentsSnap.docs) {
          final data = commentDoc.data();
          final ts = data['timestamp'] is Timestamp
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now();

          results.add(CommentWithPost(
            commentId: commentDoc.id,
            commentText: data['text'] as String? ?? '',
            commentTimestamp: ts,
            complaint: complaint,
          ));
        }
      }

      // Sort all comments by timestamp descending
      results.sort((a, b) => b.commentTimestamp.compareTo(a.commentTimestamp));

      if (mounted) {
        setState(() {
          _comments = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user comments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load comments. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    const accent = Color(0xFFF9A825);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Comments Given',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserComments,
        color: accent,
        child: _buildBody(
          isDark: isDark,
          textColor: textColor,
          subtextColor: isDark
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.black54,
          cardBg: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          accent: accent,
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color accent,
  }) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF9A825),
          strokeWidth: 2,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: _errorMessage!,
        textColor: textColor,
        subtextColor: subtextColor,
      );
    }

    if (_comments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No Comments Yet',
        subtitle:
            'Your comments on community reports will appear here. Start engaging with the community!',
        textColor: textColor,
        subtextColor: subtextColor,
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        return _buildCommentCard(
          _comments[index],
          isDark: isDark,
          textColor: textColor,
          subtextColor: subtextColor,
          cardBg: cardBg,
          accent: accent,
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: const Color(0xFFF9A825)),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentCard(
    CommentWithPost item, {
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color accent,
  }) {
    final complaint = item.complaint;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailPage(complaint: complaint),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Post preview section ──
            _buildPostPreview(
              complaint,
              isDark: isDark,
              textColor: textColor,
              subtextColor: subtextColor,
              accent: accent,
            ),

            // ── Divider ──
            Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),

            // ── User's comment section ──
            _buildCommentSection(
              item,
              isDark: isDark,
              textColor: textColor,
              subtextColor: subtextColor,
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostPreview(
    Complaint complaint, {
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (complaint.imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                complaint.imageUrls.first,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.image_outlined,
                      color: accent.withValues(alpha: 0.5), size: 24),
                ),
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.location_on_outlined,
                  color: accent.withValues(alpha: 0.5), size: 24),
            ),

          const SizedBox(width: 12),

          // Post info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complaint.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildTag(complaint.category, accent),
                    const SizedBox(width: 8),
                    _buildStatusDot(complaint.status),
                    const SizedBox(width: 4),
                    Text(
                      complaint.status,
                      style: TextStyle(color: subtextColor, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (complaint.locationName.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: subtextColor),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          complaint.locationName,
                          style: TextStyle(color: subtextColor, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Chevron
          Icon(Icons.chevron_right_rounded, color: subtextColor, size: 20),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusDot(String status) {
    Color dotColor;
    switch (status.toLowerCase()) {
      case 'resolved':
        dotColor = const Color(0xFF4CAF50);
        break;
      case 'in progress':
        dotColor = const Color(0xFFF9A825);
        break;
      default:
        dotColor = const Color(0xFFEF5350);
    }

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCommentSection(
    CommentWithPost item, {
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color accent,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? 'You';

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: accent.withValues(alpha: 0.15),
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(
                    displayName[0].toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(item.commentTimestamp),
                      style: TextStyle(color: subtextColor, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.commentText,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
