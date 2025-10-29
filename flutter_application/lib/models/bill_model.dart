class Bill {
  final int billId;
  final int employeeId;
  final String reimbursementFor;
  final double amount;
  final DateTime date;
  final String billImagePath;
  final String status;
  final String? remarks;
  final DateTime? createdAt;

  Bill({
    required this.billId,
    required this.employeeId,
    required this.reimbursementFor,
    required this.amount,
    required this.date,
    required this.billImagePath,
    this.remarks,
    required this.status,
    this.createdAt
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      billId: json['billId'],
      reimbursementFor: json['reimbursementFor'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
      billImagePath: json['billImagePath'],
      status: json['status'],
      remarks: json['remarks']?.toString(),
      employeeId: json['employeeId'],
      createdAt: DateTime.parse(json['createdAt'])
    );
  }
}