import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/excel_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Bill> _bills = [];
  List<Bill> _filteredBills = [];
  List<User> _employees = [];
  bool _isLoading = true;

  // Filters
  int? _selectedEmployeeId;
  String? _selectedCategory;
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  String? _adminId;
  String? _adminPassword;

  final List<String> _reimbursementCategories = [
    'Parking', 'Travel', 'Food', 'Office Supplies', 'Other'
  ];
  final List<String> _statusOptions = ['pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getInt('employee_id')?.toString();
      final adminPassword = prefs.getString('password');

      if (adminId == null || adminPassword == null) {
        throw Exception("Admin credentials not found.");
      }

      setState(() {
        _adminId = adminId;
        _adminPassword = adminPassword;
      });

      final results = await Future.wait([
        ApiService.fetchUsers(adminId, adminPassword),
        ApiService.getAllBillsAsAdmin(adminId, adminPassword),
      ]);

      final employees = results[0] as List<User>;
      final bills = results[1] as List<Bill>;

      if (mounted) {
        setState(() {
          _employees = employees.where((user) => !user.isAdmin).toList();
          _bills = bills;
          _filteredBills = bills;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Bill> filtered = List.from(_bills);
    if (_selectedEmployeeId != null) {
      filtered = filtered.where((b) => b.employeeId == _selectedEmployeeId).toList();
    }
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = filtered.where((b) => b.reimbursementFor == _selectedCategory).toList();
    }
    if (_selectedStatus != null) {
      filtered = filtered
          .where((b) => b.status.toLowerCase() == _selectedStatus?.toLowerCase())
          .toList();
    }
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((b) => !b.date.isBefore(_startDate!) && !b.date.isAfter(_endDate!)).toList();
    }
    setState(() => _filteredBills = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.download), onPressed: _generateExcel),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Bills Management'), Tab(text: 'Employees')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildBillsTab(), _buildEmployeesTab()],
      ),
    );
  }

  Widget _buildBillsTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
      child: Column(
        children: [
          // Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedEmployeeId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Employee', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('All Employees')),
                          ..._employees.map((e) => DropdownMenuItem<int>(value: e.employeeId, child: Text('${e.name} (${e.employeeId})', overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedEmployeeId = value);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All Categories')),
                          ..._reimbursementCategories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All Status')),
                          ..._statusOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s.toUpperCase(), overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: _selectDateRange, icon: const Icon(Icons.date_range), label: Text(_startDate != null && _endDate != null ? 'Date Range' : 'Select Dates'))),
                  ],
                ),
              ],
            ),
          ),
          // Summary Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildSummaryItem('Total Bills', _filteredBills.length.toString(), Icons.receipt_long, Colors.blue)),
                    Expanded(child: _buildSummaryItem('Total Amount', '₹${_filteredBills.fold(0.0, (sum, bill) => sum + bill.amount).toStringAsFixed(2)}', Icons.currency_rupee, Colors.green)),
                    Expanded(child: _buildSummaryItem('Pending', _filteredBills.where((bill) => bill.status == 'pending').length.toString(), Icons.pending, Colors.orange)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Bills List
          _filteredBills.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No bills match the current filters.')))
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredBills.length,
            itemBuilder: (context, index) {
              final bill = _filteredBills[index];
              final employee = _employees.firstWhere(
                    (e) => e.employeeId == bill.employeeId,
                orElse: () => User(employeeId: 0, name: 'Unknown', password: '', isAdmin: false),
              );
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Text('${employee.name} - ${bill.reimbursementFor}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(children: [const Text('💰 '),
                        Flexible(
                          child: Text(
                            'Amount: ₹${bill.amount.toStringAsFixed(2)}',
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        )
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [const Text('📅 '),
                        Flexible(
                          child: Text(
                            'Bill Date: ${DateFormat('dd/MM/yyyy').format(bill.date)}',
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        )
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [const Text('🕒 '),
                        Flexible(
                          child: Text(
                            'Submission: ${DateFormat('dd/MM/yyyy').format(bill.createdAt!)}',
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        )
                      ]),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(bill.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: _getStatusColor(bill.status),
                  ),
                  children: [_buildBillDetails(bill, employee)],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetails(Bill bill, User employee) {
    final imageUrl = '${ApiService.baseUrl.replaceAll("/api", "")}/files/${bill.billImagePath}';
    final headers = ApiService.getAuthHeaders(_adminId!, _adminPassword!);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Employee: ${employee.name} (${employee.employeeId})', style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text('Category: ${bill.reimbursementFor}', overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Amount: ₹${bill.amount.toStringAsFixed(2)}', overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Bill Date: ${DateFormat('dd/MM/yyyy').format(bill.date)}', overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Submission: ${DateFormat('dd/MM/yyyy').format(bill.createdAt!)}', overflow: TextOverflow.ellipsis),
                    if (bill.status.toLowerCase() == 'rejected' && (bill.remarks?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 8),
                      Text('Remarks: ${bill.remarks}', style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final imageWidget = Image.network(
                    imageUrl,
                    headers: headers,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.red),
                  );
                  _showBillImageDialog(imageWidget);
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      headers: headers,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, color: Colors.red);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bill.status.toLowerCase() == 'pending') Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _onApprovePressed(bill),
                  icon: const Text('✅'),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRejectDialog(bill),
                  icon: const Text('❌'),
                  label: const Text('Reject', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBillImageDialog(Widget imageWidget) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Bill Image'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: imageWidget,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _employees.length,
      itemBuilder: (context, index) {
        final employee = _employees[index];
        final employeeBills = _bills.where((bill) => bill.employeeId == employee.employeeId).toList();
        final totalAmount = employeeBills.fold(0.0, (sum, bill) => sum + bill.amount);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(employee.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(employee.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${employee.employeeId}'),
                Text('Total Bills: ${employeeBills.length}'),
                Text('Total Amount: ₹${totalAmount.toStringAsFixed(2)}'),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditUserDialog(employee);
                } else if (value == 'delete') {
                  _showDeleteConfirmationDialog(employee);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditUserDialog(User employee) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: employee.name);
    final passwordController = TextEditingController(text: employee.password);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Employee'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) => value == null || value.isEmpty ? 'Name cannot be empty' : null,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) => value == null || value.isEmpty ? 'Password cannot be empty' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final success = await ApiService.editUser(
                    adminId: _adminId!,
                    adminPassword: _adminPassword!,
                    employeeIdToEdit: employee.employeeId,
                    newName: nameController.text,
                    newPassword: passwordController.text,
                  );
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee updated successfully'), backgroundColor: Colors.green));
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update employee'), backgroundColor: Colors.red));
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

  void _showDeleteConfirmationDialog(User employee) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the user "${employee.name}"? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final success = await ApiService.deleteUser(
                  adminId: _adminId!,
                  adminPassword: _adminPassword!,
                  employeeIdToDelete: employee.employeeId,
                );
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee deleted successfully'), backgroundColor: Colors.green));
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete employee'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
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

  Future<void> _generateExcel() async {
    try {
      await ExcelService.instance.generateBillsReport(_filteredBills, _employees);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel report generated and saved to Downloads'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error generating Excel report'), backgroundColor: Colors.red));
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _onApprovePressed(Bill bill) async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getInt('employee_id');
    final adminPassword = prefs.getString('password');
    if (adminId == null || adminPassword == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin credentials not found'), backgroundColor: Colors.red));
      return;
    }

    final success = await ApiService.changeStatus(
      employeeId: adminId,
      password: adminPassword,
      billId: bill.billId,
      status: "APPROVED",
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill approved'), backgroundColor: Colors.green));
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve bill'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showRejectDialog(Bill bill) async {
    final remarkController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Bill'),
        content: TextField(
          controller: remarkController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Remarks (required)',
            hintText: 'Enter reason for rejection',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final remarks = remarkController.text.trim();
              if (remarks.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter remarks'), backgroundColor: Colors.orange));
                return;
              }

              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              final adminId = prefs.getInt('employee_id');
              final adminPassword = prefs.getString('password');
              if (adminId == null || adminPassword == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin credentials not found'), backgroundColor: Colors.red));
                return;
              }

              final success = await ApiService.changeStatus(
                employeeId: adminId,
                password: adminPassword,
                billId: bill.billId,
                status: "REJECTED",
                remarks: remarks
              );

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill rejected'), backgroundColor: Colors.green));
                _loadData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reject bill'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}