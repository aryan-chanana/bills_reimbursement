class Bill {
  final int billId;
  final int employeeId;
  final String reimbursementFor;
  final String? billDescription;
  final double amount;
  final DateTime date;
  final String? approvalMailPath;
  final String billImagePath;
  final String? paymentProofPath;
  final String status;
  final String? remarks;
  final DateTime? createdAt;

  Bill({
    required this.billId,
    required this.employeeId,
    required this.reimbursementFor,
    this.billDescription,
    required this.amount,
    required this.date,
    this.approvalMailPath,
    required this.billImagePath,
    this.paymentProofPath,
    required this.status,
    this.remarks,
    this.createdAt
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      billId: json['billId'],
      reimbursementFor: json['reimbursementFor'],
      billDescription: json['billDescription'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
      approvalMailPath: json['approvalMailPath'],
      billImagePath: json['billImagePath'],
      paymentProofPath: json['paymentProofPath'],
      status: json['status'],
      remarks: json['remarks']?.toString(),
      employeeId: json['employeeId'],
      createdAt: DateTime.parse(json['createdAt'])
    );
  }
}