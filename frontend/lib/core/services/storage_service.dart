import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // kIsWeb is true when running in a browser
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// StorageService handles uploading images to Firebase Storage.
// Firebase Storage is a cloud file system — we store complaint evidence
// photos and profile pictures there. Once uploaded, each file gets a
// permanent download URL that we save in the Firestore complaint document.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Uploads a single image file to Firebase Storage and returns its download URL.
  // The file path in Storage is: complaints/{complaintId}/{timestamp}_{filename}
  // Using a timestamp prefix ensures filenames are unique even if two users
  // upload a file with the same name at the same time.
  Future<String> uploadComplaintImage(
    String complaintId, // the Firestore document ID of the complaint
    XFile image,        // the image file selected by the user
  ) async {
    // Build a unique filename using the current time in milliseconds
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

    // Build the storage reference — this is the path in the Storage bucket
    final ref = _storage
        .ref()
        .child('complaints')   // top-level folder
        .child(complaintId)    // one subfolder per complaint
        .child(fileName);      // unique file name

    UploadTask uploadTask;

    if (kIsWeb) {
      // Web browsers can't access the file system directly, so we read
      // the image as raw bytes and upload that instead
      final bytes = await image.readAsBytes();
      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'), // tell Storage the file type
      );
    } else {
      // On Android/iOS we can upload the file directly using its path on disk
      uploadTask = ref.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }

    // Wait for the upload to finish, then get the permanent HTTPS download URL
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Uploads multiple images one by one and returns a list of their download URLs.
  // Sequential upload is used (not parallel) to avoid overloading the network.
  Future<List<String>> uploadMultipleImages(
    String complaintId,
    List<XFile> images,
  ) async {
    final List<String> urls = [];

    for (final image in images) {
      final url = await uploadComplaintImage(complaintId, image);
      urls.add(url); // collect each URL as we go
    }

    return urls; // list of download URLs in the same order as the input images
  }
}
