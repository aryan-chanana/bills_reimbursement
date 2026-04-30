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
  /// compressed artifact. PDFs and web uploads are returned unchanged — the
  /// former because this library can't compress them, the latter because
  /// `dart:io` isn't usable in the browser.
  static Future<PlatformFile> compressFile(PlatformFile file) async {
    final ext = p.extension(file.name).toLowerCase();
    if (ext == '.pdf') return file;
    if (kIsWeb) return file;
    if (file.path == null) return file;

    try {
      final Uint8List originalBytes = await File(file.path!).readAsBytes();

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

      return PlatformFile(
        name: '${timestamp}_compressed.jpg',
        size: compressedBytes.length,
        path: tempFile.path,
      );
    } catch (_) {
      return file;
    }
  }

  static Future<PlatformFile?> compressNullable(PlatformFile? file) async {
    if (file == null) return null;
    return compressFile(file);
  }
}
