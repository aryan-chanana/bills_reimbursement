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

    // Add headers (no changes here)
    List<String> headers = [
      'S.No', 'Employee ID', 'Employee Name', 'Reimbursement For', 'Amount (₹)',
      'Date', 'Status', 'Submitted Date',
    ];
    sheet.appendRow(headers); // A simpler way to add the header row

    // Add data rows with null safety
    for (int i = 0; i < bills.length; i++) {
      final bill = bills[i];
      final employee = employees.firstWhere(
            (emp) => emp.employeeId == bill.employeeId,
        orElse: () => User(employeeId: bill.employeeId, name: 'Unknown', password: '')
      );

      // Provide fallback values for any potentially null data
      List<dynamic> rowData = [
        i + 1,
        bill.employeeId,
        employee.name,
        bill.reimbursementFor ?? 'N/A',
        bill.amount ?? 0.0, // <-- Handles null amount
        bill.date != null ? DateFormat('dd/MM/yyyy').format(bill.date!) : 'N/A', // <-- Handles null date
        bill.status.toUpperCase(),
      ];
      sheet.appendRow(rowData);
    }

    // NOTE: For brevity, I've removed the cell styling and summary sheet logic.
    // You should apply the same null-safety logic (e.g., bill.amount ?? 0.0) to your
    // summary calculations as well. For example:
    // bills.fold(0.0, (sum, bill) => sum + (bill.amount ?? 0.0))

    final fileBytes = excel.save();

    if (fileBytes != null) {
      String fileName = 'Bills_Report_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}';
      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        fileExtension: 'xlsx', // <-- Correct new parameter
        mimeType: MimeType.microsoftExcel,
      );
    }
  }
}