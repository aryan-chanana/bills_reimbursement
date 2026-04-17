import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../screens/add_bill_screen.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/compression_service.dart';
import '../services/offline_queue_service.dart';
import 'package:flutter/foundation.dart';
import 'package:file_saver/file_saver.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  Color kPrimaryBlue = Color(0xFF2196F3);
  Color kPrimaryBlueDark = Color(0xFF1E3A8A);
  Color kBgTop = Color(0xFFE3F2FD);
  Color kBgBottom = Color(0xFFBBDEFB);

  int _employeeId = 0;
  String _userName = '';
  List<Bill> _bills = [];
  List<Bill> _filteredBills = [];
  bool _isLoading = true;
  double _monthlyTotal = 0.0;
  Map<String, Uint8List> _imageCache = {};
  bool _isAdmin = false;

  String _selectedFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  String _selectedStatus = 'All';
  final List<String> _statusOptions = ['All', 'Pending', 'Approved', 'Rejected', 'Paid'];

  final List<String> _reimbursementCategories = ['All', 'Parking', 'Travel', 'Food', 'Office Supplies', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    Future.delayed(Duration(milliseconds: 100), () async {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt('employee_id')!.toString();
      final password = prefs.getString('password')!;
      _isAdmin = prefs.getBool('is_admin') ?? false;

      await OfflineQueueService.trySubmitQueuedBills(int.parse(employeeId), password);
      _uploadFcmToken(employeeId, password);
    });
  }

  Future<void> _uploadFcmToken(String employeeId, String password) async {
    try {
      final token = await NotificationService.requestPermissionAndGetToken();
      if (token != null) {
        await ApiService.updateFcmToken(employeeId, password, token);
      }
    } catch (_) {}
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

      final bool backendAvailable = await ConnectivityService.isBackendAvailable();
      if (!backendAvailable) {
        _showErrorDialog("\nUnable to load bills.\nPlease try again later.");
      }
      else {
        final bills = await ApiService.getMyBills(employeeId, password);
        if (mounted) {
          setState(() {
            _bills = bills;
          });
          _calculateMonthlyTotal();
          _applyFilters();
        }
      }
    }
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateMonthlyTotal() {
    final now = DateTime.now();
    double total = 0.0;
    _bills.where((b) =>
    b.createdAt!.year == now.year &&
        b.createdAt!.month == now.month
    ).forEach((b) => total += b.amount);
    setState(() => _monthlyTotal = total);
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


    if (_selectedFilter != 'All') {
      filtered = filtered.where((b) => b.reimbursementFor == _selectedFilter).toList();
    }

    if (_selectedStatus != 'All') {
      filtered = filtered.where(
            (b) => b.status.toLowerCase() == _selectedStatus.toLowerCase(),
      ).toList();
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
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.7)),
            boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color c;
    switch (status.toLowerCase()) {
      case 'approved': c = Colors.green; break;
      case 'rejected': c = Colors.red; break;
      case 'paid': c = Colors.blue; break;
      default: c = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(30)),
      alignment: Alignment.center,
      child: Text(status.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmt = _filteredBills.fold<double>(0.0, (sum, b) => sum + b.amount);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${_userName.toUpperCase()}, $_employeeId', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBills),
          IconButton(
            icon: const Icon(Icons.lock_reset_rounded),
            tooltip: "Change Password",
            onPressed: _handleForgotPasswordFlow, // Defined below
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: "Admin Dashboard",
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/admin_dashboard');
              },
            ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimaryBlue, kPrimaryBlueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kBgTop, kBgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Filters (glass)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: _glassCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilter,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: _reimbursementCategories
                              .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) { if (v!=null) setState(()=>_selectedFilter=v); _applyFilters(); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: _statusOptions
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) { if (v!=null) setState(()=>_selectedStatus=v); _applyFilters(); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        width: 48,
                        child: ElevatedButton(
                          onPressed: _openCustomDatePicker,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.zero,
                            elevation: 0,
                          ),
                          child: const Icon(Icons.date_range, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Monthly total (glass)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _glassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("Total", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text('₹${totalAmt.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kPrimaryBlue)),
                      ]),
                      Icon(Icons.account_balance_wallet, size: 40, color: kPrimaryBlue),
                    ],
                  ),
                ),
              ),

              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredBills.isEmpty
                    ? const Center(child: Text('No bills found.'))
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _filteredBills.length,
                  itemBuilder: (context, i) {
                    final bill = _filteredBills[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _glassCard(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showBillDetailsModal(bill),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // icon
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(bill.status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.receipt_long, color: _getStatusColor(bill.status)),
                              ),
                              const SizedBox(width: 12),

                              // info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bill.reimbursementFor,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(DateFormat('dd MMM yyyy').format(bill.date),
                                            style: const TextStyle(fontSize: 13)),
                                      ),
                                    ]),
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      const Icon(Icons.currency_rupee, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text('₹${bill.amount.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 13)),
                                      ),
                                    ]),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text('Submission: ${DateFormat('dd MMM yyyy').format(bill.createdAt!)}',
                                            style: const TextStyle(fontSize: 13)),
                                      ),
                                    ]),
                                    if (bill.status.toLowerCase() == 'rejected' && bill.remarks != null) ...[
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.comment, size: 14, color: Colors.redAccent),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text('Remarks: ${bill.remarks}',
                                              style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontStyle: FontStyle.italic),
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      ]),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // centered status pill
                              _statusPill(bill.status),
                            ],
                          ),
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

      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryBlueDark,
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddBillScreen(employeeId: _employeeId)));
          if (result == true) _loadBills();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditBillDialog(Bill bill) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: bill.amount.toStringAsFixed(2));
    final descriptionController = TextEditingController(text: bill.billDescription ?? '');

    String selectedCategory = bill.reimbursementFor;
    DateTime selectedDate = bill.date;

    showDialog(
      context: context,
      builder: (context) {
        PlatformFile? newBillFile;
        PlatformFile? newApprovalFile;
        PlatformFile? newPaymentFile;

        Future<void> pickFile(String type, void Function(PlatformFile) onPicked) async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
          );
          if (result != null) onPicked(result.files.first);
        }

        Future<void> pickFromCamera(void Function(PlatformFile) onPicked) async {
          try {
            final XFile? photo = await ImagePicker().pickImage(source: ImageSource.camera);
            if (photo == null) return;
            onPicked(PlatformFile(name: photo.name, size: 0, path: photo.path));
          } on PlatformException catch (_) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Camera Permission Required'),
                content: const Text('Enable camera access from app settings.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () { Navigator.pop(context); openAppSettings(); }, child: const Text('Open Settings')),
                ],
              ),
            );
          }
        }

        Widget buildFileSection({
          required String title,
          required String? existingPath,
          required PlatformFile? newFile,
          required VoidCallback onPick,
          required VoidCallback onClear,
          VoidCallback? onCamera,
        }) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimaryBlueDark)),
                const SizedBox(height: 8),
                if (newFile != null) ...[
                  Row(
                    children: [
                      newFile.extension?.toLowerCase() != 'pdf' && !kIsWeb && newFile.path != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(File(newFile.path!), width: 48, height: 48, fit: BoxFit.cover),
                            )
                          : Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                            ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(newFile.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                      IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20), onPressed: onClear),
                    ],
                  ),
                ] else if (existingPath != null && existingPath.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          existingPath.split('/').last,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                      TextButton(onPressed: onPick, child: const Text("File")),
                      if (onCamera != null)
                        TextButton(
                          onPressed: onCamera,
                          child: Icon(Icons.camera_alt, size: 20, color: kPrimaryBlue),
                        ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPick,
                          icon: Icon(Icons.upload_file, color: kPrimaryBlue, size: 18),
                          label: Text("Select File", style: TextStyle(color: kPrimaryBlue, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (onCamera != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onCamera,
                            icon: Icon(Icons.camera_alt, color: kPrimaryBlue, size: 18),
                            label: Text("Camera", style: TextStyle(color: kPrimaryBlue, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white.withOpacity(0.90),
                      border: Border.all(color: Colors.white.withOpacity(0.7)),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // HEADER
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(colors: [kPrimaryBlue, kPrimaryBlueDark]),
                              ),
                              child: const Text("Edit Bill", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                            const SizedBox(height: 20),

                            // CATEGORY
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: InputDecoration(
                                labelText: "Category",
                                prefixIcon: Icon(Icons.category_rounded, color: kPrimaryBlueDark),
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              items: _reimbursementCategories.where((c) => c != "All").map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  selectedCategory = v!;
                                  if (selectedCategory == 'Parking') {
                                    descriptionController.clear();
                                    newApprovalFile = null;
                                    newPaymentFile = null;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            if (selectedCategory != 'Parking') ...[
                              TextFormField(
                                controller: descriptionController,
                                decoration: InputDecoration(
                                  labelText: "Description",
                                  prefixIcon: Icon(Icons.description_rounded, color: kPrimaryBlue),
                                  filled: true, fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Description required' : null,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // AMOUNT
                            TextFormField(
                              controller: amountController,
                              decoration: InputDecoration(
                                labelText: "Amount (₹)",
                                prefixIcon: Icon(Icons.currency_rupee_rounded, color: kPrimaryBlue),
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || double.tryParse(v) == null) ? 'Invalid amount' : null,
                            ),
                            const SizedBox(height: 16),

                            // DATE
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                                if (picked != null) setStateDialog(() => selectedDate = picked);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: "Date",
                                  prefixIcon: Icon(Icons.calendar_today_rounded, color: kPrimaryBlueDark),
                                  filled: true, fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // BILL FILE
                            buildFileSection(
                              title: "Bill / Receipt",
                              existingPath: bill.billImagePath,
                              newFile: newBillFile,
                              onPick: () => pickFile('bill', (f) => setStateDialog(() => newBillFile = f)),
                              onClear: () => setStateDialog(() => newBillFile = null),
                              onCamera: () => pickFromCamera((f) => setStateDialog(() => newBillFile = f)),
                            ),

                            // APPROVAL MAIL + PAYMENT PROOF (non-parking only)
                            if (selectedCategory != 'Parking') ...[
                              const SizedBox(height: 12),
                              buildFileSection(
                                title: "Approval Mail",
                                existingPath: bill.approvalMailPath,
                                newFile: newApprovalFile,
                                onPick: () => pickFile('approval', (f) => setStateDialog(() => newApprovalFile = f)),
                                onClear: () => setStateDialog(() => newApprovalFile = null),
                              ),
                              const SizedBox(height: 12),
                              buildFileSection(
                                title: "Payment Proof",
                                existingPath: bill.paymentProofPath,
                                newFile: newPaymentFile,
                                onPick: () => pickFile('payment', (f) => setStateDialog(() => newPaymentFile = f)),
                                onClear: () => setStateDialog(() => newPaymentFile = null),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // BUTTONS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context)),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlueDark, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                                  onPressed: () async {
                                    if (!formKey.currentState!.validate()) return;

                                    final prefs = await SharedPreferences.getInstance();
                                    final password = prefs.getString('password');

                                    // Compress new files before upload (PDFs pass through unchanged)
                                    final File? compressedBill = await CompressionService.compressNullable(
                                        newBillFile?.path != null ? File(newBillFile!.path!) : null);
                                    final File? compressedApproval = await CompressionService.compressNullable(
                                        newApprovalFile?.path != null ? File(newApprovalFile!.path!) : null);
                                    final File? compressedPayment = await CompressionService.compressNullable(
                                        newPaymentFile?.path != null ? File(newPaymentFile!.path!) : null);

                                    final success = await ApiService.editBill(
                                      employeeId: _employeeId.toString(),
                                      password: password!,
                                      billId: bill.billId,
                                      reimbursementFor: selectedCategory,
                                      description: descriptionController.text.trim(),
                                      amount: double.parse(amountController.text),
                                      date: selectedDate,
                                      billImage: compressedBill,
                                      approvalMail: compressedApproval,
                                      paymentProof: compressedPayment,
                                    );

                                    Navigator.pop(context);
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bill updated!")));
                                      _loadBills();
                                    }
                                  },
                                  child: const Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'paid': return Colors.blue;
      default: return Colors.orange;
    }
  }

  void _initDefaultMonthRange() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate   = DateTime(now.year, now.month + 1, 0);
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

  void _viewDocument(String filePath, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('employee_id')?.toString() ?? '';
    final password = prefs.getString('password') ?? '';

    final url = '${ApiService.baseUrl}/files/$filePath';
    final isPdf = filePath.toLowerCase().endsWith('.pdf');

    final response = await http.get(Uri.parse(url), headers: ApiService.getAuthHeaders(userId, password));
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
    _imageCache[url] = bytes;
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
                          colors: [kPrimaryBlue, kPrimaryBlueDark],
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

  Future<void> _handleForgotPasswordFlow() async {
    final empId = _employeeId.toString();
    bool isSending = false;
    String? apiError;

    // Step 1: Confirm and Send OTP
    bool otpSent = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Send a password reset OTP to your registered email for Employee ID: $empId?'),
                  if (apiError != null) ...[
                    const SizedBox(height: 12),
                    Text(apiError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending ? null : () async {
                    setStateDialog(() { isSending = true; apiError = null; });

                    // Using existing ApiService logic
                    String otpStatus = await ApiService.sendOtp(empId, '', false);

                    setStateDialog(() => isSending = false);
                    if (otpStatus == "OTP sent.") {
                      Navigator.pop(context, true);
                    } else {
                      setStateDialog(() => apiError = "Failed: $otpStatus");
                    }
                  },
                  child: isSending
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send OTP'),
                ),
              ],
            );
          }
      ),
    ) ?? false;

    if (!otpSent) return;

    // Step 2: Verify OTP
    bool isVerified = await _showOtpVerificationDialog(empId, false);
    if (!isVerified) return;

    // Step 3: Set New Password
    final newPasswordController = TextEditingController();
    final newPasswordFormKey = GlobalKey<FormState>();
    bool obscureNewPassword = true;

    bool resetSuccess = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('New Password'),
              content: Form(
                key: newPasswordFormKey,
                child: TextFormField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'Enter New Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setStateDialog(() => obscureNewPassword = !obscureNewPassword),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (newPasswordFormKey.currentState!.validate()) {
                      bool success = await ApiService.resetPassword(empId, newPasswordController.text.trim());
                      Navigator.pop(context, success);
                    }
                  },
                  child: const Text('Update Password'),
                ),
              ],
            );
          }
      ),
    ) ?? false;

    if (resetSuccess) {
      // Crucial: Update the stored password in SharedPreferences so future API calls don't fail
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('password', newPasswordController.text.trim());

      _showSuccessDialog('Password updated successfully!');
    } else {
      _showErrorDialog('Failed to update password.');
    }
  }

  Future<bool> _showOtpVerificationDialog(String empId, bool signUp) async {
    final otpController = TextEditingController();
    bool isVerified = false;
    bool isVerifying = false;
    String? inlineError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Verify OTP'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter the OTP sent to your email.'),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'OTP',
                    errorText: inlineError,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isVerifying ? null : () async {
                  setStateDialog(() { isVerifying = true; inlineError = null; });
                  isVerified = await ApiService.verifyOtp(empId, otpController.text.trim(), signUp);
                  setStateDialog(() => isVerifying = false);

                  if (isVerified) {
                    Navigator.pop(context);
                  } else {
                    setStateDialog(() => inlineError = 'Invalid OTP');
                  }
                },
                child: isVerifying
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify'),
              ),
            ],
          );
        },
      ),
    );
    return isVerified;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showBillDetailsModal(Bill bill) {
    if (bill.billDescription != null) {
    }
    final s = bill.status.toLowerCase();
    final bool canEdit = (s == 'pending' || s == 'rejected');
    final bool canDelete = (s != 'paid'); // Paid bills cannot be deleted

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
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
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statusPill(bill.status),
                          Text('₹${bill.amount.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kPrimaryBlueDark)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _detailRow(Icons.category, "Category", bill.reimbursementFor),
                      _detailRow(Icons.calendar_today, "Bill Date", DateFormat('dd MMM yyyy').format(bill.date)),
                      _detailRow(Icons.access_time, "Submitted On", DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt!)),

                      if (bill.reimbursementFor != 'Parking' && bill.billDescription != null)
                        _detailRow(Icons.description, "Description", bill.billDescription!),

                      if (bill.remarks != null && s == 'rejected')
                        _detailRow(Icons.comment, "Rejection Remarks", bill.remarks!, isError: true),

                      const SizedBox(height: 30),

                      // VIEW DOCUMENTS
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.receipt_long),
                          label: const Text("View Bill Receipt"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
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
                                padding: const EdgeInsets.all(16),
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
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _viewDocument(bill.paymentProofPath!, "Payment Proof"),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 12),

                      // ✅ ACTION BUTTONS Row
                      Row(
                        children: [
                          if (canEdit)
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit),
                                label: const Text("Edit"),
                                onPressed: () { Navigator.pop(context); _showEditBillDialog(bill); },
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                              ),
                            ),
                          if (canEdit) const SizedBox(width: 12),

                          if (canDelete)
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: const Text("Delete", style: TextStyle(color: Colors.red)),
                                onPressed: () { Navigator.pop(context); _showDeleteConfirmationDialog(bill); },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
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

  Widget _detailRow(IconData icon, String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isError ? Colors.red : Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: isError ? Colors.red : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }
}