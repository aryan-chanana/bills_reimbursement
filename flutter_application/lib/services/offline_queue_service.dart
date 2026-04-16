import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineQueueService {
  static const String _key = "offline_bills";

  static Future<void> queueBill({
    required String category,
    required double amount,
    required DateTime date,
    required XFile image,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> queued = prefs.getStringList(_key) ?? [];

    queued.add(jsonEncode({
      "category": category,
      "amount": amount,
      "date": date.toIso8601String(),
      "imagePath": image.path,
    }));

    await prefs.setStringList(_key, queued);
  }

  static Future<void> trySubmitQueuedBills(int employeeId, String password) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queued = prefs.getStringList(_key) ?? [];

    if (queued.isEmpty) return;

    List<String> remaining = [];

    for (String raw in queued) {
      final data = jsonDecode(raw);

      bool success = await ApiService.addBill(
        employeeId: employeeId,
        password: password,
        reimbursementFor: data["category"],
        description: data["description"],
        amount: data["amount"],
        date: DateTime.parse(data["date"]),
        billImage: data["imagePath"],
        approvalMail: data["approvalMail"],
        paymentProof: data["paymentProof"]
      );

      if (!success) {
        remaining.add(raw);
      }
    }
    await prefs.setStringList(_key, remaining);
  }
}
