import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// In-memory cache for bill files (images, PDFs) fetched from the backend.
/// Lives for the process lifetime; cleared only on explicit refresh.
class BillFileCache {
  BillFileCache._();
  static final instance = BillFileCache._();

  final Map<String, Uint8List> _bytes = {};

  Future<Uint8List?> fetch(
    String filePath, {
    required Map<String, String> headers,
  }) async {
    final cached = _bytes[filePath];
    if (cached != null) return cached;

    final resp = await http.get(
      Uri.parse('${ApiService.baseUrl}/files/$filePath'),
      headers: headers,
    );
    if (resp.statusCode != 200) return null;
    _bytes[filePath] = resp.bodyBytes;
    return resp.bodyBytes;
  }

  void clear() => _bytes.clear();
}
