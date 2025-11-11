import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';
import '../services/ConnectivityService.dart';
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

  Color primaryGreen = Color(0xFF4CAF50);
  Color lightGreen = Color(0xFFA5D6A7);
  Color bgGradientTop = Color(0xFFE8F5E9);
  Color bgGradientBottom = Color(0xFFDCEDC8);

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

      final bool backendAvailable = await ConnectivityService.isBackendAvailable();
      if (!backendAvailable) {
        _showErrorDialog("\nUnable to load bills.\nPlease try again later.");
      }
      else {
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
      }
    } catch (e) {
      print("LOAD BILLS ERROR = $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initDefaultMonthRange() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate   = DateTime(now.year, now.month + 1, 0);
  }

  void _applyFilters() {
    if (_startDate == null || _endDate == null) {
      _initDefaultMonthRange();
    }

    List<Bill> filtered = _bills.where((b) {
      final inRange = !b.date.isBefore(_startDate!) && !b.date.isAfter(_endDate!);
      return inRange;
    }).toList();

    if (_selectedEmployeeId != null) {
      filtered = filtered.where((b) => b.employeeId == _selectedEmployeeId).toList();
    }
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = filtered.where((b) => b.reimbursementFor == _selectedCategory).toList();
    }
    if (_selectedStatus != null) {
      filtered = filtered
          .where((b) =>
      b.status.toLowerCase() == _selectedStatus?.toLowerCase())
          .toList();
    }
    setState(() => _filteredBills = filtered);
  }

  Widget _glassCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
            boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }

  TabBarThemeData get _pillTabBarTheme => const TabBarThemeData(
    indicatorSize: TabBarIndicatorSize.tab,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.download), onPressed: _generateExcel),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightGreen, primaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(tabBarTheme: _pillTabBarTheme),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.black87,
                  unselectedLabelColor: Colors.white,
                  indicator: ShapeDecoration(
                    color: Colors.white,
                    shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.0))),
                  ),
                  tabs: const [Tab(text: 'Bills Management'), Tab(text: 'Employees')],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgGradientTop, bgGradientBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [_buildBillsTab(), _buildEmployeesTab()],
          ),
        ),
      ),
    );
  }

  Widget _buildBillsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalAmt = _filteredBills.fold<double>(0.0, (sum, b) => sum + b.amount);
    final pendingCount = _filteredBills.where((b) => b.status.toLowerCase() == 'pending').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          // Filters (Glass)
          _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedEmployeeId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Employee',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('All Employees')),
                          ..._employees.map((e) => DropdownMenuItem<int>(
                            value: e.employeeId,
                            child: Text('${e.name} (${e.employeeId})', overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedEmployeeId = v);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All Categories')),
                          ..._reimbursementCategories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedCategory = v);
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All Status')),
                          ..._statusOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s.toUpperCase()))),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedStatus = v);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openCustomDatePicker,
                        icon: const Icon(Icons.date_range),
                        label: Text('Select Dates'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Summary (Glass)
          _glassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryPill('Total Bills', _filteredBills.length.toString(), Icons.receipt_long, Colors.blue),
                _summaryPill('Total Amount', '₹${totalAmt.toStringAsFixed(2)}', Icons.currency_rupee, Colors.green),
                _summaryPill('Pending', '$pendingCount', Icons.pending_actions, Colors.orange),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bills (Glass Cards)
          if (_filteredBills.isEmpty)
            _glassCard(
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: Text('No bills match the current filters.')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredBills.length,
              itemBuilder: (context, i) {
                final bill = _filteredBills[i];
                final employee = _employees.firstWhere(
                      (e) => e.employeeId == bill.employeeId,
                  orElse: () => User(employeeId: 0, name: 'Unknown', password: '', isAdmin: false),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _glassCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showBillDetailsDialog(bill, employee),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _getStatusColor(bill.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.receipt_long, color: _getStatusColor(bill.status), size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${employee.name} (${employee.employeeId}) • ${bill.reimbursementFor}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 6),
                                Row(children: [
                                  const Icon(Icons.currency_rupee, size: 16, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text('₹${bill.amount.toStringAsFixed(2)}')),
                                ]),
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.date_range, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(DateFormat('dd MMM yyyy').format(bill.date))),
                                ]),
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text('Submitted: ${DateFormat('dd MMM yyyy').format(bill.createdAt!)}'),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(bill.status),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              bill.status.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showBillDetailsDialog(Bill bill, User employee) {
    final imageUrl = '${ApiService.baseUrl}/files/${bill.billImagePath}';
    final headers = ApiService.getAuthHeaders(_adminId!, _adminPassword!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.62,      // ✅ compact height
        minChildSize: 0.50,
        maxChildSize: 0.80,
        expand: false,
        builder: (context, controller) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _glassCard(
              child: Column(
                children: [
                  // -------- HEADER ---------
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bill Details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),

                  const SizedBox(height: 6),

                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Employee: ${employee.name} (${employee.employeeId})'),
                          Text('Category: ${bill.reimbursementFor}'),
                          Text('Amount: ₹${bill.amount.toStringAsFixed(2)}'),
                          Text('Bill Date: ${DateFormat('dd MMM yyyy').format(bill.date)}'),
                          Text('Submitted: ${DateFormat('dd MMM yyyy').format(bill.createdAt!)}'),
                          Text('Status: ${bill.status.toUpperCase()}'),

                          if (bill.remarks?.isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Remarks: ${bill.remarks!}',
                                  style: const TextStyle(color: Colors.redAccent)),
                            ),

                          const SizedBox(height: 16),

                          // ---------- IMAGE ----------
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: InteractiveViewer(
                              child: Image.network(
                                imageUrl,
                                headers: headers,
                                height: 260,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) =>
                                progress == null ? child : const SizedBox(
                                  height: 260,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (bill.status.toLowerCase() == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _onApprovePressed(bill),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Approve", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showRejectDialog(bill),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Reject", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmployeesTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _employees.length,
      itemBuilder: (context, i) {
        final employee = _employees[i];
        final employeeBills = _bills.where((b) => b.employeeId == employee.employeeId).toList();
        final totalAmount = employeeBills.fold(0.0, (sum, b) => sum + b.amount);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _glassCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(),
              leading: CircleAvatar(
                backgroundColor: Colors.greenAccent,
                child: Text(employee.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text(employee.name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
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

  Widget _summaryPill(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
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

  void _openCustomDatePicker() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        DateTime? start;
        DateTime? end;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
          child: _glassCard(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      const Expanded(
                        child: Center(child: Text('Select Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                      ),
                      TextButton(
                        onPressed: () {
                          if (start != null && end != null) {
                            Navigator.pop(context);
                            setState(() {
                              _startDate = start!;
                              _endDate = end!;
                            });
                            _applyFilters();
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Calendar
                  TableCalendar(
                    focusedDay: start != null ? start! : DateTime.now(),
                    firstDay: DateTime(2020),
                    lastDay: DateTime.now(),
                    rangeStartDay: start,
                    rangeEndDay: end,
                    onRangeSelected: (s, e, _) => setState(() { start = s; end = e; }),
                    rangeSelectionMode: RangeSelectionMode.enforced,
                    headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                  ),
                  const SizedBox(height: 12),
                  // Footer buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                          onPressed: () {
                            setState(() {
                              start = null;
                              end = null;
                              _startDate = null;
                              _endDate = null;
                            });
                            Navigator.pop(context);
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: const Text('Show All'),
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _startDate = DateTime(2020);
                              _endDate = DateTime.now();
                            });
                            _applyFilters();
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Connection Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
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