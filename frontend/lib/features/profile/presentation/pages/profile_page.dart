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
  final _editPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _editFirstNameController.dispose();
    _editLastNameController.dispose();
    _editPhoneController.dispose();
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
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.black45;
    final fieldBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

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
        _editPhoneController.text = data['phone'] ?? '';
      } else {
        final parts = (user.displayName ?? '').split(' ');
        _editFirstNameController.text = parts.isNotEmpty ? parts.first : '';
        _editLastNameController.text =
            parts.length > 1 ? parts.sublist(1).join(' ') : '';
        _editPhoneController.text = '';
      }
    } catch (_) {
      final parts = (user.displayName ?? '').split(' ');
      _editFirstNameController.text = parts.isNotEmpty ? parts.first : '';
      _editLastNameController.text =
          parts.length > 1 ? parts.sublist(1).join(' ') : '';
      _editPhoneController.text = '';
    }

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: dialogBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Header icon ──
                            Icon(Icons.edit_note_rounded,
                                color: accent, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Update your profile information',
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Email (read-only) ──
                            _buildEditRow(
                              icon: Icons.email_outlined,
                              label: user.email ?? '',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              isReadOnly: true,
                              accent: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),

                            // ── First Name ──
                            _buildEditField(
                              controller: _editFirstNameController,
                              icon: Icons.person_outline,
                              hint: 'First Name',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              accent: accent,
                              isDark: isDark,
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
                            const SizedBox(height: 10),

                            // ── Last Name ──
                            _buildEditField(
                              controller: _editLastNameController,
                              icon: Icons.person_outline,
                              hint: 'Last Name',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              accent: accent,
                              isDark: isDark,
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
                            const SizedBox(height: 10),

                            // ── Phone Number ──
                            _buildEditField(
                              controller: _editPhoneController,
                              icon: Icons.phone_outlined,
                              hint: 'Phone Number',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              accent: accent,
                              isDark: isDark,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Phone number is required';
                                }
                                final cleaned =
                                    v.trim().replaceAll(RegExp(r'[\s\-()]'), '');
                                if (cleaned.length < 9 ||
                                    cleaned.length > 15) {
                                  return 'Enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // ── Save button ──
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }

                                        setDialogState(
                                            () => isSaving = true);

                                        try {
                                          final firstName =
                                              _editFirstNameController.text
                                                  .trim();
                                          final lastName =
                                              _editLastNameController.text
                                                  .trim();
                                          final fullName =
                                              '$firstName $lastName';

                                          await user
                                              .updateDisplayName(fullName);
                                          await user.reload();

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user.uid)
                                              .set({
                                            'firstName': firstName,
                                            'lastName': lastName,
                                            'displayName': fullName,
                                            'phone': _editPhoneController
                                                .text
                                                .trim(),
                                          }, SetOptions(merge: true));

                                          if (!context.mounted) return;
                                          Navigator.pop(context);

                                          if (mounted) setState(() {});

                                          ScaffoldMessenger.of(this.context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Profile updated successfully'),
                                              backgroundColor: accent,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        } catch (e) {
                                          setDialogState(
                                              () => isSaving = false);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Failed to update: ${e.toString()}'),
                                              backgroundColor:
                                                  Colors.redAccent,
                                              behavior:
                                                  SnackBarBehavior.floating,
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
                                    borderRadius: BorderRadius.circular(14),
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

                            // ── Close button ──
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Close',
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Read-only row for email display.
  Widget _buildEditRow({
    required IconData icon,
    required String label,
    required Color fieldBg,
    required Color textColor,
    required Color accent,
    required bool isDark,
    bool isReadOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: isReadOnly
                  ? (isDark ? Colors.white38 : Colors.black26)
                  : accent,
              size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isReadOnly
                    ? (isDark ? Colors.white38 : Colors.black38)
                    : textColor,
                fontSize: 15,
              ),
            ),
          ),
          if (isReadOnly)
            Icon(Icons.lock_outline,
                color: isDark ? Colors.white24 : Colors.black12, size: 16),
        ],
      ),
    );
  }

  /// Editable text field row matching the dialog card style.
  Widget _buildEditField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required Color fieldBg,
    required Color textColor,
    required Color accent,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : Colors.black26,
          fontSize: 15,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Icon(icon, color: accent, size: 20),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 42, minHeight: 0),
        filled: true,
        fillColor: fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
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

                  // Name + Edit button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _showEditProfileDialog,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: accent,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
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
