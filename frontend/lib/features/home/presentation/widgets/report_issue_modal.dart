import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotit/core/services/location_service.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/home/presentation/widgets/location_picker_screen.dart';
import 'package:spotit/main.dart';

// ─── Helper: show the modal ─────────────────────────────────────────────────
/// Call this from anywhere (e.g. FAB onPressed) to display the Report Issue
/// dialog with a smooth OriginOS-style spring animation.
void showReportIssueModal(BuildContext context) {
  Navigator.of(context).push(_ReportIssueRoute());
}

// ─── Custom route with OriginOS-style spring animation ───────────────────────

class _ReportIssueRoute extends PageRouteBuilder {
  _ReportIssueRoute()
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 550),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _AnimatedReportDialog(animation: animation);
          },
        );
}

// ─── Animated blurred backdrop + modal ───────────────────────────────────────

class _AnimatedReportDialog extends StatelessWidget {
  final Animation<double> animation;

  const _AnimatedReportDialog({required this.animation});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // ── Spring-style curved animation ──
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: const _OriginOSCurve(),
      reverseCurve: Curves.easeInQuart,
    );

    // ── Blur: 0 → 12 ──
    final blurAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // ── Background dim: transparent → semi-black ──
    final dimAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.black.withAlpha(90),
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // ── Scale: starts slightly smaller, springs to 1.0 ──
    final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnimation);

    // ── Fade ──
    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    // ── Slide up from bottom ──
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curvedAnimation);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurAnimation.value,
            sigmaY: blurAnimation.value,
          ),
          child: Container(
            color: dimAnimation.value,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // absorb taps on the modal itself
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: SlideTransition(
                        position: slideAnimation,
                        child: ScaleTransition(
                          scale: scaleAnimation,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 420,
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.90,
                            ),
                            child: const Material(
                              color: Colors.transparent,
                              child: ReportIssueModal(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Modal Widget ────────────────────────────────────────────────────────────

class ReportIssueModal extends StatefulWidget {
  const ReportIssueModal({super.key});

  @override
  State<ReportIssueModal> createState() => _ReportIssueModalState();
}

class _ReportIssueModalState extends State<ReportIssueModal> {
  // ── Controllers ──
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _scrollController = ScrollController();
  final _descriptionFocusNode = FocusNode();

  // ── State ──
  String? _selectedCategory;
  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _submitSuccess = false;
  String? _errorMessage;
  bool _isCategoryExpanded = false;

  // ── Geotag state ──
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  static const List<Map<String, dynamic>> _categories = [
    {'label': 'Road Damage', 'icon': Icons.remove_road},
    {'label': 'Infrastructure', 'icon': Icons.construction},
    {'label': 'Waste', 'icon': Icons.delete_outline},
    {'label': 'Lighting', 'icon': Icons.lightbulb_outline},
    {'label': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _descriptionFocusNode.addListener(_onDescriptionFocusChange);
  }

  void _onDescriptionFocusChange() {
    if (_descriptionFocusNode.hasFocus) {
      // Wait for the keyboard to appear, then scroll to the bottom
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _descriptionFocusNode.removeListener(_onDescriptionFocusChange);
    _descriptionFocusNode.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ── Image Picker ──
  Future<void> _pickFromGallery() async {
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (images.isNotEmpty) {
        setState(() {
          final remaining = 5 - _pickedImages.length;
          _pickedImages.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (image != null && _pickedImages.length < 5) {
        setState(() => _pickedImages.add(image));
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  void _removeImage(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  // ── Location helpers ──

  /// Opens the full-screen map picker and stores the result.
  Future<void> _openLocationPicker() async {
    final initial = _latitude != null && _longitude != null
        ? LatLng(_latitude!, _longitude!)
        : const LatLng(6.9271, 79.8612); // Default: Colombo, LK

    final result = await Navigator.of(context, rootNavigator: true)
        .push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLatLng: initial),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latLng.latitude;
        _longitude = result.latLng.longitude;
        _locationController.text = result.address;
      });
    }
  }

  /// Fetches the device's current GPS location and reverse geocodes it.
  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      final address =
          await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationController.text = address;
      });
    } on LocationServiceException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ── Submit Handler ──
  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);
    // Basic validation
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    if (title.isEmpty) {
      _showError('Please enter a title for your report.');
      return;
    }
    if (_selectedCategory == null) {
      _showError('Please select a category.');
      return;
    }
    if (location.isEmpty) {
      _showError('Please enter a location.');
      return;
    }
    if (description.isEmpty) {
      _showError('Please enter a description.');
      return;
    }
    if (_pickedImages.isEmpty) {
      _showError('Please add at least one photo.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('You must be signed in to submit a report.');
        return;
      }

      final complaint = Complaint(
        id: '', // will be assigned by Firestore
        title: title,
        description: description,
        category: _selectedCategory!,
        status: 'Pending',
        upvoteCount: 0,
        commentCount: 0,
        timestamp: DateTime.now(),
        authorId: user.uid,
        authorName: user.displayName ?? user.email ?? 'Anonymous',
        locationName: location,
        latitude: _latitude,
        longitude: _longitude,
      );

      final repo = RepositoryProvider.of(context);
      await repo.createComplaint(complaint, images: _pickedImages);

      if (!mounted) return;

      // Show success state
      setState(() {
        _isSubmitting = false;
        _submitSuccess = true;
      });

      // Auto-close after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully! 🎉'),
            backgroundColor: Color(0xFFF9A825),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        _showError('Failed to submit report. Please try again.');
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  // ── Colors ──
  static const _sheetBg = Color(0xFF141414);
  static const _fieldFill = Color(0xFF1E1E1E);
  static const _accentGreen = Color(0xFFF9A825);
  static const _borderColor = Color(0xFF2A2A2A);
  static const _textPrimary = Colors.white;
  static final _textSecondary = Colors.white.withAlpha(153);
  static final _hintColor = Colors.white.withAlpha(100);

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──
          _buildHeader(),

          if (_errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Scrollable content ──
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Evidence Photos ──
                  _sectionTitle('Evidence Photos'),
                  const SizedBox(height: 12),
                  _buildPhotoButtons(),
                  if (_pickedImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildImagePreviews(),
                  ],
                  const SizedBox(height: 24),

                  // ── Report Details ──
                  _sectionTitle('Report Details'),
                  const SizedBox(height: 12),

                  // Title
                  _buildTextField(
                    controller: _titleController,
                    hint: 'Title',
                    prefixIcon: Icons.edit_outlined,
                  ),
                  const SizedBox(height: 12),

                  // Category
                  _buildCategoryDropdown(),
                  const SizedBox(height: 12),

                  // Location
                  _buildLocationField(),
                  const SizedBox(height: 12),

                  // Description
                  _buildTextField(
                    controller: _descriptionController,
                    hint: 'Description',
                    prefixIcon: Icons.description_outlined,
                    maxLines: 4,
                    alignTop: true,
                    focusNode: _descriptionFocusNode,
                  ),
                  const SizedBox(height: 24),

                  // ── Animated Submit Button ──
                  _buildAnimatedSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Animated Submit Button ──
  Widget _buildAnimatedSubmitButton() {
    if (_submitSuccess) {
      // ── Success state ──
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'Report Sent! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSubmitting) {
      // ── Submitting state ──
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            color: _accentGreen.withAlpha(180),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Uploading…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Idle state ──
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.send_rounded, size: 20),
        label: const Text(
          'Submit Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: _handleSubmit,
      ),
    );
  }

  // ── Header: New Report ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borderColor),
        ),
      ),
      child: const Text(
        'New Report',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Section title ──
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ── Gallery + Camera buttons ──
  Widget _buildPhotoButtons() {
    return Row(
      children: [
        Expanded(
          child: _photoActionCard(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: _pickedImages.length >= 5 ? null : _pickFromGallery,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _photoActionCard(
            icon: Icons.camera_alt_outlined,
            label: 'Camera',
            onTap: _pickedImages.length >= 5 ? null : _pickFromCamera,
          ),
        ),
      ],
    );
  }

  Widget _photoActionCard({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: _fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: _accentGreen, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image preview row ──
  Widget _buildImagePreviews() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pickedImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = _pickedImages[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: _borderColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: kIsWeb
                      ? Image.network(file.path, fit: BoxFit.cover)
                      : Image.file(File(file.path), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Reusable text field ──
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    int maxLines = 1,
    Widget? suffixIcon,
    bool alignTop = false,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      focusNode: focusNode,
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _hintColor, fontSize: 14),
        filled: true,
        fillColor: _fieldFill,
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            top: alignTop ? 14 : 0,
          ),
          child: Icon(prefixIcon, color: _accentGreen, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accentGreen, width: 1.5),
        ),
      ),
    );
  }

  // ── Premium Location field ──
  Widget _buildLocationField() {
    final hasCoords = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable field that opens the map picker
        GestureDetector(
          onTap: _openLocationPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasCoords ? _accentGreen.withAlpha(100) : _borderColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasCoords
                      ? Icons.location_on_rounded
                      : Icons.location_on_outlined,
                  color: _accentGreen,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _locationController.text.isEmpty
                      ? Text(
                          'Tap to pick location on map',
                          style: TextStyle(color: _hintColor, fontSize: 14),
                        )
                      : Text(
                          _locationController.text,
                          style:
                              const TextStyle(color: _textPrimary, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 8),
                // GPS quick-fill button
                GestureDetector(
                  onTap: _isFetchingLocation ? null : _fetchCurrentLocation,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _accentGreen.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isFetchingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: _accentGreen, strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded,
                            color: _accentGreen, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Show coords chip when we have a pin location
        if (hasCoords)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
              style: TextStyle(
                color: Colors.white.withAlpha(60),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }

  // ── Category expandable dropdown ──
  Widget _buildCategoryDropdown() {
    final selectedCat = _categories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c!['label'] == _selectedCategory,
          orElse: () => null,
        );

    return Column(
      children: [
        // ── Tap target: shows selected category or placeholder ──
        GestureDetector(
          onTap: () =>
              setState(() => _isCategoryExpanded = !_isCategoryExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isCategoryExpanded ? _accentGreen : _borderColor,
                width: _isCategoryExpanded ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selectedCat != null
                      ? selectedCat['icon'] as IconData
                      : Icons.category_outlined,
                  color: _accentGreen,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCat != null
                        ? selectedCat['label'] as String
                        : 'Select Category',
                    style: TextStyle(
                      color: selectedCat != null ? _textPrimary : _hintColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isCategoryExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _hintColor,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Expandable category list ──
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: _categories.map((c) {
                final label = c['label'] as String;
                final icon = c['icon'] as IconData;
                final isSelected = _selectedCategory == label;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = label;
                        _isCategoryExpanded = false;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _accentGreen.withAlpha(40)
                            : _fieldFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? _accentGreen.withAlpha(120)
                              : _borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: _accentGreen, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? _accentGreen : _textPrimary,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: _accentGreen,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          crossFadeState: _isCategoryExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

// ─── OriginOS-style spring curve ─────────────────────────────────────────────
/// A custom curve that overshoots slightly then settles, mimicking the fluid
/// spring animation seen in OriginOS app launches.
class _OriginOSCurve extends Curve {
  const _OriginOSCurve();

  @override
  double transformInternal(double t) {
    // Spring-like formula: overshoots to ~1.02 then settles to 1.0
    // Using a damped spring: 1 - e^(-6t) * cos(2.5πt)
    final double dampedSpring =
        1.0 - math.exp(-6.0 * t) * math.cos(2.5 * math.pi * t);
    return dampedSpring;
  }
}
