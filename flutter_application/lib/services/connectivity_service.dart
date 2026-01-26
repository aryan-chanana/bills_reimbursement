import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class ConnectivityService {
  static Future<bool> hasInternet() async {
    if (kIsWeb) {
      return true;
    }

    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isServerAlive() async {
    try {
      final client = http.Client();
      final request = http.Request(
        "GET",
        Uri.parse(ApiService.baseUrl + "/ping"),
      );
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBackendAvailable() async {
    return await hasInternet() && await isServerAlive();
  }
}