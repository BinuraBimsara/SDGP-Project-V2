import 'package:flutter/material.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';

class Comment {
  final String id;
  final String author;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.author,
    required this.text,
    required this.timestamp,
  });
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

    // Add some dummy comments
    _comments.addAll([
      Comment(
        id: 'c1',
        author: 'John D.',
        text:
            'This has been bothering the whole neighbourhood. Hope it gets fixed soon!',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Comment(
        id: 'c2',
        author: 'Sarah M.',
        text:
            'I reported this to the council last week as well. No response yet.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ]);
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
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    setState(() {
      _comments.add(
        Comment(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}',
          author: 'You',
          text: _commentController.text.trim(),
          timestamp: DateTime.now(),
        ),
      );
      _complaint = _complaint.copyWith(
        commentCount: _complaint.commentCount + 1,
      );
      _commentController.clear();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
                            ? const Color(0xFF9C27B0)
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
                              backgroundColor: const Color(0xFF9C27B0),
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
    final subtextColor =
        isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black54;
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
                    // Image
                    if (_complaint.imageUrl.isNotEmpty)
                      Image.network(
                        _complaint.imageUrl,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 250,
                          color: inputBg,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                              size: 50,
                            ),
                          ),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(16),
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
                          const SizedBox(height: 12),

                          // Badges
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildBadge(
                                _complaint.category,
                                _getCategoryColor(_complaint.category),
                              ),
                              _buildBadge(
                                _complaint.status,
                                _getStatusColor(_complaint.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Location & Date
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: metaColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _complaint.locationString,
                                style: TextStyle(
                                  color: metaColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: metaColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(_complaint.timestamp),
                                style: TextStyle(
                                  color: metaColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Description
                          Text(
                            _complaint.description,
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Upvote button with bounce
                          Center(
                            child: GestureDetector(
                              onTap: _toggleUpvote,
                              child: ScaleTransition(
                                scale: _upvoteBounceAnimation,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _hasUpvoted
                                        ? const Color(
                                            0xFFFFC107,
                                          ).withValues(alpha: 0.15)
                                        : isDark
                                            ? const Color(0xFF1C2733)
                                            : const Color(0xFFE8EDF2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _hasUpvoted
                                          ? const Color(
                                              0xFFFFC107,
                                            ).withValues(alpha: 0.4)
                                          : isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.1)
                                              : Colors.black.withValues(
                                                  alpha: 0.08,
                                                ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward_rounded,
                                        color: _hasUpvoted
                                            ? const Color(0xFF9C27B0)
                                            : isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.7,
                                                  )
                                                : Colors.black54,
                                        size: 26,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_complaint.upvoteCount}',
                                        style: TextStyle(
                                          color: _hasUpvoted
                                              ? const Color(0xFF9C27B0)
                                              : isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.8,
                                                    )
                                                  : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _hasUpvoted ? 'Upvoted' : 'Upvote',
                                        style: TextStyle(
                                          color: _hasUpvoted
                                              ? const Color(0xFF9C27B0)
                                              : isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.5,
                                                    )
                                                  : Colors.black45,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

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
                          if (_comments.isEmpty)
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
                            ...List.generate(_comments.length, (i) {
                              return _buildCommentTile(
                                _comments[i],
                                isDark,
                                textColor,
                              );
                            }),
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
                8,
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
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
                        color: Color(0xFF9C27B0),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(Comment comment, bool isDark, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                child: Text(
                  comment.author[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF9C27B0),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                comment.author,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
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
        ],
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

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
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
      case 'pothole':
        return const Color(0xFFE91E63);
      case 'infrastructure':
        return const Color(0xFF2196F3);
      case 'utilities':
        return const Color(0xFF9C27B0);
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
