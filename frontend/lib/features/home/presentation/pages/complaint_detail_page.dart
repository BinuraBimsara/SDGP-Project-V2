import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/features/chat/presentation/pages/chat_screen.dart';
import 'package:spotit/main.dart';

class Comment {
  final String id;
  final String author;
  final String authorId;
  final String text;
  final DateTime timestamp;
  final String? parentCommentId;
  final bool isOfficial;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.author,
    required this.authorId,
    required this.text,
    required this.timestamp,
    this.parentCommentId,
    this.isOfficial = false,
    List<Comment>? replies,
  }) : replies = replies ?? [];
}

enum ComplaintDetailResult {
  deleted,
}

class ComplaintDetailPage extends StatefulWidget {
  final Complaint complaint;
  final bool isOfficial;

  const ComplaintDetailPage({
    super.key,
    required this.complaint,
    this.isOfficial = false,
  });

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
  bool _isOfficial = false;
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
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    // If already marked as official (e.g. from gov dashboard), skip Firestore check
    if (widget.isOfficial) {
      if (mounted) setState(() => _isOfficial = true);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()?['role'] == 'official' && mounted) {
        setState(() => _isOfficial = true);
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
    }
  }

  Future<void> _openChatWithCitizen() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatRepo = ChatRepositoryProvider.of(context);

    final officialDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final officialName = officialDoc.data()?['name'] as String? ??
        currentUser.displayName ??
        'Official';

    final session = await chatRepo.getOrCreateChat(
      officialId: currentUser.uid,
      citizenId: _complaint.authorId,
      complaintId: _complaint.id,
      officialName: officialName,
      citizenName: _complaint.authorName,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: session.id,
          otherUserName: _complaint.authorName,
          isOfficial: true,
        ),
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
                isOfficial: data['isOfficial'] as bool? ?? false,
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

  /// Pull-to-refresh: reloads comments and complaint data.
  Future<void> _refreshDetail() async {
    // Reload comments
    setState(() => _isLoadingComments = true);
    await _loadComments();
    // Also refresh the complaint data (upvote count, status, etc.)
    try {
      final updated = await _repository.getComplaintById(_complaint.id);
      if (updated != null && mounted) {
        setState(() {
          _complaint = updated.copyWith(isUpvoted: _hasUpvoted);
        });
      }
    } catch (e) {
      debugPrint('Error refreshing complaint: $e');
    }
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
      Navigator.pop(context, ComplaintDetailResult.deleted);
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
      isOfficial: _isOfficial,
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
        floatingActionButton: _isOfficial
            ? FloatingActionButton.extended(
                onPressed: _openChatWithCitizen,
                backgroundColor: const Color(0xFF2EAA5E),
                icon: const Icon(Icons.chat_rounded, color: Colors.white),
                label: const Text(
                  'Contact Citizen',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              )
            : null,
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshDetail,
                color: const Color(0xFFF9A825),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                displacement: 40,
                strokeWidth: 2.5,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          if (_complaint.distanceInMeters !=
                                                  null &&
                                              _complaint.distanceInMeters !=
                                                  double.maxFinite)
                                            _buildBadge(
                                              _formatDistance(
                                                  _complaint.distanceInMeters!),
                                              const Color(0xFF607D8B),
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
                                      onTap: _isOfficial ? null : _toggleUpvote,
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
                                                      ? Colors.white.withValues(
                                                          alpha: 0.08)
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
                                                        ? Colors.white
                                                            .withValues(
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

                            // Official-only location section
                            if (_isOfficial)
                              _buildOfficialLocationSection(isDark, textColor),

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

  // ── Official-only location section with map + navigation ──
  Widget _buildOfficialLocationSection(bool isDark, Color textColor) {
    final lat = _complaint.latitude;
    final lng = _complaint.longitude;

    // No coordinates → don't show anything
    if (lat == null || lng == null) return const SizedBox.shrink();

    final target = LatLng(lat, lng);
    const accent = Color(0xFFF9A825);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final border = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, color: accent, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Official: Complaint Location',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Map card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 20),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: target,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('complaint_location'),
                    position: target,
                    infoWindow: InfoWindow(
                      title: _complaint.title,
                      snippet: _complaint.locationName,
                    ),
                  ),
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomGesturesEnabled: false,
                liteModeEnabled: true,
                style: isDark ? _darkMapStyle : _lightMapStyle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Location name
        if (_complaint.locationName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: accent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _complaint.locationName,
                    style: TextStyle(
                      color:
                          isDark ? Colors.white.withAlpha(180) : Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Get Directions button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: const Text(
              'Get Directions in Google Maps',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => _openGoogleMapsNavigation(lat, lng),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _openGoogleMapsNavigation(double lat, double lng) async {
    // Try Google Maps app first
    final googleMapsUri = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=d',
    );

    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri);
      return;
    }

    // Fallback: open in browser
    final browserUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (await canLaunchUrl(browserUri)) {
      await launchUrl(browserUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open maps application'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // ── Map styles (same as LocationPickerScreen) ──
  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0d0d0d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0d0d0d"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1f1f1f"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#303030"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2a2a2a"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#3a3a3a"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#08141a"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#445e75"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#131313"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#0a1c12"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#2d5a27"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#141414"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#2a2a2a"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#f9a825"}]}
]
''';

  static const String _lightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e0e0e0"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#e8e8e8"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#d0d0d0"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c8e6f5"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#6b9dc2"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#c8e6c9"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#4caf50"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#c0c0c0"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#f9a825"}]}
]
''';

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
    final isOfficialComment = comment.isOfficial;
    // Official comment accent: a muted teal-green that works on both themes
    const officialAccent = Color(0xFF2E7D32);

    return GestureDetector(
      onLongPress: isOwn ? () => _confirmDeleteComment(comment) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: leftPad),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOfficialComment
              ? (isDark ? const Color(0xFF1B3A1B) : const Color(0xFFE8F5E9))
              : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(12),
          border: isOfficialComment
              ? Border.all(
                  color: officialAccent.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : depth > 0
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
                  backgroundColor: isOfficialComment
                      ? officialAccent.withValues(alpha: 0.2)
                      : const Color(0xFFF9A825).withValues(alpha: 0.2),
                  child: Text(
                    comment.author.isNotEmpty
                        ? comment.author[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isOfficialComment
                          ? officialAccent
                          : const Color(0xFFF9A825),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.author,
                          style: TextStyle(
                            color:
                                isOfficialComment ? officialAccent : textColor,
                            fontWeight: isOfficialComment
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOfficialComment) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: officialAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Official',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                color: isOfficialComment
                    ? (isDark
                        ? const Color(0xFFA5D6A7)
                        : const Color(0xFF1B5E20))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.black54),
                fontSize: 13,
                fontWeight:
                    isOfficialComment ? FontWeight.w700 : FontWeight.normal,
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

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m away';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km away';
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
