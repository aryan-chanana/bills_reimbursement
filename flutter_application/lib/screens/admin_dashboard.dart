import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';
import '../services/bill_download_service.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/excel_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

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
  List<User> _disabledUsers = [];
  bool _isLoading = true;
  List<User> _pendingUsers = [];
  // final GlobalKey _imageKey = GlobalKey();

  // Filters
  int? _selectedEmployeeId;
  String? _selectedCategory;
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  String _employeeSearch = "";
  String _employeeSort = "id_asc";

  String? _adminId;
  String? _adminPassword;

  final List<String> _reimbursementCategories = [
    'Parking', 'Travel', 'Food', 'Office Supplies', 'Other'
  ];
  final List<String> _statusOptions = ['pending', 'approved', 'rejected', 'paid'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    Future.delayed(const Duration(milliseconds: 100), _uploadFcmToken);
  }

  Future<void> _uploadFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt('employee_id')?.toString();
      final password = prefs.getString('password');
      debugPrint('FCM_UPLOAD: employeeId=$employeeId, hasPassword=${password != null}');
      if (employeeId == null || password == null) return;
      final token = await NotificationService.requestPermissionAndGetToken();
      debugPrint('FCM_UPLOAD: token=${token != null ? token.substring(0, 20) + "..." : "NULL"}');
      if (token != null) {
        await ApiService.updateFcmToken(employeeId, password, token);
        debugPrint('FCM_UPLOAD: done');
      }
    } catch (e) {
      debugPrint('FCM_UPLOAD ERROR: $e');
    }
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
            _employees = employees.where((u) => u.isApproved && !u.isDisabled).toList();
            _disabledUsers = employees.where((u) => u.isApproved && u.isDisabled).toList();
            _pendingUsers = employees.where((u) => !u.isApproved).toList();
            _bills = bills;
            _filteredBills = bills;
          });
          _applyFilters();
        }
      }
    } catch (e) {
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
      final submittedAt = b.createdAt!;
      final inRange = !submittedAt.isBefore(_startDate!) &&
          !submittedAt.isAfter(_endDate!);
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

          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _showSettingsSheet,
          ),

          PopupMenuButton<String>(

            onSelected: (value) {
              if (value == "refresh") _loadData();
              if (value == "pdf") _generateBillsPdf();
              if (value == "excel") _generateExcel();
              if (value == "user") {
                Navigator.pushReplacementNamed(context, '/user_dashboard');
              }
              if (value == "logout") _logout();
            },

            itemBuilder: (context) => const [

              PopupMenuItem(
                value: "refresh",
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text("Refresh"),
                ),
              ),

              PopupMenuItem(
                value: "pdf",
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text("Export PDF"),
                ),
              ),

              PopupMenuItem(
                value: "excel",
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text("Export Excel"),
                ),
              ),

              PopupMenuItem(
                value: "user",
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text("User Dashboard"),
                ),
              ),

              PopupMenuItem(
                value: "logout",
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text("Logout"),
                ),
              ),

            ],

            icon: const Icon(Icons.more_vert),
          )
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
                  dividerColor: Colors.transparent,
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

          if (_selectedStatus != null && _filteredBills.isNotEmpty) ...[
            if (_selectedStatus!.toLowerCase() == 'pending')
              _batchActionButton(
                label: "Approve All Pending (${_filteredBills.length})",
                icon: Icons.done_all,
                color: Colors.green,
                onPressed: _handleApproveAllBills,
              ),
            if (_selectedStatus!.toLowerCase() == 'approved')
              _batchActionButton(
                label: "Mark All Paid (${_filteredBills.length})",
                icon: Icons.payments,
                color: Colors.blue,
                onPressed: _handleMarkAllAsPaid,
              ),
            const SizedBox(height: 16),
          ],

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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 56, color: primaryGreen.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text('No bills found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('Try adjusting your filters', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredBills.length,
              itemBuilder: (context, i) {
                final bill = _filteredBills[i];
                final employee = [..._employees, ..._disabledUsers].firstWhere(
                      (e) => e.employeeId == bill.employeeId,
                  orElse: () => User(employeeId: 0, name: 'Unknown', password: '', isAdmin: false),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _glassCard(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showAdminBillDetailsModal(bill, employee),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // left status bar
                            Container(
                              width: 4,
                              decoration: BoxDecoration(
                                color: _getStatusColor(bill.status),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  bottomLeft: Radius.circular(20),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
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
                                            Icon(Icons.currency_rupee, size: 16, color: const Color(0xFF10B981)),
                                            const SizedBox(width: 4),
                                            Expanded(child: Text('₹${bill.amount.toStringAsFixed(2)}')),
                                          ]),
                                          const SizedBox(height: 2),
                                          Row(children: [
                                            Icon(Icons.date_range, size: 16, color: const Color(0xFF3B82F6)),
                                            const SizedBox(width: 4),
                                            Expanded(child: Text(DateFormat('dd MMM yyyy').format(bill.date))),
                                          ]),
                                          const SizedBox(height: 2),
                                          Row(children: [
                                            Icon(Icons.access_time, size: 16, color: const Color(0xFFF59E0B)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text('Submitted: ${DateFormat('dd MMM yyyy').format(bill.createdAt!)}'),
                                            ),
                                          ]),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _statusPill(bill.status),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _batchActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _showAdminBillDetailsModal(Bill bill, User employee) {
    final s = bill.status.toLowerCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Pull Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 4, width: 40,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Header Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statusPill(bill.status),
                          Text('₹${bill.amount.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.green[700])),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Employee Info Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(child: Text(employee.name[0])),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(employee.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text("Employee ID: ${employee.employeeId}", style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Bill Info Rows
                      _adminDetailRow(Icons.category, "Reimbursement For", bill.reimbursementFor),
                      _adminDetailRow(Icons.calendar_today, "Bill Date", DateFormat('dd MMM yyyy').format(bill.date)),
                      _adminDetailRow(Icons.access_time, "Submitted At", DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt!)),

                      // Add description row here if exists in your model
                      if (bill.reimbursementFor != 'Parking' && bill.billDescription != null)
                        _adminDetailRow(Icons.description, "Description", bill.billDescription!),

                      if (bill.remarks != null && s == 'rejected')
                        _adminDetailRow(Icons.comment, "Rejection Remarks", bill.remarks!, isError: true),

                      const SizedBox(height: 20),

                      // DOCUMENTS SECTION
                      const Text("Documents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.receipt_long),
                          label: const Text("View Bill Receipt"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _viewDocument(bill.billImagePath, "Bill Receipt"),
                        ),
                      ),

                      if (bill.reimbursementFor != 'Parking') ...[
                        if (bill.approvalMailPath != null && bill.approvalMailPath!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.mark_email_read),
                              label: const Text("View Approval Mail"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _viewDocument(bill.approvalMailPath!, "Approval Mail"),
                            ),
                          ),
                        ],
                        if (bill.paymentProofPath != null && bill.paymentProofPath!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payment),
                              label: const Text("View Payment Proof"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _viewDocument(bill.paymentProofPath!, "Payment Proof"),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 24),

                      // ✅ DYNAMIC ACTION BUTTONS
                      if (s == 'pending') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text("Approve"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                                onPressed: () { Navigator.pop(context); _onApprovePressed(bill); },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text("Reject"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                                onPressed: () { Navigator.pop(context); _showRejectDialog(bill); },
                              ),
                            ),
                          ],
                        ),
                      ] else if (s == 'approved') ...[
                        Column(
                          children: [
                            // Primary Action: Mark as Paid
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.payments),
                                label: const Text("Mark as Paid"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _confirmMarkAsPaid(bill);
                                },
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Secondary Action: Reject (even if approved)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close, color: Colors.red),
                                label: const Text("Reject Approved Bill", style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showRejectDialog(bill);
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else if (s == 'paid') ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.download),
                            label: const Text("Download Record"),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                            onPressed: () {Navigator.pop(context); _downloadBillImage(bill); },
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _adminDetailRow(IconData icon, String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isError ? Colors.red : Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isError ? Colors.red : Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildEmployeesTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final employees = _getFilteredEmployees();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            Row(
              children: [

                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search employee",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (v) {
                      setState(() {
                        _employeeSearch = v;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 10),

                DropdownButton<String>(
                  value: _employeeSort,
                  items: const [
                    DropdownMenuItem(value: "id_asc", child: Text("ID ↑")),
                    DropdownMenuItem(value: "id_desc", child: Text("ID ↓")),
                    DropdownMenuItem(value: "name", child: Text("Name")),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _employeeSort = v!;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // USER REQUEST BUTTON
            if (_pendingUsers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_active),
                  label: Text("User Requests (${_pendingUsers.length})"),
                  onPressed: _showUserRequestsDialog,
                ),
              ),


            // ACTIVE EMPLOYEE LIST
            ...employees.map((employee) {

              final employeeBills =
              _bills.where((b) => b.employeeId == employee.employeeId).toList();

              final totalAmount =
              employeeBills.fold(0.0, (sum, b) => sum + b.amount);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _glassCard(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.greenAccent,
                      child: Text(
                        employee.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      employee.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('ID: ${employee.employeeId}'),
                            if (employee.isAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings, size: 14, color: Colors.orange),
                                    SizedBox(width: 4),
                                    Text("ADMIN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text('Total Bills: ${employeeBills.length}'),
                        Text('Total Amount: ₹${totalAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditUserDialog(employee);
                        } else if (value == 'disable') {
                          _showToggleDisableDialog(employee);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'disable',
                          child: Text('Disable', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),

        // FAB
        Positioned(
          right: 18,
          bottom: 18,
          child: GestureDetector(
            onTap: _showCreateUserDialog,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Add Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showEditUserDialog(User employee) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: employee.name);
    final emailController = TextEditingController(text: employee.email);

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
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value == null || value.isEmpty ? 'Email cannot be empty' : null,
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
                    name: nameController.text,
                    email: emailController.text,
                    isApproved: true
                  );
                  Navigator.pop(context);
                  if (success == "true") {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee updated successfully'), backgroundColor: Colors.green));
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update employee: $success'), backgroundColor: Colors.red));
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

  void _showToggleDisableDialog(User employee) {
    final willDisable = !employee.isDisabled;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(willDisable ? 'Disable Employee' : 'Enable Employee'),
          content: Text(
            willDisable
                ? 'Disable "${employee.name}"? They will no longer be able to log in.'
                : 'Re-enable "${employee.name}"? They will be able to log in again.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final success = await ApiService.disableUser(
                  adminId: _adminId!,
                  adminPassword: _adminPassword!,
                  employeeId: employee.employeeId,
                  disabled: willDisable,
                );
                if (mounted) Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Employee ${willDisable ? 'disabled' : 'enabled'} successfully'),
                    backgroundColor: Colors.green,
                  ));
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to update employee status'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: willDisable ? Colors.red : Colors.green),
              child: Text(willDisable ? 'Disable' : 'Enable', style: const TextStyle(color: Colors.white)),
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
      case 'approved': return const Color(0xFF10B981);
      case 'rejected': return const Color(0xFFEF4444);
      case 'paid':     return const Color(0xFF3B82F6);
      default:         return const Color(0xFFF59E0B);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 60),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text("Select range",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),

                        // 🔁 SHOW ALL moved here
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _startDate = DateTime(2020);
                              _endDate = DateTime.now();
                            });
                            _applyFilters();
                          },
                          child: Text("Show All"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // CALENDAR
                    TableCalendar(
                      focusedDay: start != null ? start! : DateTime.now(),
                      firstDay: DateTime(2020),
                      lastDay: DateTime.now(),
                      rangeStartDay: start,
                      rangeEndDay: end,
                      onRangeSelected: (s, e, f) {
                        setState(() {
                          start = s;
                          end = e;
                        });
                      },
                      rangeSelectionMode: RangeSelectionMode.enforced,
                      headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true),
                    ),

                    const SizedBox(height: 12),

                    // FOOTER BUTTONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.clear),
                          label: Text("Clear"),
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

                        // 🔁 SAVE moved here
                        ElevatedButton.icon(
                          icon: Icon(Icons.save),
                          label: Text("Save"),
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
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
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

  Future<void> _onMarkAsPaidPressed(Bill bill) async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getInt('employee_id');
    final adminPassword = prefs.getString('password');

    if (adminId == null || adminPassword == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin credentials not found'), backgroundColor: Colors.red),
      );
      return;
    }

    final success = await ApiService.changeStatus(
      employeeId: adminId,
      password: adminPassword,
      billId: bill.billId,
      status: "PAID",
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill marked as paid'), backgroundColor: Colors.green),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark bill as paid'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmMarkAsPaid(Bill bill) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: const Text('Are you sure this bill has been paid?'),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // ✅ center buttons
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _onMarkAsPaidPressed(bill);
                },
                child: const Text('Yes'),
              ),
            ],
          ),
        ],
      ),
    );
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
                Navigator.pop(context);
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

  void _viewDocument(String filePath, String title) async {
    final url = '${ApiService.baseUrl}/files/$filePath';
    final isPdf = filePath.toLowerCase().endsWith('.pdf');

    final response = await http.get(Uri.parse(url), headers: ApiService.getAuthHeaders(_adminId!, _adminPassword!));
    if (response.statusCode != 200) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Could not load document.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
      return;
    }

    final bytes = response.bodyBytes;
    if (!mounted) return;

    if (isPdf) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${filePath.split('/').last}');
      await tempFile.writeAsBytes(bytes);
      await OpenFilex.open(tempFile.path);
      return;
    }

    // Image viewer
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      barrierLabel: 'Close',
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.92,
                height: MediaQuery.of(context).size.height * 0.80,
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [lightGreen, primaryGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download, color: Colors.white),
                            tooltip: 'Download',
                            onPressed: () async {
                              final ext = filePath.split('.').last.toLowerCase();
                              final name = filePath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
                              await FileSaver.instance.saveAs(
                                name: name,
                                bytes: bytes,
                                fileExtension: ext,
                                mimeType: (ext == 'jpg' || ext == 'jpeg') ? MimeType.jpeg : MimeType.png,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: InteractiveViewer(
                          panEnabled: true,
                          minScale: 1,
                          maxScale: 4,
                          child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim), child: child),
        );
      },
    );
  }

  Future<void> _downloadBillImage(Bill bill) async {
    try {
      final imageUrl = '${ApiService.baseUrl}/files/${bill.billImagePath}';
      final headers = ApiService.getAuthHeaders(_adminId!, _adminPassword!);

      final response = await http.get(Uri.parse(imageUrl), headers: headers);
      if (response.statusCode != 200) throw Exception();

      await BillDownloadService.downloadBytes(
        response.bodyBytes,
        'bill_${bill.billImagePath}',
        'image/png',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image downloaded')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download image'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generateBillsPdf() async {
    if (_filteredBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bills to export')),
      );
      return;
    }

    // Show loading dialog while generating
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generating PDF…'),
          ],
        ),
      ),
    );

    try {
      // Load Unicode-supporting fonts so bullet (•) and em-dash (—) render correctly
      final fontRegular = await PdfGoogleFonts.notoSansRegular();
      final fontBold    = await PdfGoogleFonts.notoSansBold();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      );
      final authHeaders = ApiService.getAuthHeaders(_adminId!, _adminPassword!);

      final allKnownUsers = [..._employees, ..._disabledUsers];
      for (final bill in _filteredBills) {
        final employee = allKnownUsers.firstWhere(
          (e) => e.employeeId == bill.employeeId,
          orElse: () => User(employeeId: bill.employeeId, name: 'Unknown', password: ''),
        );
        await _addBillToPdf(pdf, bill, employee, authHeaders);
      }

      final pdfBytes = await pdf.save();
      final fileName = 'Bills_${DateFormat('dd-MM-yyyy').format(DateTime.now())}';

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog

      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(pdfBytes),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved to downloads'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('PDF ERROR: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Fetches a document and adds it to the PDF.
  /// Images: embedded directly. PDFs: each page rasterised at 150 dpi and embedded.
  /// Silently skips if path is null/empty or the fetch fails.
  Future<void> _addDocumentPage(
    pw.Document pdf,
    Map<String, String> headers,
    String? path,
    String label,
    int billId,
  ) async {
    if (path == null || path.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/files/$path'),
        headers: headers,
      );
      if (response.statusCode != 200) return;

      final fileBytes = response.bodyBytes;
      final isPdf = path.toLowerCase().endsWith('.pdf');

      if (isPdf) {
        // Rasterise each page and embed as a full-size image
        int pageNum = 1;
        await for (final raster in Printing.raster(fileBytes, dpi: 150)) {
          final imgBytes = await raster.toPng();
          final image = pw.MemoryImage(imgBytes);
          final currentPage = pageNum;
          pdf.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  currentPage == 1 ? 'Bill #$billId — $label' : 'Bill #$billId — $label (page $currentPage)',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 12),
                pw.Expanded(child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))),
              ],
            ),
          ));
          pageNum++;
        }
      } else {
        // Plain image document
        final image = pw.MemoryImage(fileBytes);
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Bill #$billId — $label',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Expanded(child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))),
            ],
          ),
        ));
      }
    } catch (_) {
      // Skip document if fetch or rasterisation fails
    }
  }

  /// A labelled info row for the bill summary page.
  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 11)),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  /// A document presence indicator line (filename or "Not provided").
  pw.Widget _pdfDocLine(String label, String? path) {
    final present = path != null && path.isNotEmpty;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text('  • $label: ', style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            present ? path.split('/').last : 'Not provided',
            style: pw.TextStyle(
              fontSize: 11,
              color: present ? PdfColors.black : PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        bool isAdmin = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Create Employee'),
              content: SingleChildScrollView(
                child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    TextFormField(
                      controller: idController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Employee ID'),
                      validator: (v) =>
                      v == null || v.isEmpty
                          ? 'Required'
                          : null,
                    ),

                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) =>
                      v == null || v.isEmpty
                          ? 'Required'
                          : null,
                    ),

                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                      v == null || v.isEmpty
                          ? 'Required'
                          : null,
                    ),

                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) =>
                      v == null || v.isEmpty
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Register as Admin"),
                        Switch(
                          value: isAdmin,
                          onChanged: (v) {
                            setStateDialog(() {
                              isAdmin = v;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              )),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                  child: const Text('Create'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final success = await ApiService.signUp(
                        idController.text.trim(),
                        nameController.text.trim(),
                        emailController.text.trim(),
                        passwordController.text.trim(),
                        isAdmin
                    );

                    Navigator.pop(context);

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(
                            'Employee created successfully'),
                            backgroundColor: Colors.green),
                      );
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(
                            'Failed to create employee'),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _disabledActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text('Disabled Employees (${_disabledUsers.length})'),
              subtitle: const Text('View, enable or delete disabled accounts'),
              trailing: const Icon(Icons.chevron_right),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                _showDisabledUsersSheet();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Delete Old Data', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Remove bills older than 2 financial years'),
              trailing: const Icon(Icons.chevron_right),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteOldDataDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDisabledUsersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4, width: 40,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                child: Row(
                  children: [
                    const Icon(Icons.block, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Disabled Employees (${_disabledUsers.length})',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('Export All'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        _exportAllDisabledUsersPdf();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _disabledUsers.length,
                  itemBuilder: (context, i) {
                    final user = _disabledUsers[i];
                    final userBills = _bills.where((b) => b.employeeId == user.employeeId).toList();
                    final totalAmt = userBills.fold(0.0, (sum, b) => sum + b.amount);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.grey,
                                  child: Text(
                                    user.name.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                      Text('ID: ${user.employeeId}  •  Bills: ${userBills.length}  •  ₹${totalAmt.toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _disabledActionBtn(
                                    icon: Icons.picture_as_pdf,
                                    label: 'Export',
                                    color: Colors.blue,
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _exportUserBillsPdf(user);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _disabledActionBtn(
                                    icon: Icons.person_add_alt_1,
                                    label: 'Enable',
                                    color: Colors.green,
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showToggleDisableDialog(user);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _disabledActionBtn(
                                    icon: Icons.delete_forever,
                                    label: 'Delete',
                                    color: Colors.red,
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showDeleteUserDialog(user);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserRequestsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),

          title: const Text("New User Requests"),

          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: _pendingUsers.isEmpty
                ? const Text("No pending requests")
                : ListView.builder(
              shrinkWrap: true,
              itemCount: _pendingUsers.length,
              itemBuilder: (context, i) {
                final user = _pendingUsers[i];

                return ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    radius: 18,
                    child: Icon(Icons.person, size: 18),
                  ),

                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),

                  subtitle: Text(
                    "ID: ${user.employeeId}\nAdmin: ${user.isAdmin ? "Yes" : "No"}",
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _approveUser(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectUser(user),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          actions: [
            if (_pendingUsers.isNotEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.done_all),
                label: const Text("Approve All"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: _approveAllUsers,
              ),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveUser(User user) async {
    final success = await ApiService.editUser(
      adminId: _adminId!,
      adminPassword: _adminPassword!,
      employeeIdToEdit: user.employeeId,
      name: user.name,
      email: user.email,
      isApproved: true
    );

    if (success == "true") {
      Navigator.pop(context);
      _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User approved"), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _rejectUser(User user) async {
    final success = await ApiService.deleteUser(
      adminId: _adminId!,
      adminPassword: _adminPassword!,
      employeeIdToDelete: user.employeeId,
    );

    if (success) {
      Navigator.pop(context);
      _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User rejected"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _approveAllUsers() async {

    if (_pendingUsers.isEmpty) return;

    int successCount = 0;

    for (final user in _pendingUsers) {

      final success = await ApiService.editUser(
        adminId: _adminId!,
        adminPassword: _adminPassword!,
        employeeIdToEdit: user.employeeId,
        name: user.name,
        email: user.email,
        isApproved: true,
      );
      if (success == "true") successCount++;
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$successCount users approved"),
        backgroundColor: Colors.green,
      ),
    );
    _loadData();
  }

  List<User> _getFilteredEmployees() {

    List<User> list = [..._employees];

    // search
    if (_employeeSearch.isNotEmpty) {
      list = list.where((u) =>
      u.name.toLowerCase().contains(_employeeSearch.toLowerCase()) ||
          u.employeeId.toString().contains(_employeeSearch)
      ).toList();
    }

    // sorting
    if (_employeeSort == "name") {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_employeeSort == "id_desc") {
      list.sort((a, b) => b.employeeId.compareTo(a.employeeId));
    } else {
      list.sort((a, b) => a.employeeId.compareTo(b.employeeId));
    }

    return list;
  }

  Future<void> _handleApproveAllBills() async {
    bool? confirm = await _showConfirmDialog(
        "Approve All",
        "Are you sure you want to approve all ${_filteredBills.length} pending bills currently shown?"
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    int successCount = 0;

    for (final bill in _filteredBills) {
      final success = await ApiService.changeStatus(
        employeeId: int.parse(_adminId!),
        password: _adminPassword!,
        billId: bill.billId,
        status: "APPROVED",
      );
      if (success) successCount++;
    }

    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$successCount bills approved successfully!'), backgroundColor: Colors.green),
    );
  }

  Future<void> _handleMarkAllAsPaid() async {
    bool? confirm = await _showConfirmDialog(
        "Mark All Paid",
        "Confirm that all ${_filteredBills.length} approved bills shown have been paid?"
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    int successCount = 0;

    for (final bill in _filteredBills) {
      final success = await ApiService.changeStatus(
        employeeId: int.parse(_adminId!),
        password: _adminPassword!,
        billId: bill.billId,
        status: "PAID",
      );
      if (success) successCount++;
    }

    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$successCount bills marked as paid!'), backgroundColor: Colors.blue),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
        ],
      ),
    );
  }

  /// Adds all pages for a single bill to the PDF document.
  Future<void> _addBillToPdf(pw.Document pdf, Bill bill, User employee, Map<String, String> authHeaders) async {
    List<Uint8List> receiptPages = [];
    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/files/${bill.billImagePath}'),
        headers: authHeaders,
      );
      if (resp.statusCode == 200) {
        if (bill.billImagePath.toLowerCase().endsWith('.pdf')) {
          await for (final raster in Printing.raster(resp.bodyBytes, dpi: 150)) {
            receiptPages.add(await raster.toPng());
          }
        } else {
          receiptPages = [resp.bodyBytes];
        }
      }
    } catch (_) {}

    // Page 1: info summary + bill receipt
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Bill #${bill.billId}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
            ),
            pw.SizedBox(height: 10),
            _pdfInfoRow('Employee', '${employee.name}  (ID: ${bill.employeeId})'),
            _pdfInfoRow('Category', bill.reimbursementFor),
            if (bill.billDescription != null && bill.billDescription!.isNotEmpty)
              _pdfInfoRow('Description', bill.billDescription!),
            _pdfInfoRow('Amount', 'Rs. ${bill.amount.toStringAsFixed(2)}'),
            _pdfInfoRow('Bill Date', DateFormat('dd MMM yyyy').format(bill.date)),
            _pdfInfoRow('Submitted', bill.createdAt != null ? DateFormat('dd MMM yyyy').format(bill.createdAt!) : '—'),
            _pdfInfoRow('Status', bill.status.toUpperCase()),
            if (bill.remarks != null && bill.remarks!.isNotEmpty)
              _pdfInfoRow('Remarks', bill.remarks!),
            pw.SizedBox(height: 8),
            pw.Text('Attached Documents:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            _pdfDocLine('Bill Receipt', bill.billImagePath),
            _pdfDocLine('Approval Mail', bill.approvalMailPath),
            _pdfDocLine('Payment Proof', bill.paymentProofPath),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Expanded(
              child: pw.Center(
                child: receiptPages.isNotEmpty
                    ? pw.Image(pw.MemoryImage(receiptPages.first), fit: pw.BoxFit.contain)
                    : pw.Text('Bill Receipt: Image unavailable',
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ),
            ),
          ],
        ),
      ),
    );

    // Extra pages for multi-page bill receipt PDFs
    for (int p = 1; p < receiptPages.length; p++) {
      final pageImg = pw.MemoryImage(receiptPages[p]);
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Bill #${bill.billId} — Bill Receipt (page ${p + 1})',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Expanded(child: pw.Center(child: pw.Image(pageImg, fit: pw.BoxFit.contain))),
          ],
        ),
      ));
    }

    await _addDocumentPage(pdf, authHeaders, bill.approvalMailPath, 'Approval Mail', bill.billId);
    await _addDocumentPage(pdf, authHeaders, bill.paymentProofPath, 'Payment Proof', bill.billId);
  }

  Future<void> _exportUserBillsPdf(User user) async {
    final userBills = _bills.where((b) => b.employeeId == user.employeeId).toList();

    if (userBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No bills found for ${user.name}')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generating PDF…'),
          ],
        ),
      ),
    );

    try {
      final fontRegular = await PdfGoogleFonts.notoSansRegular();
      final fontBold    = await PdfGoogleFonts.notoSansBold();
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      );
      final authHeaders = ApiService.getAuthHeaders(_adminId!, _adminPassword!);

      for (final bill in userBills) {
        await _addBillToPdf(pdf, bill, user, authHeaders);
      }

      final pdfBytes = await pdf.save();
      final safeName = user.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final fileName = '${safeName}_Bills_${DateFormat('dd-MM-yyyy').format(DateTime.now())}';

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(pdfBytes),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved to downloads'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportAllDisabledUsersPdf() async {
    if (_disabledUsers.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Generating PDF for all disabled users…')),
          ],
        ),
      ),
    );

    try {
      final fontRegular = await PdfGoogleFonts.notoSansRegular();
      final fontBold    = await PdfGoogleFonts.notoSansBold();
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      );
      final authHeaders = ApiService.getAuthHeaders(_adminId!, _adminPassword!);

      for (final user in _disabledUsers) {
        final userBills = _bills.where((b) => b.employeeId == user.employeeId).toList();
        for (final bill in userBills) {
          await _addBillToPdf(pdf, bill, user, authHeaders);
        }
      }

      final pdfBytes = await pdf.save();
      final fileName = 'Disabled_Users_Bills_${DateFormat('dd-MM-yyyy').format(DateTime.now())}';

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(pdfBytes),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved to downloads'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteUserDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to permanently delete "${user.name}" (ID: ${user.employeeId}).'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber, color: Colors.red, size: 18),
                    SizedBox(width: 6),
                    Text('This action is irreversible.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ]),
                  SizedBox(height: 6),
                  Text(
                    'All bills and uploaded documents will be permanently deleted. Download their data first if you need a record.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download Data'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
            onPressed: () {
              Navigator.pop(context);
              _exportUserBillsPdf(user);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ApiService.deleteUser(
                adminId: _adminId!,
                adminPassword: _adminPassword!,
                employeeIdToDelete: user.employeeId,
              );
              if (mounted) {
                if (success) {
                  setState(() {
                    _disabledUsers.removeWhere((u) => u.employeeId == user.employeeId);
                    _bills.removeWhere((b) => b.employeeId == user.employeeId);
                    _filteredBills.removeWhere((b) => b.employeeId == user.employeeId);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Employee deleted'), backgroundColor: Colors.green),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete employee'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteOldDataDialog() async {
    // Fetch count first so the dialog can show how many bills will be deleted
    Map<String, dynamic>? info;
    try {
      info = await ApiService.getOldBillsCount(adminId: _adminId!, adminPassword: _adminPassword!);
    } catch (_) {}

    if (!mounted) return;

    final int count = info?['count'] ?? 0;
    final String cutoff = info?['cutoffDate'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Old Data', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (count == 0)
              const Text('No bills older than 2 years found. Nothing to delete.')
            else ...[
              Text('Found $count bill(s) submitted before ${cutoff.isNotEmpty ? DateFormat('dd MMM yyyy').format(DateTime.parse(cutoff)) : '2 years ago'}.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.warning_amber, color: Colors.red, size: 18),
                      SizedBox(width: 6),
                      Text('This action is irreversible.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ]),
                    SizedBox(height: 6),
                    Text(
                      'All matching bills and their uploaded files will be permanently deleted. Export the data first if you need a record.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (count > 0)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final result = await ApiService.deleteOldBills(adminId: _adminId!, adminPassword: _adminPassword!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Deleted ${result['count']} old bill(s) successfully'),
                      backgroundColor: Colors.green,
                    ));
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to delete old data: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
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

