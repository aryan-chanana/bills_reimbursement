import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';

class ExcelService {
  static final ExcelService instance = ExcelService._init();

  ExcelService._init();

  Future<void> generateBillsReport(List<Bill> bills,
      List<User> employees) async {
    var excel = Excel.createExcel();

    // String defaultSheet = excel.tables.keys.first;
    // print("Default sheet name: $defaultSheet");

    // // Rename it to BillsReport
    // try {
    //   excel.rename(defaultSheet, 'BillsReport');
    //   print("Renamed successfully");
    // } catch (e) {
    //   print("Rename error: $e");
    // }

    final sheet = excel['BillsReport'];

    List<String> headers = [
      'S.No', 'Employee ID', 'Employee Name', 'Reimbursement For', 'Amount (₹)',
      'Date', 'Status', 'Submitted Date',
    ];
    sheet.appendRow(headers);

    for (int i = 0; i < bills.length; i++) {
      final bill = bills[i];
      final employee = employees.firstWhere(
              (emp) => emp.employeeId == bill.employeeId,
          orElse: () =>
              User(employeeId: bill.employeeId, name: 'Unknown', password: '')
      );

      List<dynamic> rowData = [
        i + 1,
        bill.employeeId,
        employee.name,
        bill.reimbursementFor,
        bill.amount,
        DateFormat('dd/MM/yyyy').format(bill.date),
        bill.status.toUpperCase(),
      ];
      sheet.appendRow(rowData);
    }

    try {
      // Unsupported operation: Cannot remove from an unmodifiable list
      // look what caused above statement in delete method
      // somewhere in delete or rename method, code is break hence returning above method
      // and we going in catch clause but until then our sheet has already been deleted/renamed
      excel.delete('Sheet1');
      print("Deleted successfully");
    }
    catch (e) {
      print("Not deleted :: $e");
    }

    final fileBytes = excel.save();

    if (fileBytes != null) {
      String fileName = 'Bills_Report_${DateFormat('ddMMyyyy_HHmmss').format(
          DateTime.now())}';
      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }
}