import 'dart:typed_data';
import 'dart:html' as html;

class BillDownloadService {
  static Future<void> downloadBytes(
      Uint8List bytes, String fileName, String mimeType) async {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  /// Opens [bytes] in a new browser tab. Used for inline PDF viewing.
  /// The blob URL is intentionally not revoked here — the new tab still
  /// needs it. Browsers GC blob URLs once the tab unloads.
  static Future<void> openBytes(
      Uint8List bytes, String fileName, String mimeType) async {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }
}
