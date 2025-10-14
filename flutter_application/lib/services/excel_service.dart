import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';

class ExcelService {
  static final ExcelService instance = ExcelService._init();
  ExcelService._init();

  Future<void> generateBillsReport(List<Bill> bills, List<User> employees) async {
    final excel = Excel.createExcel();
    final sheet = excel['BillsReport'];
    excel.rename('Sheet1', 'BillsReport');

    List<String> headers = [
      'S.No', 'Employee ID', 'Employee Name', 'Reimbursement For', 'Amount (₹)',
      'Date', 'Status', 'Submitted Date',
    ];
    sheet.appendRow(headers);

    for (int i = 0; i < bills.length; i++) {
      final bill = bills[i];
      final employee = employees.firstWhere(
            (emp) => emp.employeeId == bill.employeeId,
        orElse: () => User(employeeId: bill.employeeId, name: 'Unknown', password: '')
      );

      List<dynamic> rowData = [
        i + 1,
        bill.employeeId,
        employee.name,
        bill.reimbursementFor ?? 'N/A',
        bill.amount ?? 0.0,
        bill.date != null ? DateFormat('dd/MM/yyyy').format(bill.date!) : 'N/A',
        bill.status.toUpperCase(),
      ];
      sheet.appendRow(rowData);
    }

    final fileBytes = excel.save();

    if (fileBytes != null) {
      String fileName = 'Bills_Report_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}';
      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }
}