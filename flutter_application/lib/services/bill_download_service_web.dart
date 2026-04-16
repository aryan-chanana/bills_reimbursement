import 'dart:typed_data';
import 'dart:html' as html;

class BillDownloadService {
  static Future<void> downloadBytes(
      Uint8List bytes, String fileName, String mimeType) async {

    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);


    html.Url.revokeObjectUrl(url);
  }
}