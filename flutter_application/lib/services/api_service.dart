import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../models/bill_model.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.5:8080';

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

  static Future<bool> signUp(String employeeId, String name, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employeeId': int.tryParse(employeeId) ?? 0,
        'name': name,
        'password': password,
        'admin': false,
      }),
    );
    return response.statusCode == 201;
  }

  static Future<List<User>> fetchUsers(String adminId, String adminPassword) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: getAuthHeaders(adminId, adminPassword),
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users. Status code: ${response.statusCode}');
    }
  }

  static Future<bool> editUser({required String adminId,
                                required String adminPassword,
                                required int employeeIdToEdit,
                                required String newName,
                                required String newPassword}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$employeeIdToEdit'),
      headers: getAuthHeaders(adminId, adminPassword),
      body: jsonEncode({
        'employeeId': employeeIdToEdit,
        'name': newName,
        'password': newPassword,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deleteUser({required String adminId,
                                  required String adminPassword,
                                  required int employeeIdToDelete}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$employeeIdToDelete'),
      headers: getAuthHeaders(adminId, adminPassword),
    );
    return response.statusCode == 200;
  }

  // Bills
  static Future<bool> addBill({required int employeeId,
                               required String password,
                               required String reimbursementFor,
                               required double amount,
                               required DateTime date,
                               required File billImage}) async {

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/$employeeId/bills'),
    );

    String basicAuth = 'Basic ${base64Encode(utf8.encode('$employeeId:$password'))}';
    request.headers['Authorization'] = basicAuth;

    request.fields['reimbursementFor'] = reimbursementFor;
    request.fields['amount'] = amount.toString();
    request.fields['date'] = DateFormat('yyyy-MM-dd').format(date);

    request.files.add(
      await http.MultipartFile.fromPath('billImage', billImage.path),
    );

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
      Uri.parse('$baseUrl/bills'),
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
      Uri.parse('$baseUrl/bills/$billId/status'),
      headers: getAuthHeaders(employeeId.toString(), password),
      body: jsonEncode(body),
    );


    if (response.statusCode == 200) {
      return true;
    } else {
      debugPrint('Failed to edit bill: ${response.statusCode} ${response.body}');
      return false;
    }
  }

  static Future<bool> editBill({required String employeeId, required String password, required int billId, required String reimbursementFor, required double amount, required DateTime date, File? billImage}) async {
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/users/$employeeId/bills/$billId'),
    );

    String basicAuth = 'Basic ${base64Encode(utf8.encode('$employeeId:$password'))}';
    request.headers['Authorization'] = basicAuth;

    request.fields['reimbursementFor'] = reimbursementFor;
    request.fields['amount'] = amount.toString();
    request.fields['date'] = DateFormat('yyyy-MM-dd').format(date);

    if (billImage != null) {
      request.files.add(await http.MultipartFile.fromPath('billImage', billImage.path),
      );
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
}