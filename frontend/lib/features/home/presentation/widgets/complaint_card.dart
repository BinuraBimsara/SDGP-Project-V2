import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';

class ComplaintCard extends StatefulWidget {
  final Complaint complaint;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onUpvoteChanged;

  const ComplaintCard({
    super.key,
    required this.complaint,
    this.onTap,
    this.onUpvoteChanged,
  });

  @override
  State<ComplaintCard> createState() => _ComplaintCardState();
}

class _ComplaintCardState extends State<ComplaintCard>
    with SingleTickerProviderStateMixin {
  late bool _isUpvoted;
  late int _upvoteCount;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _isUpvoted = widget.complaint.isUpvoted;
    _upvoteCount = widget.complaint.upvoteCount;
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(ComplaintCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.complaint.isUpvoted != widget.complaint.isUpvoted ||
        oldWidget.complaint.upvoteCount != widget.complaint.upvoteCount) {
      setState(() {
        _isUpvoted = widget.complaint.isUpvoted;
        _upvoteCount = widget.complaint.upvoteCount;
      });
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleUpvote() {
    setState(() {
      _isUpvoted = !_isUpvoted;
      _upvoteCount += _isUpvoted ? 1 : -1;
    });
    _bounceController.forward(from: 0);
    widget.onUpvoteChanged?.call(_isUpvoted);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor =
        isDark ? Colors.white.withValues(alpha: 0.65) : Colors.black54;
    final metaColor =
        isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black38;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.08);

    // Upvote pill colors
    final upvotePillBg =
        isDark ? const Color(0xFF1C2733) : const Color(0xFFE8EDF2);
    final upvoteArrowColor = _isUpvoted
        ? const Color(0xFFF9A825)
        : (isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with upvote count
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.complaint.title,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.complaint.authorName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 13,
                                color: metaColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.complaint.authorName,
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Category & Status Badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildBadge(
                              widget.complaint.category,
                              _getCategoryColor(widget.complaint.category),
                            ),
                            _buildBadge(
                              widget.complaint.status,
                              _getStatusColor(widget.complaint.status),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Upvote pill on the right
                  GestureDetector(
                    onTap: _handleUpvote,
                    behavior: HitTestBehavior.opaque,
                    child: ScaleTransition(
                      scale: _bounceAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _isUpvoted
                              ? const Color(0xFFF9A825).withValues(alpha: 0.15)
                              : upvotePillBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isUpvoted
                                ? const Color(0xFFF9A825).withValues(alpha: 0.4)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06)),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              color: upvoteArrowColor,
                              size: 20,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_upvoteCount',
                              style: TextStyle(
                                color: _isUpvoted
                                    ? const Color(0xFFF9A825)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : Colors.black87),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Image – Instagram-style dynamic aspect ratio
            if (widget.complaint.imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _DynamicAspectRatioImage(
                    imageUrl: widget.complaint.imageUrl,
                    isDark: isDark,
                  ),
                ),
              ),

            // Description
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                widget.complaint.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),

            // Footer: location, date, comments
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  // Location
                  Icon(Icons.location_on_outlined, size: 14, color: metaColor),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      _formatLocationWithDistance(widget.complaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: metaColor, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Date
                  Icon(Icons.access_time_rounded, size: 14, color: metaColor),
                  const SizedBox(width: 3),
                  Text(
                    _formatDate(widget.complaint.timestamp),
                    style: TextStyle(color: metaColor, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                  // Comments - always visible
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 14,
                    color: metaColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.complaint.commentCount}',
                    style: TextStyle(color: metaColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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

  String _formatLocationWithDistance(Complaint complaint) {
    if (complaint.distanceInMeters != null) {
      final double km = complaint.distanceInMeters! / 1000;
      final String distanceStr = km.toStringAsFixed(1);
      return '${complaint.locationString} • $distanceStr km away';
    }
    return complaint.locationString;
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'waste':
        return const Color(0xFF4CAF50);
      case 'lighting':
        return const Color(0xFFFF9800);
      case 'pothole':
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
// Instagram-style dynamic aspect ratio image
// Resolves actual decoded image dimensions (EXIF rotation is applied by
// Flutter's decoder) and clamps the aspect ratio to:
//   • Portrait max : 4:5  (aspectRatio = 0.8)
//   • Square       : 1:1  (aspectRatio = 1.0)
//   • Landscape max: 1.91:1 (aspectRatio = 1.91)
// ─────────────────────────────────────────────────────────────────────────────
class _DynamicAspectRatioImage extends StatefulWidget {
  final String imageUrl;
  final bool isDark;

  const _DynamicAspectRatioImage({
    required this.imageUrl,
    required this.isDark,
  });

  @override
  State<_DynamicAspectRatioImage> createState() =>
      _DynamicAspectRatioImageState();
}

class _DynamicAspectRatioImageState extends State<_DynamicAspectRatioImage> {
  static const double _minAR = 4 / 5; // 0.8  – portrait
  static const double _maxAR = 1.91; // 1.91 – landscape
  // Start with landscape default so tall images shrink into place
  // rather than expanding (feels more natural when scrolling).
  double _aspectRatio = _maxAR;
  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveImageDimensions();
  }

  @override
  void didUpdateWidget(_DynamicAspectRatioImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _removeListener();
      _aspectRatio = _maxAR;
      _resolveImageDimensions();
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
  }

  void _resolveImageDimensions() {
    _imageStream =
        CachedNetworkImageProvider(widget.imageUrl).resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!mounted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w > 0 && h > 0) {
          final raw = w / h;
          setState(() {
            _aspectRatio = raw.clamp(_minAR, _maxAR);
          });
        }
        _removeListener();
      },
      onError: (exception, stackTrace) {
        if (!mounted) return;
        _removeListener();
      },
    );
    _imageStream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final placeholderColor =
        widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: placeholderColor,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF9A825),
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: placeholderColor,
            child: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
