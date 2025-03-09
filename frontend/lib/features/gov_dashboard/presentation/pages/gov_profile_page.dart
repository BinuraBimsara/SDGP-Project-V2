import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/gov_dashboard/presentation/pages/gov_status_reports_page.dart';
import 'package:spotit/main.dart';

/// Government official profile page with Uber-inspired layout.
class GovProfilePage extends StatefulWidget {
  const GovProfilePage({super.key});

  @override
  State<GovProfilePage> createState() => _GovProfilePageState();
}

class _GovProfilePageState extends State<GovProfilePage> {
  List<Complaint> _allComplaints = [];
  bool _isLoading = true;

  // Profile data from Firestore
  String _position = 'Government Official';
  String _workplace = 'Municipal Council';
  String _location = 'Colombo District';
  String _phone = '';

  // Edit controllers
  final _editNameController = TextEditingController();
  final _editPhoneController = TextEditingController();
  final _editPositionController = TextEditingController();
  final _editWorkplaceController = TextEditingController();
  final _editLocationController = TextEditingController();

  @override
  void dispose() {
    _editNameController.dispose();
    _editPhoneController.dispose();
    _editPositionController.dispose();
    _editWorkplaceController.dispose();
    _editLocationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadProfileData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = RepositoryProvider.of(context);
      final complaints = await repo.getComplaints();
      if (mounted) {
        setState(() {
          _allComplaints = complaints;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _position = (data['position'] as String?)?.isNotEmpty == true
              ? data['position']
              : 'Government Official';
          _workplace = (data['workplace'] as String?)?.isNotEmpty == true
              ? data['workplace']
              : 'Municipal Council';
          _location = (data['branch'] as String?)?.isNotEmpty == true
              ? data['branch']
              : 'Colombo District';
          _phone = (data['phone'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        return user.email!.split('@').first;
      }
    }
    return 'User';
  }

  String? _getUserPhoto() {
    return FirebaseAuth.instance.currentUser?.photoURL;
  }

  void _navigateToStatus(String status) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RepositoryProvider(
          repository: RepositoryProvider.of(context),
          child: GovStatusReportsPage(status: status),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFEF5350), size: 22),
              const SizedBox(width: 8),
              Text('Sign Out',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87, fontSize: 18)),
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
              child: Text('Cancel',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    const accent = Color(0xFFF9A825);

    final displayName = _getUserName();
    final photoUrl = _getUserPhoto();

    final resolved = _allComplaints.where((c) => c.status == 'Resolved').length;
    final inProgress = _allComplaints.where((c) => c.status == 'In Progress').length;
    final pending = _allComplaints.where((c) => c.status == 'Pending').length;
    final total = _allComplaints.length;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ── Header: Logout ──
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

            // ── Name + Photo Row (Uber-style) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Name + badge on the left
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Official badge (replaces star rating from screenshot)
                        Row(
                          children: [
                            const Icon(Icons.admin_panel_settings_outlined,
                                color: accent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Official',
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Profile photo on the right
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Icon(Icons.person, color: subtextColor, size: 32)
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Two Action Blocks: Reports Resolved & Inbox ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _navigateToStatus('Resolved'),
                      child: _buildActionBlock(
                        icon: Icons.check_circle_outline,
                        label: 'Reports Resolved',
                        value: _isLoading ? '...' : '$resolved',
                        cardBg: cardBg,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionBlock(
                      icon: Icons.inbox_rounded,
                      label: 'Inbox',
                      value: _isLoading ? '...' : '${_allComplaints.length}',
                      cardBg: cardBg,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── About Block ──
            _buildAboutBlock(cardBg, textColor, subtextColor, isDark),

            const SizedBox(height: 12),

            // ── In Progress Circle Block ──
            GestureDetector(
              onTap: () => _navigateToStatus('In Progress'),
              child: _buildProgressCircleBlock(
                title: 'In Progress',
                subtitle: 'Reports that are being processed and being addressed',
                count: inProgress,
                total: total,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                isDark: isDark,
              ),
            ),

            const SizedBox(height: 12),

            // ── Pending Circle Block ──
            GestureDetector(
              onTap: () => _navigateToStatus('Pending'),
              child: _buildProgressCircleBlock(
                title: 'Pending',
                subtitle: 'Reports that still haven\'t been addressed by the authorities yet',
                count: pending,
                total: total,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                isDark: isDark,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBlock({
    required IconData icon,
    required String label,
    required String value,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
  }) {
    const accent = Color(0xFFF9A825);
    return Container(
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
      child: Row(
        children: [
          Icon(icon, color: accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutBlock(Color cardBg, Color textColor, Color subtextColor, bool isDark) {
    const accent = Color(0xFFF9A825);
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'About',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: _showEditProfileDialog,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, color: accent, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAboutRow(
            icon: Icons.badge_outlined,
            label: 'Position',
            value: _position,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          const SizedBox(height: 12),
          _buildAboutRow(
            icon: Icons.business_outlined,
            label: 'Workplace',
            value: _workplace,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          const SizedBox(height: 12),
          _buildAboutRow(
            icon: Icons.location_on_outlined,
            label: 'Location / Branch',
            value: _location,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subtextColor,
  }) {
    const accent = Color(0xFFF9A825);
    return Row(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: subtextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressCircleBlock({
    required String title,
    required String subtitle,
    required int count,
    required int total,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
  }) {
    // Determine color based on ratio
    Color progressColor;
    if (total == 0) {
      progressColor = Colors.grey;
    } else {
      final ratio = count / total;
      if (ratio < 0.25) {
        progressColor = const Color(0xFFEF5350); // red — few
      } else if (ratio < 0.65) {
        progressColor = const Color(0xFF2196F3); // blue — medium
      } else {
        progressColor = const Color(0xFF4CAF50); // green — most
      }
    }

    return Container(
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
      child: Row(
        children: [
          // Text side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Segmented circle
          SizedBox(
            width: 64,
            height: 64,
            child: CustomPaint(
              painter: _SegmentedCirclePainter(
                filled: count,
                total: total == 0 ? 1 : total,
                filledColor: progressColor,
                emptyColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
              ),
              child: Center(
                child: Text(
                  '$count/$total',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit Profile Dialog ──

  Future<void> _showEditProfileDialog() async {
    final user = FirebaseAuth.instance.currentUser;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFF9A825);
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.black45;
    final fieldBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

    // Pre-fill from current state
    _editNameController.text = user?.displayName ?? _getUserName();
    _editPhoneController.text = _phone;
    _editPositionController.text = _position;
    _editWorkplaceController.text = _workplace;
    _editLocationController.text = _location;

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withAlpha(80),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, anim, secondaryAnim, dialogChild) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: anim,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
              child: dialogChild,
            ),
          ),
        );
      },
      pageBuilder: (ctx, anim, secondaryAnim) {
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
                            // Header
                            const Icon(Icons.edit_note_rounded,
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

                            // Email (read-only)
                            _buildEditRow(
                              icon: Icons.email_outlined,
                              label: user?.email ?? 'official@spotit.lk',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              isReadOnly: true,
                              accent: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),

                            // Name
                            _buildEditField(
                              controller: _editNameController,
                              icon: Icons.person_outline,
                              hint: 'Full Name',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              accent: accent,
                              isDark: isDark,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Name is required';
                                }
                                if (v.trim().length < 2) {
                                  return 'Must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            // Contact Number
                            _buildEditField(
                              controller: _editPhoneController,
                              icon: Icons.phone_outlined,
                              hint: 'Contact Number',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              accent: accent,
                              isDark: isDark,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  final cleaned = v
                                      .trim()
                                      .replaceAll(RegExp(r'[\s\-()]'), '');
                                  if (cleaned.length < 9 ||
                                      cleaned.length > 15) {
                                    return 'Enter a valid phone number';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            // Position
                            _buildEditField(
                              controller: _editPositionController,
                              icon: Icons.badge_outlined,
                              hint: 'Position',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              accent: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),

                            // Branch / Office
                            _buildEditField(
                              controller: _editWorkplaceController,
                              icon: Icons.business_outlined,
                              hint: 'Branch / Office',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              accent: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),

                            // Location of Branch
                            _buildEditField(
                              controller: _editLocationController,
                              icon: Icons.location_on_outlined,
                              hint: 'Location of Branch',
                              fieldBg: fieldBg,
                              textColor: textColor,
                              accent: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 24),

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!
                                            .validate()) {
                                          return;
                                        }
                                        setDialogState(
                                            () => isSaving = true);
                                        try {
                                          final name =
                                              _editNameController.text.trim();

                                          // Update Firebase Auth if user exists
                                          if (user != null) {
                                            await user.updateDisplayName(name);
                                            await user.reload();
                                          }

                                          // Save to Firestore if user exists
                                          if (user != null) {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(user.uid)
                                                .set({
                                              'displayName': name,
                                              'phone': _editPhoneController
                                                  .text
                                                  .trim(),
                                              'position':
                                                  _editPositionController
                                                      .text
                                                      .trim(),
                                              'workplace':
                                                  _editWorkplaceController
                                                      .text
                                                      .trim(),
                                              'branch':
                                                  _editLocationController
                                                      .text
                                                      .trim(),
                                            }, SetOptions(merge: true));
                                          }

                                          if (!context.mounted) return;
                                          Navigator.pop(context);

                                          if (mounted) {
                                            // Update local state immediately
                                            setState(() {
                                              _position =
                                                  _editPositionController
                                                      .text
                                                      .trim();
                                              _workplace =
                                                  _editWorkplaceController
                                                      .text
                                                      .trim();
                                              _location =
                                                  _editLocationController
                                                      .text
                                                      .trim();
                                              _phone =
                                                  _editPhoneController
                                                      .text
                                                      .trim();
                                            });
                                            if (user != null) {
                                              _loadProfileData();
                                            }
                                            ScaffoldMessenger.of(
                                                    this.context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Profile updated successfully'),
                                                backgroundColor: accent,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setDialogState(
                                              () => isSaving = false);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Failed to update: $e'),
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

                            // Close button
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
}

/// Custom painter for a segmented donut chart (like Uber's safety check-up).
class _SegmentedCirclePainter extends CustomPainter {
  final int filled;
  final int total;
  final Color filledColor;
  final Color emptyColor;

  _SegmentedCirclePainter({
    required this.filled,
    required this.total,
    required this.filledColor,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 6.0;
    const gapAngle = 0.06; // gap between segments in radians

    final segmentCount = total.clamp(1, 100);
    final sweepPerSegment = (2 * pi - gapAngle * segmentCount) / segmentCount;
    var startAngle = -pi / 2; // start from top

    final filledPaint = Paint()
      ..color = filledColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final emptyPaint = Paint()
      ..color = emptyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < segmentCount; i++) {
      final paint = i < filled ? filledPaint : emptyPaint;
      canvas.drawArc(rect, startAngle, sweepPerSegment, false, paint);
      startAngle += sweepPerSegment + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedCirclePainter oldDelegate) {
    return filled != oldDelegate.filled ||
        total != oldDelegate.total ||
        filledColor != oldDelegate.filledColor;
  }
}
