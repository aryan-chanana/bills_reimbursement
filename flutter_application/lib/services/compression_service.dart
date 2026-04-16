import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CompressionService {
  // Max dimension (width or height). Images larger than this are scaled down.
  static const int _maxDimension = 1920;
  // JPEG quality 0–100. 72 gives a good size/quality balance for documents.
  static const int _quality = 72;

  /// Compresses an image file and returns the compressed [File].
  /// PDFs are returned unchanged.
  ///
  /// Uses [compressWithList] (byte-based) instead of [compressAndGetFile]
  /// (path-based) to reliably handle camera images, content URIs, and
  /// HEIC files across all Android/iOS sources.
  static Future<File> compressFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();

    // PDFs cannot be compressed with this library — return as-is
    if (ext == '.pdf') return file;

    try {
      final Uint8List originalBytes = await file.readAsBytes();

      final Uint8List compressedBytes = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _quality,
        format: CompressFormat.jpeg,
      );

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/${timestamp}_compressed.jpg');
      await tempFile.writeAsBytes(compressedBytes);
      return tempFile;
    } catch (_) {
      // Fallback: return original if compression fails for any reason
      return file;
    }
  }

  /// Convenience: compress a nullable [File], returning null if input is null.
  static Future<File?> compressNullable(File? file) async {
    if (file == null) return null;
    return compressFile(file);
  }
}
