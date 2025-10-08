class Bill {
  final int billId;
  final int employeeId;
  final String reimbursementFor;
  final double amount;
  final DateTime date;
  final String billImagePath;
  final String status;

  Bill({
    required this.billId,
    required this.employeeId,
    required this.reimbursementFor,
    required this.amount,
    required this.date,
    required this.billImagePath,
    required this.status,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      billId: json['billId'],
      reimbursementFor: json['reimbursementFor'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
      billImagePath: json['billImagePath'],
      status: json['status'],
      employeeId: json['employeeId'],
    );
  }
}