import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ─── Helper: show the modal ─────────────────────────────────────────────────
/// Call this from anywhere (e.g. FAB onPressed) to display the Report Issue
/// dialog with a blurred background.
void showReportIssueModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withAlpha(80),
    builder: (_) => const _BlurredReportDialog(),
  );
}

// ─── Blurred backdrop wrapper ────────────────────────────────────────────────
class _BlurredReportDialog extends StatelessWidget {
  const _BlurredReportDialog();

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: const Material(
            color: Colors.transparent,
            child: ReportIssueModal(),
          ),
        ),
      ),
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

  // ── State ──
  String? _selectedCategory;
  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  static const List<Map<String, dynamic>> _categories = [
    {'label': 'Pothole', 'icon': Icons.warning_amber_rounded},
    {'label': 'Road Damage', 'icon': Icons.remove_road},
    {'label': 'Infrastructure', 'icon': Icons.construction},
    {'label': 'Waste', 'icon': Icons.delete_outline},
    {'label': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
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

  // ── Colors ──
  static const _sheetBg = Color(0xFF141414);
  static const _fieldFill = Color(0xFF1E1E1E);
  static const _accentGreen = Color(0xFF4CAF50);
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

          // ── Scrollable content ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Evidence Photos ──
                  _sectionTitle('📷 Evidence Photos'),
                  const SizedBox(height: 12),
                  _buildPhotoButtons(),
                  if (_pickedImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildImagePreviews(),
                  ],
                  const SizedBox(height: 24),

                  // ── Report Details ──
                  _sectionTitle('📋 Report Details'),
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
                  _buildTextField(
                    controller: _locationController,
                    hint: 'Location',
                    prefixIcon: Icons.location_on_outlined,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.my_location,
                          color: _accentGreen, size: 20),
                      onPressed: () {
                        // TODO: integrate geolocator to auto‑fill location
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  _buildTextField(
                    controller: _descriptionController,
                    hint: 'Description',
                    prefixIcon: Icons.description_outlined,
                    maxLines: 4,
                    alignTop: true,
                  ),
                  const SizedBox(height: 24),

                  // ── Submit Button ──
                  SizedBox(
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
                      onPressed: () {
                        // TODO: handle submission
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header: [X]  New Report  [Submit] ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borderColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: _textPrimary, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'New Report',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: handle submission
              Navigator.pop(context);
            },
            child: const Text(
              'Submit',
              style: TextStyle(
                color: _accentGreen,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
  }) {
    return TextFormField(
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

  // ── Category dropdown ──
  Widget _buildCategoryDropdown() {
    final selectedCat = _categories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c!['label'] == _selectedCategory,
          orElse: () => null,
        );

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      dropdownColor: const Color(0xFF2A2A2A),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: _hintColor),
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: _fieldFill,
        prefixIcon: Icon(
          selectedCat != null
              ? selectedCat['icon'] as IconData
              : Icons.category_outlined,
          color: _accentGreen,
          size: 20,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
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
      hint: Text(
        'Category',
        style: TextStyle(color: _hintColor, fontSize: 14),
      ),
      items: _categories
          .map(
            (c) => DropdownMenuItem(
              value: c['label'] as String,
              child: Row(
                children: [
                  Icon(c['icon'] as IconData, color: _accentGreen, size: 18),
                  const SizedBox(width: 10),
                  Text(c['label'] as String),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedCategory = value),
    );
  }
}
