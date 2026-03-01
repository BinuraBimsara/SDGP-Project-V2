import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Service for uploading images to Firebase Storage.
///
/// Images are stored under `complaints/{complaintId}/` with unique
/// timestamped filenames. Returns download URLs for the uploaded files.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a single complaint image and return its download URL.
  ///
  /// Path: `complaints/{complaintId}/{timestamp}_{filename}`
  Future<String> uploadComplaintImage(
    String complaintId,
    XFile image,
  ) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
    final ref = _storage
        .ref()
        .child('complaints')
        .child(complaintId)
        .child(fileName);

    UploadTask uploadTask;

    if (kIsWeb) {
      // Web: use putData with bytes
      final bytes = await image.readAsBytes();
      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      // Mobile: use putFile
      uploadTask = ref.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload multiple complaint images and return their download URLs.
  Future<List<String>> uploadMultipleImages(
    String complaintId,
    List<XFile> images,
  ) async {
    final List<String> urls = [];

    for (final image in images) {
      final url = await uploadComplaintImage(complaintId, image);
      urls.add(url);
    }

    return urls;
  }
}
