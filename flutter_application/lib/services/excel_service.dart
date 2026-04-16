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
    var excel = Excel.createExcel();
    final sheet = excel['BillsReport'];

    // ── Header row ────────────────────────────────────────────────
    sheet.appendRow([
      'S.No',
      'Employee ID',
      'Employee Name',
      'Category',
      'Description',
      'Amount (₹)',
      'Bill Date',
      'Submitted Date',
      'Status',
      'Remarks',
      'Bill Receipt',
      'Approval Mail',
      'Payment Proof',
    ]);

    // ── Data rows ─────────────────────────────────────────────────
    for (int i = 0; i < bills.length; i++) {
      final bill = bills[i];
      final employee = employees.firstWhere(
        (emp) => emp.employeeId == bill.employeeId,
        orElse: () => User(employeeId: bill.employeeId, name: 'Unknown', password: ''),
      );

      sheet.appendRow([
        i + 1,                                                          // S.No
        bill.employeeId,                                                // Employee ID
        employee.name,                                                  // Employee Name
        bill.reimbursementFor,                                          // Category
        bill.billDescription ?? '—',                                    // Description
        bill.amount,                                                    // Amount
        DateFormat('dd/MM/yyyy').format(bill.date),                     // Bill Date
        bill.createdAt != null
            ? DateFormat('dd/MM/yyyy').format(bill.createdAt!)
            : '—',                                                      // Submitted Date
        bill.status.toUpperCase(),                                      // Status
        bill.remarks ?? '—',                                            // Remarks
        _docLabel(bill.billImagePath),                                  // Bill Receipt
        _docLabel(bill.approvalMailPath),                               // Approval Mail
        _docLabel(bill.paymentProofPath),                               // Payment Proof
      ]);
    }

    // Delete the default empty sheet Excel creates
    try {
      excel.delete('Sheet1');
    } catch (_) {}

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final fileName = 'Bills_Report_${DateFormat('dd-MM-yyyy').format(DateTime.now())}';
      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }

  /// Returns the filename from a stored path, or '—' if absent.
  static String _docLabel(String? path) {
    if (path == null || path.isEmpty) return '—';
    return path.split('/').last;
  }
}
