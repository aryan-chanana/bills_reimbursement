import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/bill_model.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.1.3\:8080'
  );

  static Map<String, String> getAuthHeaders(String employeeId, String password) {
    String basicAuth = 'Basic ${base64Encode(utf8.encode('$employeeId:$password'))}';
    return {
      'Content-Type': 'application/json',
      'Authorization': basicAuth,
    };
  }

  // Users
  static Future<User?> login(String employeeId, String password) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$employeeId'),
      headers: getAuthHeaders(employeeId, password),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    else if (response.statusCode == 403) {
      throw Exception("User not permitted to fetch details");
    }
    else {
      // status code 404 or 401
      return null;
    }
  }

  static Future<bool> signUp(String employeeId, String name, String email, String password, bool isAdmin) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employeeId': int.tryParse(employeeId) ?? 0,
        'name': name,
        'email': email,
        'password': password,
        'admin': isAdmin,
      }),
    );
    return response.statusCode == 201;
  }

  static Future<List<User>> fetchUsers(String adminId, String adminPassword) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users'),
      headers: getAuthHeaders(adminId, adminPassword),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users. Status code: ${response.statusCode}');
    }
  }

  static Future<String> editUser({required String adminId, required String adminPassword, required int employeeIdToEdit, required String name, required String email, required bool isApproved}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/users/$employeeIdToEdit'),
      headers: getAuthHeaders(adminId, adminPassword),
      body: jsonEncode({
        'employeeId': employeeIdToEdit,
        'name': name,
        'email': email,
        'approved': isApproved,
      }),
    );
    if (response.statusCode == 200) return "true";
    return response.body;
  }

  static Future<bool> deleteUser({required String adminId,
                                  required String adminPassword,
                                  required int employeeIdToDelete}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/users/$employeeIdToDelete'),
      headers: getAuthHeaders(adminId, adminPassword),
    );
    return response.statusCode == 200;
  }

  // Bills
  static Future<bool> addBill({required int employeeId,
                               required String password,
                               required String reimbursementFor, String? description,
                               required double amount,
                               required DateTime date,
                               required File billImage, File? approvalMail, File? paymentProof}) async {

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/$employeeId/bills'),
    );

    String basicAuth = 'Basic ${base64Encode(utf8.encode('$employeeId:$password'))}';
    request.headers['Authorization'] = basicAuth;

    request.fields['reimbursementFor'] = reimbursementFor;
    if (description != null) request.fields['description'] = description;
    request.fields['amount'] = amount.toString();
    request.fields['date'] = DateFormat('yyyy-MM-dd').format(date);

    if (kIsWeb) {
      // For Web: Read as bytes and send
      request.files.add(http.MultipartFile.fromBytes(
        'billImage',
        await billImage.readAsBytes(),
        filename: billImage.path.split('/').last,
      ));
    } else {
      // For Mobile: Stream directly from the file path
      request.files.add(
        await http.MultipartFile.fromPath('billImage', billImage.path),
      );
    }
    if (approvalMail != null) {
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'approvalMail',
          await approvalMail.readAsBytes(),
          filename: approvalMail.path.split('/').last,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('approvalMail', approvalMail.path));
      }
    }
    if (paymentProof != null) {
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'paymentProof',
          await paymentProof.readAsBytes(),
          filename: paymentProof.path.split('/').last,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('paymentProof', paymentProof.path));
      }
    }

    var response = await request.send();

    return response.statusCode == 201;
  }

  static Future<List<Bill>> getMyBills(String employeeId, String password) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$employeeId/bills'),
        headers: ApiService.getAuthHeaders(employeeId, password)
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Bill.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load bills: ${response.body}');
    }
  }

  static Future<List<Bill>> getAllBillsAsAdmin(String employeeId, String password) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/bills'),
      headers: getAuthHeaders(employeeId, password),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Bill.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load all bills.');
    }
  }

  static Future<bool> changeStatus({required int employeeId, required String password, required int billId, String? status, String? remarks}) async {
    Map<String, dynamic> body = {};
    if (status != null) {
      body['status'] = status;
      body['remarks'] = remarks;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/admin/bills/$billId/status'),
      headers: getAuthHeaders(employeeId.toString(), password),
      body: jsonEncode(body),
    );

    print("response = " + response.statusCode.toString());


    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  static Future<bool> editBill({required String employeeId, required String password, required int billId, required String reimbursementFor, String? description, required double amount, required DateTime date, File? billImage, File? approvalMail, File? paymentProof}) async {
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/users/$employeeId/bills/$billId'),
    );

    String basicAuth = 'Basic ${base64Encode(utf8.encode('$employeeId:$password'))}';
    request.headers['Authorization'] = basicAuth;

    request.fields['reimbursementFor'] = reimbursementFor;
    if (description != null) request.fields['description'] = description;
    request.fields['amount'] = amount.toString();
    request.fields['date'] = DateFormat('yyyy-MM-dd').format(date);

    if (billImage != null) {
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'billImage',
          await billImage.readAsBytes(),
          filename: billImage.path.split('/').last,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('billImage', billImage.path));
      }
    }

    if (approvalMail != null) {
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'approvalMail',
          await approvalMail.readAsBytes(),
          filename: approvalMail.path.split('/').last,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('approvalMail', approvalMail.path));
      }
    }

    if (paymentProof != null) {
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'paymentProof',
          await paymentProof.readAsBytes(),
          filename: paymentProof.path.split('/').last,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('paymentProof', paymentProof.path));
      }
    }

    var response = await request.send();

    return response.statusCode == 200;
  }

  static Future<bool> deleteBill({required String employeeId,
                                  required String password,
                                  required int billId,}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$employeeId/bills/$billId'),
      headers: getAuthHeaders(employeeId, password),
    );
    return response.statusCode == 200;
  }

  // OTP
  static Future<String> sendOtp(String employeeId, String email, bool signUp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$employeeId/send-otp'),
      body: {
        'email': email,
        'signUp': signUp.toString(),
      },
    );
    return response.body;
  }

  static Future<bool> verifyOtp(String employeeId, String otp, bool signUp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$employeeId/verify-otp'),
      body: {
        'otp': otp,
        'signUp': signUp.toString(),
      },
    );
    return response.statusCode == 200;
  }

  static Future<bool> resetPassword(String employeeId, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$employeeId/update-password'),
      body: {
        'newPassword': newPassword,
      },
    );
    return response.statusCode == 200;
  }
}