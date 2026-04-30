import 'dart:io';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BillDownloadService {
  /// Saves [bytes] to a user-chosen location.
  ///
  /// Android: opens the SAF "Save as" picker (defaults to Downloads).
  /// iOS: opens the system share sheet, which includes "Save to Files".
  ///
  /// Returns `true` if the user completed the save, `false` if they
  /// cancelled the picker. Throws if the underlying save errors out.
  static Future<bool> downloadBytes(
      Uint8List bytes, String fileName, String mimeType) async {
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    final base = p.basenameWithoutExtension(fileName);
    final saved = await FileSaver.instance.saveAs(
      name: base,
      bytes: bytes,
      fileExtension: ext,
      mimeType: _mimeTypeFor(mimeType),
    );
    return saved != null && saved.isNotEmpty;
  }

  /// Writes [bytes] to a temp file and asks the OS to open it with whichever
  /// app handles [mimeType] (PDF viewer, image viewer, etc.).
  static Future<void> openBytes(
      Uint8List bytes, String fileName, String mimeType) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);
    await OpenFilex.open(tempFile.path);
  }

  static MimeType _mimeTypeFor(String raw) {
    switch (raw) {
      case 'image/jpeg': return MimeType.jpeg;
      case 'image/png':  return MimeType.png;
      case 'application/pdf': return MimeType.pdf;
      default: return MimeType.other;
    }
  }
}
