import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';

class ExcelService {
  static final ExcelService instance = ExcelService._init();
  ExcelService._init();

  Future<void> generateBillsReport(
      List<Bill> bills,
      List<User> employees,
      ) async {

    var excel = Excel.createExcel();
    final sheet = excel['BillsReport'];

    sheet.appendRow([
      'S.No',
      'Employee ID',
      'Employee Name',
      'Reimbursement For',
      'Amount (₹)',
      'Date',
      'Status',
      'Submitted Date',
    ]);

    for (int i = 0; i < bills.length; i++) {
      final bill = bills[i];
      final employee = employees.firstWhere(
            (e) => e.employeeId == bill.employeeId,
        orElse: () => User(
          employeeId: bill.employeeId,
          name: 'Unknown',
          password: '',
        ),
      );
      sheet.appendRow([
        i + 1,
        bill.employeeId,
        employee.name,
        bill.reimbursementFor,
        bill.amount,
        DateFormat('dd/MM/yyyy').format(bill.date),
        bill.status.toUpperCase(),
        DateFormat('dd/MM/yyyy').format(bill.createdAt!),
      ]);
    }

    try {
      excel.delete('Sheet1');
      print("Deleted successfully");
    }
    catch (e) {
      print("Not deleted :: $e");
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final fileName =
        'Bills_Report_${DateFormat('dd-MM-yyyy').format(DateTime.now())}';

    await FileSaver.instance.saveAs(
      name: fileName,
      bytes: Uint8List.fromList(fileBytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }
}