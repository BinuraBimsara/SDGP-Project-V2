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
      body: const Center(
        child: Text('Loading...'),
      ),
    );
  }
}
