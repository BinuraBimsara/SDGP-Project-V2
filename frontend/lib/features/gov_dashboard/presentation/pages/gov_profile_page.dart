import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
                            Icon(Icons.admin_panel_settings_outlined,
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
            _buildProgressCircleBlock(
              title: 'In Progress',
              subtitle: 'Reports that are being processed and being addressed',
              count: inProgress,
              total: total,
              cardBg: cardBg,
              textColor: textColor,
              subtextColor: subtextColor,
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            // ── Pending Circle Block ──
            _buildProgressCircleBlock(
              title: 'Pending',
              subtitle: 'Reports that still haven\'t been addressed by the authorities yet',
              count: pending,
              total: total,
              cardBg: cardBg,
              textColor: textColor,
              subtextColor: subtextColor,
              isDark: isDark,
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
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 12,
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
          Text(
            'About',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildAboutRow(
            icon: Icons.badge_outlined,
            label: 'Position',
            value: 'Government Official',
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          const SizedBox(height: 12),
          _buildAboutRow(
            icon: Icons.business_outlined,
            label: 'Workplace',
            value: 'Municipal Council',
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          const SizedBox(height: 12),
          _buildAboutRow(
            icon: Icons.location_on_outlined,
            label: 'Location / Branch',
            value: 'Colombo District',
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
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
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
                    fontSize: 12,
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
                    fontSize: 13,
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
