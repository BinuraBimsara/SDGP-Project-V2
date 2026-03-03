import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/main.dart';

class Comment {
  final String id;
  final String author;
  final String authorId;
  final String text;
  final DateTime timestamp;
  final String? parentCommentId;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.author,
    required this.authorId,
    required this.text,
    required this.timestamp,
    this.parentCommentId,
    List<Comment>? replies,
  }) : replies = replies ?? [];
}

class ComplaintDetailPage extends StatefulWidget {
  final Complaint complaint;

  const ComplaintDetailPage({super.key, required this.complaint});

  @override
  State<ComplaintDetailPage> createState() => _ComplaintDetailPageState();
}

class _ComplaintDetailPageState extends State<ComplaintDetailPage>
    with SingleTickerProviderStateMixin {
  late Complaint _complaint;
  late bool _hasUpvoted;
  final List<Comment> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _upvoteBounceController;
  late Animation<double> _upvoteBounceAnimation;
  Comment? _replyingTo;
  int _currentImagePage = 0;
  bool _isLoadingComments = true;
  late ComplaintRepository _repository;

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
    _hasUpvoted = widget.complaint.isUpvoted;
    _upvoteBounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _upvoteBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(
        parent: _upvoteBounceController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = RepositoryProvider.of(context);
    if (_isLoadingComments) {
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    try {
      final commentsData = await _repository.getComments(_complaint.id);
      if (!mounted) return;

      // Build flat list first
      final allComments = commentsData
          .map((data) => Comment(
                id: data['id'] as String,
                author: data['author'] as String,
                authorId: data['authorId'] as String? ?? '',
                text: data['text'] as String,
                timestamp: data['timestamp'] as DateTime,
                parentCommentId: data['parentCommentId'] as String?,
              ))
          .toList();

      // Build a tree: top-level + nested replies
      final Map<String, Comment> byId = {};
      for (final c in allComments) {
        byId[c.id] = c;
      }
      final List<Comment> topLevel = [];
      for (final c in allComments) {
        if (c.parentCommentId != null && byId.containsKey(c.parentCommentId)) {
          byId[c.parentCommentId]!.replies.add(c);
        } else {
          topLevel.add(c);
        }
      }

      setState(() {
        _comments.clear();
        _comments.addAll(topLevel);
        _isLoadingComments = false;
      });
    } catch (e) {
      debugPrint('Error loading comments: $e');
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _upvoteBounceController.dispose();
    super.dispose();
  }

  void _toggleUpvote() {
    setState(() {
      _hasUpvoted = !_hasUpvoted;
      _complaint = _complaint.copyWith(
        upvoteCount: _complaint.upvoteCount + (_hasUpvoted ? 1 : -1),
        isUpvoted: _hasUpvoted,
      );
    });
    _upvoteBounceController.forward(from: 0);

    // Persist upvote toggle to Firebase (handles both add/remove)
    _repository.toggleUpvote(_complaint.id).then((_) {}).catchError((e) {
      debugPrint('Error toggling upvote: $e');
    });
  }

  bool get _isAuthor {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return currentUid.isNotEmpty && currentUid == _complaint.authorId;
  }

  void _confirmDelete() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFEF5350), size: 22),
            const SizedBox(width: 8),
            Text(
              'Delete Complaint',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this complaint? This action cannot be undone.',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    try {
      await _repository.deleteComplaint(_complaint.id);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Complaint deleted successfully'),
          backgroundColor: const Color(0xFFF9A825),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint('Error deleting complaint: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete complaint'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    final text = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final author = user?.displayName ?? user?.email ?? 'You';
    final authorId = user?.uid ?? '';
    final parentId = _replyingTo?.id;

    _commentController.clear();
    setState(() {
      _replyingTo = null;
    });

    // Persist comment to Firestore then reload the full tree
    _repository
        .addComment(
      _complaint.id,
      author,
      text,
      authorId: authorId,
      parentCommentId: parentId,
    )
        .then((newCount) {
      setState(() {
        _complaint = _complaint.copyWith(commentCount: newCount);
      });
      _loadComments();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }).catchError((e) {
      debugPrint('Error adding comment: $e');
    });
  }

  /// Confirm & delete a comment via a blurred dialog.
  void _confirmDeleteComment(Comment comment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, a1, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 6 * a1.value,
            sigmaY: 6 * a1.value,
          ),
          child: FadeTransition(
            opacity: a1,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: a1,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (context, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF5350),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Delete Comment',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will also delete all replies. This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _performDeleteComment(comment);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF5350),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _performDeleteComment(Comment comment) async {
    try {
      await _repository.deleteComment(_complaint.id, comment.id);
      if (!mounted) return;
      // Reload comments and update count
      final updatedComplaints =
          await _repository.getComplaintById(_complaint.id);
      if (updatedComplaints != null && mounted) {
        setState(() {
          _complaint = _complaint.copyWith(
            commentCount: updatedComplaints.commentCount,
          );
        });
      }
      await _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Comment deleted'),
            backgroundColor: const Color(0xFFF9A825),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete comment'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showReportDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        String? selectedReason;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    color: Color(0xFFEF5350),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Report Complaint',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Why are you reporting this complaint?',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    'Spam or misleading',
                    'Inappropriate content',
                    'Duplicate complaint',
                    'Incorrect location',
                    'Other',
                  ].map((reason) {
                    final isSelected = selectedReason == reason;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? const Color(0xFFF9A825)
                            : isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black38,
                        size: 22,
                      ),
                      title: Text(
                        reason,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        setDialogState(() {
                          selectedReason = reason;
                        });
                      },
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black45,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedReason != null
                      ? () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Report submitted. Thank you!',
                              ),
                              backgroundColor: const Color(0xFFF9A825),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF5350),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final metaColor =
        isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black38;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final inputBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context, _complaint),
          ),
          title: Text(
            'Complaint Details',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          centerTitle: true,
          actions: [
            if (_isAuthor)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF5350)),
                onPressed: _confirmDelete,
                tooltip: 'Delete',
              ),
            IconButton(
              icon: const Icon(Icons.flag_outlined, color: Color(0xFFEF5350)),
              onPressed: _showReportDialog,
              tooltip: 'Report',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image(s) — carousel if multiple, single if one
                    _buildImageSection(inputBg),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Badges container
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title
                                    Text(
                                      _complaint.title,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_complaint.authorName.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor:
                                                const Color(0xFFF9A825)
                                                    .withValues(alpha: 0.2),
                                            child: Text(
                                              _complaint.authorName[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Color(0xFFF9A825),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _complaint.authorName,
                                            style: TextStyle(
                                              color: metaColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),

                                    // Badges
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        _buildBadge(
                                          _complaint.category,
                                          _getCategoryColor(
                                              _complaint.category),
                                        ),
                                        _buildBadge(
                                          _complaint.status,
                                          _getStatusColor(_complaint.status),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Vertical Upvote Pill
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: _toggleUpvote,
                                    behavior: HitTestBehavior.opaque,
                                    child: ScaleTransition(
                                      scale: _upvoteBounceAnimation,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _hasUpvoted
                                              ? const Color(0xFFF9A825)
                                                  .withValues(alpha: 0.15)
                                              : isDark
                                                  ? const Color(0xFF1C2733)
                                                  : const Color(0xFFE8EDF2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _hasUpvoted
                                                ? const Color(0xFFF9A825)
                                                    .withValues(alpha: 0.4)
                                                : isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.08)
                                                    : Colors.black.withValues(
                                                        alpha: 0.08),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.arrow_upward_rounded,
                                              color: _hasUpvoted
                                                  ? const Color(0xFFF9A825)
                                                  : isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.7)
                                                      : Colors.black54,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_complaint.upvoteCount}',
                                              style: TextStyle(
                                                color: _hasUpvoted
                                                    ? const Color(0xFFF9A825)
                                                    : isDark
                                                        ? Colors.white
                                                            .withValues(
                                                                alpha: 0.8)
                                                        : Colors.black87,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Comments section header
                          Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: textColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Comments (${_comments.length})',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Comments list
                          if (_isLoadingComments)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFF9A825),
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (_comments.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'No comments yet. Be the first to comment!',
                                  style: TextStyle(
                                    color: metaColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._buildCommentThread(
                              _comments,
                              isDark,
                              textColor,
                              0,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Comment input bar
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                8 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply indicator banner
                  if (_replyingTo != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.reply_rounded,
                            size: 16,
                            color: Color(0xFFF9A825),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Replying to @${_replyingTo!.author}',
                              style: const TextStyle(
                                color: Color(0xFFF9A825),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _replyingTo = null);
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _replyingTo != null
                                ? 'Reply to @${_replyingTo!.author}...'
                                : 'Write a comment...',
                            hintStyle: TextStyle(color: metaColor),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _addComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _addComment,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9A825),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the image section: carousel if multiple images, single if one.
  /// Uses Instagram-style dynamic aspect ratio (4:5 to 1.91:1).
  Widget _buildImageSection(Color inputBg) {
    // Collect all image URLs, preferring imageUrls list over single imageUrl
    final List<String> urls = _complaint.imageUrls.isNotEmpty
        ? _complaint.imageUrls
        : (_complaint.imageUrl.isNotEmpty ? [_complaint.imageUrl] : []);

    if (urls.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Single image — dynamic aspect ratio
    if (urls.length == 1) {
      return _DetailDynamicImage(
        imageUrl: urls.first,
        isDark: isDark,
        placeholderColor: inputBg,
      );
    }

    // Multiple images — square carousel with indicators
    return AspectRatio(
      aspectRatio: 1.0, // square for carousel consistency
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentImagePage = i),
            itemBuilder: (context, index) {
              return Image.network(
                urls[index],
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: inputBg,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.grey, size: 50),
                  ),
                ),
              );
            },
          ),
          // Dot indicators
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(urls.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentImagePage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentImagePage == i
                        ? const Color(0xFFF9A825)
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Recursively build comment thread widgets with indentation.
  List<Widget> _buildCommentThread(
    List<Comment> comments,
    bool isDark,
    Color textColor,
    int depth,
  ) {
    final List<Widget> widgets = [];
    for (final comment in comments) {
      widgets.add(
        _buildCommentTile(comment, isDark, textColor, depth),
      );
      if (comment.replies.isNotEmpty) {
        widgets.addAll(
          _buildCommentThread(comment.replies, isDark, textColor, depth + 1),
        );
      }
    }
    return widgets;
  }

  Widget _buildCommentTile(
    Comment comment,
    bool isDark,
    Color textColor,
    int depth,
  ) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwn = currentUid.isNotEmpty && currentUid == comment.authorId;
    // Max indentation depth of 4 levels
    final leftPad = (depth.clamp(0, 4)) * 24.0;

    return GestureDetector(
      onLongPress: isOwn ? () => _confirmDeleteComment(comment) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: leftPad),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: depth > 0
              ? Border(
                  left: BorderSide(
                    color: const Color(0xFFF9A825).withValues(alpha: 0.4),
                    width: 2,
                  ),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      const Color(0xFFF9A825).withValues(alpha: 0.2),
                  child: Text(
                    comment.author.isNotEmpty
                        ? comment.author[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Color(0xFFF9A825),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comment.author,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _timeSince(comment.timestamp),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.black26,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment.text,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.75)
                    : Colors.black54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            // Reply button row
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _replyingTo = comment);
                    // Auto-focus the text field
                    FocusScope.of(context).requestFocus(FocusNode());
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) {
                        FocusScope.of(context).requestFocus(FocusNode());
                      }
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.black38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Text(
                    '${comment.replies.length} ${comment.replies.length == 1 ? 'reply' : 'replies'}',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black26,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            // "Tap and hold to delete" hint for own comments only
            if (isOwn)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tap and hold to delete your comment',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.2),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'waste':
        return const Color(0xFF4CAF50);
      case 'lighting':
        return const Color(0xFFFF9800);
      case 'road damage':
        return const Color(0xFFE91E63);
      case 'infrastructure':
        return const Color(0xFF2196F3);
      case 'utilities':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF607D8B);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF4CAF50);
      case 'in progress':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFFEF5350);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Instagram-style dynamic aspect ratio image for the detail page.
// Same approach as the home feed: resolve decoded dimensions, clamp to
// 4:5 (portrait) ↔ 1.91:1 (landscape).
// ─────────────────────────────────────────────────────────────────────────────
class _DetailDynamicImage extends StatefulWidget {
  final String imageUrl;
  final bool isDark;
  final Color placeholderColor;

  const _DetailDynamicImage({
    required this.imageUrl,
    required this.isDark,
    required this.placeholderColor,
  });

  @override
  State<_DetailDynamicImage> createState() => _DetailDynamicImageState();
}

class _DetailDynamicImageState extends State<_DetailDynamicImage> {
  static const double _minAR = 4 / 5; // portrait
  static const double _maxAR = 1.91; // landscape
  double _aspectRatio = _maxAR;
  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_DetailDynamicImage old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) {
      _cleanup();
      _aspectRatio = _maxAR;
      _resolve();
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _cleanup() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
  }

  void _resolve() {
    _imageStream =
        NetworkImage(widget.imageUrl).resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!mounted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w > 0 && h > 0) {
          final raw = w / h;
          setState(() => _aspectRatio = raw.clamp(_minAR, _maxAR));
        }
        _cleanup();
      },
      onError: (_, __) {
        if (!mounted) return;
        _cleanup();
      },
    );
    _imageStream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Image.network(
          widget.imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: widget.placeholderColor,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: const Color(0xFFF9A825),
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: widget.placeholderColor,
            child: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
                size: 50,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
