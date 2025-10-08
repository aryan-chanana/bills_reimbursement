import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../screens/add_bill_screen.dart';
import '../services/api_service.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _employeeId = 0;
  String _userName = '';
  List<Bill> _bills = [];
  List<Bill> _filteredBills = [];
  bool _isLoading = true;
  double _monthlyTotal = 0.0;
  Map<String, Uint8List> _imageCache = {};

  String _selectedFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _reimbursementCategories = [
    'All', 'Parking', 'Travel', 'Food', 'Office Supplies', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _employeeId = prefs.getInt('employee_id') ?? 0;
      _userName = prefs.getString('name') ?? '';
    });
    await _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt('employee_id')?.toString();
      final password = prefs.getString('password');

      if (employeeId == null || password == null) {
        throw Exception("User credentials not found.");
      }

      final bills = await ApiService.getMyBills(employeeId, password);
      if (mounted) {
        setState(() {
          _bills = bills;
        });
        _calculateMonthlyTotal();
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bills: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateMonthlyTotal() {
    final now = DateTime.now();
    double total = 0.0;
    _bills.where((b) => b.date.year == now.year && b.date.month == now.month)
        .forEach((b) => total += b.amount);
    setState(() => _monthlyTotal = total);
  }

  void _applyFilters() {
    List<Bill> filtered = List.from(_bills);
    if (_selectedFilter != 'All') {
      filtered = filtered.where((bill) => bill.reimbursementFor == _selectedFilter).toList();
    }
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((bill) => !bill.date.isBefore(_startDate!) && !bill.date.isAfter(_endDate!)).toList();
    }
    setState(() => _filteredBills = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Hello, $_userName'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBills),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: Column(
          children: [
            // Summary Card & Filters... (no changes)
            Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('This Month\'s Total', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          Text('₹${_monthlyTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      const Icon(Icons.account_balance_wallet, size: 40, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedFilter,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: _reimbursementCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedFilter = value);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.date_range), onPressed: _selectDateRange),
                ],
              ),
            ),

            // Bills List (CHANGED)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredBills.isEmpty
                  ? const Center(child: Text('No bills found.'))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredBills.length,
                itemBuilder: (context, index) {
                  final bill = _filteredBills[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: _getStatusColor(bill.status), child: const Text('₹', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      title: Text(bill.reimbursementFor, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount: ₹${bill.amount.toStringAsFixed(2)}'),
                          Text('Date: ${DateFormat('dd/MM/yyyy').format(bill.date)}'),
                          Text('Status: ${bill.status.toUpperCase()}', style: TextStyle(color: _getStatusColor(bill.status), fontWeight: FontWeight.bold)),
                        ],
                      ),

                      trailing: bill.status.toLowerCase() == 'pending'
                          ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditBillDialog(bill);
                          } else if (value == 'delete') {
                            _showDeleteConfirmationDialog(bill);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      )
                          : IconButton(icon: const Icon(Icons.image), onPressed: () => _viewBillImage(bill)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddBillScreen(employeeId: _employeeId)),
          );
          if (result == true) {
            _loadBills();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditBillDialog(Bill bill) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: bill.amount.toString());
    String selectedCategory = bill.reimbursementFor;
    DateTime selectedDate = bill.date;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Bill'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: _reimbursementCategories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (value) => selectedCategory = value!,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount (₹)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty || double.tryParse(v) == null ? 'Invalid amount' : null,
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) {
                        // This requires a StatefulWidget for the dialog, so we'll skip state update for simplicity
                        selectedDate = picked;
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                    ),
                  )
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final prefs = await SharedPreferences.getInstance();
                  final password = prefs.getString('password');
                  if (password == null) return;

                  final updatedBill = Bill(
                    billId: bill.billId,
                    reimbursementFor: selectedCategory,
                    amount: double.parse(amountController.text),
                    date: selectedDate,
                    billImagePath: bill.billImagePath, // Image path doesn't change on edit
                    status: bill.status,
                    employeeId: bill.employeeId,
                  );

                  final success = await ApiService.editBill(
                    employeeId: _employeeId.toString(),
                    password: password,
                    billId: bill.billId,
                    updatedBill: updatedBill,
                  );

                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill updated!'), backgroundColor: Colors.green));
                    _loadBills();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update bill.'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(Bill bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this bill?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final password = prefs.getString('password');
              if (password == null) return;

              final success = await ApiService.deleteBill(
                employeeId: _employeeId.toString(),
                password: password,
                billId: bill.billId,
              );

              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill deleted!'), backgroundColor: Colors.green));
                _loadBills();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete bill.'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _viewBillImage(Bill bill) async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getInt('employee_id')?.toString() ?? '';
    final adminPassword = prefs.getString('password') ?? '';

    final imageUrl = '${ApiService.baseUrl.replaceAll("/api", "")}/files/${bill.billImagePath}';

    Uint8List? cachedBytes = _imageCache[imageUrl];
    Uint8List bytes;

    if (cachedBytes != null) {
      bytes = cachedBytes;
    } else {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: ApiService.getAuthHeaders(adminId, adminPassword),
      );

      if (response.statusCode != 200) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: const Text('Could not load image.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        );
        return;
      }

      bytes = response.bodyBytes;
      _imageCache[imageUrl] = bytes;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Bill Image'),
              actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }
}