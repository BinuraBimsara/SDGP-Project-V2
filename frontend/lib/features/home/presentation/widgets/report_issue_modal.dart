import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ─── Helper: show the modal ─────────────────────────────────────────────────
/// Call this from anywhere (e.g. FAB onPressed) to display the Report Issue
/// modal bottom sheet.
void showReportIssueModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ReportIssueModal(),
  );
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
  final _nameController = TextEditingController();

  // ── State ──
  String? _selectedCategory;
  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  static const List<String> _categories = [
    'Road',
    'Infrastructure',
    'Waste',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ── Image Picker ──
  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (images.isNotEmpty) {
        setState(() {
          // Cap at 5 images total
          final remaining = 5 - _pickedImages.length;
          _pickedImages.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  void _removeImage(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Theme-aware colors ──
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final fieldFill =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white.withAlpha(153) : Colors.black54;
    final hintColor = isDark ? Colors.white.withAlpha(100) : Colors.black38;
    final borderColor =
        isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(30);
    const accentGreen = Color(0xFF4CAF50);

    return Container(
      // Take up to 92% of screen height
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(51) : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Scrollable content ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  _buildHeader(textPrimary, textSecondary),
                  const SizedBox(height: 20),

                  // ── Issue Title ──
                  _label('Issue Title', textPrimary),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _titleController,
                    hint: 'Brief description of the issue',
                    fieldFill: fieldFill,
                    hintColor: hintColor,
                    textColor: textPrimary,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 16),

                  // ── Category ──
                  _label('Category', textPrimary),
                  const SizedBox(height: 8),
                  _buildCategoryDropdown(
                    fieldFill: fieldFill,
                    hintColor: hintColor,
                    textColor: textPrimary,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 16),

                  // ── Description ──
                  _label('Description', textPrimary),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _descriptionController,
                    hint: 'Provide detailed information...',
                    maxLines: 4,
                    fieldFill: fieldFill,
                    hintColor: hintColor,
                    textColor: textPrimary,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Be as detailed as possible to help resolve the issue quickly',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // ── Location ──
                  _label('Location', textPrimary),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _locationController,
                    hint: 'Street address or coordinates',
                    fieldFill: fieldFill,
                    hintColor: hintColor,
                    textColor: textPrimary,
                    borderColor: borderColor,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.location_on, color: accentGreen),
                      onPressed: () {
                        // TODO: integrate geolocator to auto‑fill location
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Click the pin icon to automatically use your current location',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 20),

                  // ── Photos (Optional) ──
                  _label('Photos (Optional)', textPrimary),
                  const SizedBox(height: 10),
                  _buildUploadButton(accentGreen),
                  const SizedBox(height: 8),
                  Text(
                    'PNG, JPG, GIF up to 10MB (Max 5 images)',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  if (_pickedImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildImagePreviews(borderColor),
                  ],
                  const SizedBox(height: 16),

                  // ── Your Name ──
                  _label('Your Name', textPrimary),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _nameController,
                    hint: 'Enter your name',
                    fieldFill: fieldFill,
                    hintColor: hintColor,
                    textColor: textPrimary,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 24),

                  // ── Submit ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // TODO: handle submission
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  // ── Header ──
  Widget _buildHeader(Color textPrimary, Color textSecondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Report New Issue',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please provide details about the issue you are reporting.',
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: textPrimary, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  // ── Section label ──
  Widget _label(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ── Reusable text field ──
  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    required Color fieldFill,
    required Color hintColor,
    required Color textColor,
    required Color borderColor,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor, fontSize: 14),
        filled: true,
        fillColor: fieldFill,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
        ),
      ),
    );
  }

  // ── Category dropdown ──
  Widget _buildCategoryDropdown({
    required Color fieldFill,
    required Color hintColor,
    required Color textColor,
    required Color borderColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
        ),
      ),
      hint: Text(
        'Select a category',
        style: TextStyle(color: hintColor, fontSize: 14),
      ),
      items: _categories
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(c),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedCategory = value),
    );
  }

  // ── Upload button ──
  Widget _buildUploadButton(Color accent) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.cloud_upload_outlined, size: 22),
        label: const Text(
          'Upload Photos',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: _pickedImages.length >= 5 ? null : _pickImages,
      ),
    );
  }

  // ── Image preview row ──
  Widget _buildImagePreviews(Color borderColor) {
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
                    border: Border.all(color: borderColor),
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
}
