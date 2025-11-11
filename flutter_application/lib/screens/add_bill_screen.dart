import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ConnectivityService.dart';
import '../services/api_service.dart';
import '../services/ocr_service.dart';
import '../services/offline_queue_service.dart';

class AddBillScreen extends StatefulWidget {
  final int employeeId;

  const AddBillScreen({super.key, required this.employeeId});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  Color kPrimaryBlue = Color(0xFF2196F3);
  Color kPrimaryBlueDark = Color(0xFF1E3A8A);
  Color kBgTop = Color(0xFFE3F2FD);
  Color kBgBottom = Color(0xFFBBDEFB);

  String _selectedCategory = 'Travel';
  DateTime _selectedDate = DateTime.now();
  File? _imageFile;
  bool _isLoading = false;
  bool _isAnalyzing = false;

  final List<String> _reimbursementCategories = [
    'Parking', 'Travel', 'Food', 'Office Supplies', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    if (!_reimbursementCategories.contains(_selectedCategory)) {
      _selectedCategory = _reimbursementCategories.first;
    }
  }

  Widget glassCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.08),
                blurRadius: 18,
                offset: Offset(0, 10),
              )
            ],
          ),
          child: child,
        ),
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
        title: const Text("Add New Bill"),
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
        child: Stack(
          children: [

            // ✅ MAIN CONTENT
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 90, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [

                    // ✅ Category + Amount + Date card (glass)
                    glassCard(
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Reimbursement For',
                              prefixIcon: Icon(Icons.category_rounded, color: kPrimaryBlue),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            items: _reimbursementCategories
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedCategory = v!),
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              labelText: 'Amount (₹)',
                              prefixIcon: Icon(Icons.currency_rupee_rounded, color: kPrimaryBlue),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                            (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0)
                                ? 'Enter valid amount'
                                : null,
                          ),

                          const SizedBox(height: 16),

                          InkWell(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date',
                                prefixIcon: Icon(Icons.calendar_today_rounded, color: kPrimaryBlue),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(_selectedDate),
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ Image Upload Glass Card
                    glassCard(
                      child: Column(
                        children: [

                          Text("Bill Image",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kPrimaryBlueDark)),

                          const SizedBox(height: 16),

                          // ✅ Preview box
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey.shade300,
                              child: _imageFile != null
                                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                                  : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image, size: 70, color: Colors.grey.shade600),
                                  SizedBox(height: 6),
                                  Text("No image selected", style: TextStyle(color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _pickAndProcessImage(ImageSource.gallery),
                                  icon: Icon(Icons.photo, color: Colors.white),
                                  label: Text("Gallery", style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryBlue,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _pickAndProcessImage(ImageSource.camera),
                                  icon: Icon(Icons.camera_alt, color: Colors.white),
                                  label: Text("Camera", style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryBlue,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ Submit button (Modern Blue)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitBill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryBlueDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text("Submit Bill",
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✅ OCR overlay (unchanged)
            if (_isAnalyzing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text("Analyzing bill...", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    setState(() {
      _imageFile = imageFile;
      _isAnalyzing = true;
    });

    try {
      final extractedData = await OcrService.processImage(imageFile);
      print("DEBUG OCR Result: $extractedData");

      if (extractedData['amount'] != null) {
        _amountController.text = (extractedData['amount'] as double).toStringAsFixed(2);
      }
      if (extractedData['date'] != null) {
        setState(() {
          _selectedDate = extractedData['date'] as DateTime;
        });
      }
      if (extractedData['category'] != null) {
        setState(() {
          _selectedCategory = extractedData['category'] as String;
        });
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not analyze image.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _submitBill() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      _showErrorDialog("Please select a bill image");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final password = prefs.getString('password');
      if (password == null) return;

      final employeeId = widget.employeeId.toInt();

      final bool backendAvailable = await ConnectivityService.isBackendAvailable();
      if (!backendAvailable) {
        _showErrorDialog("Unable to connect to server. Bill saved locally and will auto-upload when connected.");
        setState(() => _isLoading = false);

        await OfflineQueueService.queueBill(
          category: _selectedCategory,
          amount: double.parse(_amountController.text),
          date: _selectedDate,
          image: _imageFile!,
        );

        return;
      }
      else {
        final success = await ApiService.addBill(
          employeeId: employeeId,
          password: password,
          reimbursementFor: _selectedCategory,
          amount: double.parse(_amountController.text),
          date: _selectedDate,
          billImage: _imageFile!,
        );

        if (success && mounted) {
          Navigator.pop(context, true);
        } else {
          _showErrorDialog("Server unreachable, bill saved offline.");

          await OfflineQueueService.queueBill(
            category: _selectedCategory,
            amount: double.parse(_amountController.text),
            date: _selectedDate,
            image: _imageFile!,
          );
        }
      }
    }
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
    finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  Future<void> saveBillOffline(Map<String, dynamic> billData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList('offline_bills') ?? [];
    queue.add(billData.toString());
    await prefs.setStringList('offline_bills', queue);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}