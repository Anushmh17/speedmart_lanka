import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageUploadService {
  StorageUploadService._();
  static final StorageUploadService instance = StorageUploadService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a local file to Firebase Storage and returns the download URL.
  /// [storagePath] e.g. `profile_images/user-123.jpg`
  /// [quality] JPEG quality 1–100 (default 80).
  Future<String> uploadImage(String localPath, String storagePath,
      {int quality = 80}) async {
    final file = File(localPath);
    if (!file.existsSync()) throw Exception('Image file not found: $localPath');

    final compressed = await _compress(file, quality);
    final uploadFile = compressed ?? file;

    final ref = _storage.ref().child(storagePath);
    final task = await ref.putFile(
      uploadFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await task.ref.getDownloadURL();

    if (compressed != null) compressed.deleteSync();
    return url;
  }

  Future<File?> _compress(File file, int quality) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_c.jpg');
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      return result == null ? null : File(result.path);
    } catch (e) {
      debugPrint('[Storage] Compression failed, uploading original: $e');
      return null;
    }
  }

  /// Uploads multiple local paths, skipping any that are already network URLs.
  /// Returns a list of download URLs in the same order.
  Future<List<String>> uploadImages(
      List<String> paths, String Function(int index) storagePathBuilder) async {
    final results = <String>[];
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (path.startsWith('http://') || path.startsWith('https://')) {
        results.add(path); // already uploaded
      } else {
        final url = await uploadImage(path, storagePathBuilder(i));
        results.add(url);
      }
    }
    return results;
  }

  /// Deletes a file from Firebase Storage by its download URL.
  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('[Storage] Failed to delete $downloadUrl: $e');
    }
  }
}
