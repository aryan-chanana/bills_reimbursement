import 'dart:io';

class BillDownloadService {
  static Future<void> downloadBytes(
      List<int> bytes,
      String fileName,
      String mime,
      ) async {
    final dir = Directory('/storage/emulated/0/Download');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
  }
}