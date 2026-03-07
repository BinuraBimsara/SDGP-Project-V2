import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/profile/presentation/pages/comments_given_page.dart';

class ProfilePage extends StatefulWidget {
  /// Callback to switch the bottom navigation tab (used to jump to Reports tab).
  final void Function(int index)? onSwitchTab;

  /// Whether this profile belongs to a government official.
  final bool isOfficial;

  const ProfilePage({super.key, this.onSwitchTab, this.isOfficial = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _reportsCount = 0;
  int _upvotesReceived = 0;
  int _commentsGiven = 0;
  bool _isLoading = true;

  // Edit profile controllers
  final _editFirstNameController = TextEditingController();
  final _editLastNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _editFirstNameController.dispose();
    _editLastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;

    // ── Reports & Upvotes (independent try/catch) ──
    try {
      // Fetch all complaints, filter client-side to avoid composite index
      final allComplaintsSnap = await firestore
          .collection('complaints')
          .get();

      final myComplaints = allComplaintsSnap.docs
          .where((doc) => doc.data()['authorId'] == user.uid)
          .toList();

      int totalUpvotes = 0;
      for (final doc in myComplaints) {
        final data = doc.data();
        totalUpvotes += (data['upvoteCount'] as num?)?.toInt() ?? 0;
      }

      if (mounted) {
        setState(() {
          _reportsCount = myComplaints.length;
          _upvotesReceived = totalUpvotes;
        });
      }
    } catch (e) {
      debugPrint('Error loading reports/upvotes stats: $e');
    }

    // ── Comments Given (independent try/catch) ──
    try {
      final complaintsSnap = await firestore.collection('complaints').get();
      int commentsCount = 0;

      for (final complaintDoc in complaintsSnap.docs) {
        final commentsSnap = await complaintDoc.reference
            .collection('comments')
            .where('authorId', isEqualTo: user.uid)
            .get();
        commentsCount += commentsSnap.docs.length;
      }

      if (mounted) {
        setState(() {
          _commentsGiven = commentsCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading comments stats: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF5350), size: 22),
              const SizedBox(width: 8),
              Text('Sign Out',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18)),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style:
                    TextStyle(color: isDark ? Colors.white54 : Colors.black45),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // ─── Edit Profile ────────────────────────────────────────

  Future<void> _showEditProfileDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFF9A825);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fieldBg = isDark ? const Color(0xFF2A2A2A) : Colors.grey[100];
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.1);

    // Pre-fill from Firestore first, fallback to Auth displayName
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _editFirstNameController.text = data['firstName'] ?? '';
        _editLastNameController.text = data['lastName'] ?? '';
      } else {
        final parts = (user.displayName ?? '').split(' ');
        _editFirstNameController.text = parts.isNotEmpty ? parts.first : '';
        _editLastNameController.text =
            parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    } catch (_) {
      final parts = (user.displayName ?? '').split(' ');
      _editFirstNameController.text = parts.isNotEmpty ? parts.first : '';
      _editLastNameController.text =
          parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Update your display name.',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // First Name
                      Text(
                        'First Name',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _editFirstNameController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Enter first name',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: borderColor, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: borderColor, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: accent, width: 1.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'First name is required';
                          }
                          if (v.trim().length < 2) {
                            return 'Must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      Text(
                        'Last Name',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _editLastNameController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Enter last name',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: borderColor, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: borderColor, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: accent, width: 1.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Last name is required';
                          }
                          if (v.trim().length < 2) {
                            return 'Must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setSheetState(() => isSaving = true);

                                  try {
                                    final firstName =
                                        _editFirstNameController.text.trim();
                                    final lastName =
                                        _editLastNameController.text.trim();
                                    final fullName = '$firstName $lastName';

                                    // Update Firebase Auth display name
                                    await user.updateDisplayName(fullName);
                                    await user.reload();

                                    // Update Firestore user document
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .set({
                                      'firstName': firstName,
                                      'lastName': lastName,
                                      'displayName': fullName,
                                    }, SetOptions(merge: true));

                                    if (!context.mounted) return;
                                    Navigator.pop(context);

                                    // Refresh the profile page
                                    if (mounted) setState(() {});

                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Profile updated successfully'),
                                        backgroundColor: accent,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    setSheetState(() => isSaving = false);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to update: ${e.toString()}'),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                accent.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    const accent = Color(0xFFF9A825);

    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final photoUrl = user?.photoURL;
    final memberSince = user?.metadata.creationTime;

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ── Header Banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: _signOut,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout_rounded, color: accent, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── User Info Card ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1A2A1A),
                          const Color(0xFF1E1E1E),
                        ]
                      : [
                          const Color(0xFFE8F5E9),
                          const Color(0xFFF1F8E9),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile photo
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: accent.withValues(alpha: 0.15),
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Text(
                              displayName[0].toUpperCase(),
                              style: const TextStyle(
                                color: accent,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name
                  Text(
                    displayName,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    email,
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Role badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            widget.isOfficial || email.endsWith('.gov.lk')
                                ? Icons.admin_panel_settings_outlined
                                : Icons.person_outline_rounded,
                            color: accent,
                            size: 14),
                        const SizedBox(width: 4),
                        Text(
                          widget.isOfficial || email.endsWith('.gov.lk') ? 'Official' : 'Citizen',
                          style: const TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats Cards ──
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: accent, strokeWidth: 2),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.location_on_outlined,
                            value: '$_reportsCount',
                            label: 'Reports Submitted',
                            cardBg: cardBg,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            onTap: () {
                              // Switch to the My Reports tab (index 2)
                              widget.onSwitchTab?.call(2);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.trending_up_rounded,
                            value: '$_upvotesReceived',
                            label: 'Upvotes Received',
                            cardBg: cardBg,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      value: '$_commentsGiven',
                      label: 'Comments Given',
                      cardBg: cardBg,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      isDark: isDark,
                      fullWidth: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CommentsGivenPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ── About Section ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Member Since
                  Text(
                    'Member Since',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    memberSince != null ? _formatDate(memberSince) : 'Unknown',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Community Impact
                  Text(
                    'Community Impact',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thank you for helping make our community better! '
                    'Your contributions help local government identify '
                    'and resolve issues more efficiently.',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
    bool fullWidth = false,
    VoidCallback? onTap,
  }) {
    const accent = Color(0xFFF9A825);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: subtextColor,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          if (onTap != null) ...[
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: accent),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
