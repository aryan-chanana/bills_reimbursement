import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CompressionService {
  static const int _maxDimension = 1920;
  static const int _quality = 72;

  /// Compresses an image [PlatformFile] and returns a new one pointing at the
  /// compressed artifact. PDFs are returned unchanged. Works on both mobile
  /// (writes a temp file so multipart streaming + offline queue keep working)
  /// and web (keeps bytes in memory because there's no filesystem).
  static Future<PlatformFile> compressFile(PlatformFile file) async {
    final ext = p.extension(file.name).toLowerCase();
    if (ext == '.pdf') return file;

    try {
      Uint8List? input = file.bytes;
      if (input == null && !kIsWeb && file.path != null) {
        input = await File(file.path!).readAsBytes();
      }
      if (input == null || input.isEmpty) return file;

      final Uint8List compressed = await FlutterImageCompress.compressWithList(
        input,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _quality,
        format: CompressFormat.jpeg,
      );

      final ts = DateTime.now().millisecondsSinceEpoch;
      final outName = '${ts}_compressed.jpg';

      if (kIsWeb) {
        return PlatformFile(name: outName, size: compressed.length, bytes: compressed);
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$outName');
      await tempFile.writeAsBytes(compressed);

      return PlatformFile(name: outName, size: compressed.length, path: tempFile.path);
    } catch (_) {
      return file;
    }
  }

  static Future<PlatformFile?> compressNullable(PlatformFile? file) async {
    if (file == null) return null;
    return compressFile(file);
  }
}
