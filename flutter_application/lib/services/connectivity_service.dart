import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class ConnectivityService {
  static Future<bool> hasInternet() async {
    try {
      print("has internet entered");
      if (kIsWeb) {
        print("returning true from here");
        return true;
      }
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty;
    } catch (e) {
      print(e.toString());
      return false;
    }
  }

  static Future<bool> isServerAlive() async {
    print("Entered is server alive");
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
