import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/home/presentation/pages/complaint_detail_page.dart';

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

/// Instagram-style page showing all comments by the current user,
/// each displayed alongside a thumbnail of the post commented on.
class CommentsGivenPage extends StatefulWidget {
  const CommentsGivenPage({super.key});

  @override
  State<CommentsGivenPage> createState() => _CommentsGivenPageState();
}

class _CommentsGivenPageState extends State<CommentsGivenPage> {
  List<CommentWithPost> _allComments = [];
  List<CommentWithPost> _displayedComments = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortOrder = 'newest';

  @override
  void initState() {
    super.initState();
    _loadUserComments();
  }

  // ── Data fetching ──────────────────────────────────────────────────────

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
      final complaintsSnap = await firestore.collection('complaints').get();

      final List<CommentWithPost> results = [];

      for (final complaintDoc in complaintsSnap.docs) {
        // Only filter by author — no orderBy to avoid composite index requirement
        final commentsSnap = await complaintDoc.reference
            .collection('comments')
            .where('author', isEqualTo: authorName)
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

      // Sort client-side (newest first by default)
      results.sort((a, b) => b.commentTimestamp.compareTo(a.commentTimestamp));

      if (mounted) {
        setState(() {
          _allComments = results;
          _displayedComments = List.from(results);
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

  void _applySortOrder(String order) {
    setState(() {
      _sortOrder = order;
      _displayedComments = List.from(_allComments);
      if (order == 'oldest') {
        _displayedComments
            .sort((a, b) => a.commentTimestamp.compareTo(b.commentTimestamp));
      } else {
        _displayedComments
            .sort((a, b) => b.commentTimestamp.compareTo(a.commentTimestamp));
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor =
        isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black45;
    const accent = Color(0xFFF9A825);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: textColor,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Comments',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserComments,
        color: accent,
        child: _buildBody(
          isDark: isDark,
          textColor: textColor,
          subtextColor: subtextColor,
          accent: accent,
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
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

    if (_allComments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No Comments Yet',
        subtitle:
            'Your comments on community reports will appear here.\nStart engaging with the community!',
        textColor: textColor,
        subtextColor: subtextColor,
      );
    }

    return Column(
      children: [
        // ── Filter chips row (Instagram-style) ──
        _buildFilterRow(isDark: isDark, textColor: textColor, accent: accent),

        // ── Comments list ──
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _displayedComments.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 72,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            itemBuilder: (context, index) {
              return _buildCommentRow(
                _displayedComments[index],
                isDark: isDark,
                textColor: textColor,
                subtextColor: subtextColor,
                accent: accent,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────

  Widget _buildFilterRow({
    required bool isDark,
    required Color textColor,
    required Color accent,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildFilterChip(
            label: _sortOrder == 'newest' ? 'Newest to oldest' : 'Oldest to newest',
            icon: Icons.swap_vert_rounded,
            isDark: isDark,
            textColor: textColor,
            accent: accent,
            onTap: () {
              _applySortOrder(_sortOrder == 'newest' ? 'oldest' : 'newest');
            },
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: '${_displayedComments.length} comments',
            icon: Icons.chat_outlined,
            isDark: isDark,
            textColor: textColor,
            accent: accent,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    required Color accent,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: textColor),
            ],
          ],
        ),
      ),
    );
  }

  // ── Instagram-style comment row ────────────────────────────────────────

  Widget _buildCommentRow(
    CommentWithPost item, {
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color accent,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? 'You';
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
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User avatar ──
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withValues(alpha: 0.15),
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Text(
                      displayName[0].toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // ── Username + comment text + time ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username + inline comment
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: displayName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: item.commentText,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Time ago + post title hint
                  Row(
                    children: [
                      Text(
                        _formatTimeAgo(item.commentTimestamp),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'on: ${complaint.title}',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Post thumbnail (right side like Instagram) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: complaint.imageUrls.isNotEmpty
                  ? Image.network(
                      complaint.imageUrls.first,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderThumb(accent),
                    )
                  : _buildPlaceholderThumb(accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderThumb(Color accent) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.location_on_outlined,
        color: accent.withValues(alpha: 0.4),
        size: 20,
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────

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

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo';
    } else if (diff.inDays > 6) {
      return '${(diff.inDays / 7).floor()}w';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
