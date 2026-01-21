import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../screens/add_bill_screen.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';

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

      await OfflineQueueService.trySubmitQueuedBills(int.parse(employeeId), password);
    });
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
      print("LOAD BILLS ERROR = $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
      // print(stack);
      // if (mounted) {
      //   _showErrorDialog("\nUnable to load bills.\nPlease try again later.");
      // }
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${_userName.toUpperCase()}, $_employeeId', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBills),
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
              // Monthly total (glass)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _glassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("This Month's Total", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text('₹${_monthlyTotal.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kPrimaryBlue)),
                      ]),
                      Icon(Icons.account_balance_wallet, size: 40, color: kPrimaryBlue),
                    ],
                  ),
                ),
              ),

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
                          onTap: () {
                            final s = bill.status.toLowerCase();
                            if (s == 'approved' || s == 'paid') _viewBillImage(bill);
                            else _showBillOptions(bill);
                          },
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
    final amountController = TextEditingController(
        text: bill.amount.toStringAsFixed(2));
    String selectedCategory = bill.reimbursementFor;
    DateTime selectedDate = bill.date;

    showDialog(
      context: context,
      builder: (context) {
        XFile? newImageFile;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget imagePreviewWidget() {
              if (newImageFile != null) {
                // ✅ Local new image (picked)
                return InteractiveViewer(
                  panEnabled: true,
                  minScale: 1,
                  maxScale: 4,
                  child: Image.file(
                    File(newImageFile!.path),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                );
              } else if (bill.billImagePath.isNotEmpty) {
                // ✅ Server image with auth
                final url = '${ApiService.baseUrl.replaceAll(
                    "/api", "")}/files/${bill.billImagePath}';
                return FutureBuilder<Uint8List?>(
                  future: _fetchImageWithAuth(url),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (snapshot.hasError || !snapshot.hasData) {
                      return const Text('Could not load image');
                    } else {
                      return InteractiveViewer(
                        panEnabled: true,
                        minScale: 1,
                        maxScale: 4,
                        child: Image.memory(
                          snapshot.data!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      );
                    }
                  },
                );
              } else {
                return const Text('No image selected');
              }
            }

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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ✅ HEADER
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [kPrimaryBlue, kPrimaryBlueDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Text(
                              "Edit Bill",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ✅ CATEGORY DROPDOWN (glass)
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: InputDecoration(
                              labelText: "Category",
                              prefixIcon: Icon(Icons.category_rounded, color: kPrimaryBlueDark),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            items: _reimbursementCategories
                                .where((c) => c != "All")
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setStateDialog(() => selectedCategory = v!),
                          ),

                          const SizedBox(height: 16),

                          // ✅ AMOUNT TEXTFIELD
                          TextFormField(
                            controller: amountController,
                            decoration: InputDecoration(
                              labelText: "Amount (₹)",
                              prefixIcon: Icon(Icons.currency_rupee_rounded, color: kPrimaryBlue),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),

                          const SizedBox(height: 16),

                          // ✅ DATE PICKER
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setStateDialog(() => selectedDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: "Date",
                                prefixIcon: Icon(Icons.calendar_today_rounded, color: kPrimaryBlueDark),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ✅ IMAGE PREVIEW GLASS BOX
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: imagePreviewWidget(),
                            ),
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: Icon(Icons.image_rounded, size: 32, color: kPrimaryBlue),
                              onPressed: () {
                                _pickBillImage(
                                  onPicked: (file) {
                                    setStateDialog(() => newImageFile = file);
                                  },
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ✅ BUTTONS (Blue + shaped)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(fontSize: 16),
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),

                              const SizedBox(width: 12),

                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryBlueDark,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                ),
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;

                                  final prefs = await SharedPreferences.getInstance();
                                  final password = prefs.getString('password');

                                  File? img = newImageFile != null ? File(newImageFile!.path) : null;

                                  final success = await ApiService.editBill(
                                    employeeId: _employeeId.toString(),
                                    password: password!,
                                    billId: bill.billId,
                                    reimbursementFor: selectedCategory,
                                    amount: double.parse(amountController.text),
                                    date: selectedDate,
                                    billImage: img,
                                  );

                                  Navigator.pop(context);
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Bill updated!")),
                                    );
                                    _loadBills();
                                  }
                                },
                                child: Text(
                                  "Save",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Future<void> _pickBillImage({required void Function(XFile file) onPicked}) async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);

                  try {
                    final image = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (image != null) onPicked(image);
                  } on PlatformException catch (e) {
                    if (!context.mounted) return;

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Camera Permission Required'),
                        content: const Text(
                          'Camera access is required to capture bill images. '
                              'Please enable it from app settings.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              openAppSettings();
                            },
                            child: const Text('Open Settings'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (image != null) onPicked(image);
                  } on PlatformException catch (e) {
                    if (!context.mounted) return;

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Gallery Permission Required'),
                        content: const Text(
                          'Gallery access is required to select bill images. '
                              'Please enable it from app settings.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              openAppSettings();
                            },
                            child: const Text('Open Settings'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Uint8List?> _fetchImageWithAuth(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final employeeId = prefs.getInt('employee_id')?.toString() ?? '';
    final password = prefs.getString('password') ?? '';

    final response = await http.get(
      Uri.parse(url),
      headers: ApiService.getAuthHeaders(employeeId, password),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      debugPrint('Failed to load image: ${response.statusCode}');
      return null;
    }
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

  void _showBillOptions(Bill bill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ✅ REJECTED REMARK (Only if rejected)
                  if (bill.status.toLowerCase() == 'rejected' && bill.remarks != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bill.remarks!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ✅ EDIT BILL
                  ListTile(
                    leading: Icon(Icons.edit_rounded, color: kPrimaryBlueDark),
                    title: const Text("Edit Bill", style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditBillDialog(bill);
                    },
                  ),

                  // ✅ DELETE BILL
                  ListTile(
                    leading: const Icon(Icons.delete_rounded, color: Colors.red),
                    title: const Text("Delete Bill", style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmationDialog(bill);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 60), // reduces padding
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
                        Text("Select range", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                          child: Text("Save"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // CALENDAR
                    TableCalendar(
                      focusedDay: start != null ? start!: DateTime.now(),
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
                        ElevatedButton.icon(
                          icon: Icon(Icons.date_range),
                          label: Text("Show All"),
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _startDate = DateTime(2020);
                              _endDate = DateTime.now();
                            });
                            _applyFilters();
                          },
                        )
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

  void _viewBillImage(Bill bill) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('employee_id')?.toString() ?? '';
    final password = prefs.getString('password') ?? '';

    final imageUrl = '${ApiService.baseUrl}/files/${bill.billImagePath}';

    Uint8List? bytes;

    // ✅ Try cache first
    if (_imageCache.containsKey(imageUrl)) {
      bytes = _imageCache[imageUrl]!;
    } else {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: ApiService.getAuthHeaders(userId, password),
      );

      if (response.statusCode != 200) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: const Text('Could not load image.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              )
            ],
          ),
        );
        return;
      }

      bytes = response.bodyBytes;
      _imageCache[imageUrl] = bytes;
    }

    // ✅ MODERN VIEWER
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
                    // ✅ Top Bar
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
                          const Expanded(
                            child: Center(
                              child: Text(
                                "Bill Image",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white
                                ),
                              ),
                            ),
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
                          child: Center(
                            child: Image.memory(
                              bytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
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

      // ✅ Fade + Scale Animation
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim),
            child: child,
          ),
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }
}