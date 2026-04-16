import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart';
import '../services/compression_service.dart';
import '../services/ocr_service.dart';
import '../services/offline_queue_service.dart';
import 'package:flutter/foundation.dart';

/// Holds data for a single entry in batch mode.
class _BatchEntry {
  DateTime date = DateTime.now();
  final TextEditingController amountController = TextEditingController();
  PlatformFile? billFile;
  PlatformFile? paymentProofFile; // each entry has its own payment receipt
}

class AddBillScreen extends StatefulWidget {
  final int employeeId;

  const AddBillScreen({super.key, required this.employeeId});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Color kPrimaryBlue = const Color(0xFF2196F3);
  Color kPrimaryBlueDark = const Color(0xFF1E3A8A);
  Color kBgTop = const Color(0xFFE3F2FD);
  Color kBgBottom = const Color(0xFFBBDEFB);

  String _selectedCategory = 'Parking';
  DateTime _selectedDate = DateTime.now();

  // Single mode files
  PlatformFile? _billFile;
  PlatformFile? _approvalMailFile;
  PlatformFile? _paymentProofFile;

  // Batch mode
  bool _batchMode = false;
  final List<_BatchEntry> _batchEntries = [];

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
                offset: const Offset(0, 10),
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
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kBgTop, kBgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  physics: const ClampingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [

                        // 1. CATEGORY + BATCH TOGGLE (always on top)
                        glassCard(
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedCategory,
                                decoration: InputDecoration(
                                  labelText: 'Reimbursement For',
                                  prefixIcon: Icon(Icons.category_rounded, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                items: _reimbursementCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _selectedCategory = v!;
                                    if (_selectedCategory == 'Parking') {
                                      _descriptionController.clear();
                                      _approvalMailFile = null;
                                      _paymentProofFile = null;
                                    }
                                  });
                                },
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Icon(Icons.layers_rounded, color: kPrimaryBlue, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Submit multiple bills",
                                    style: TextStyle(fontSize: 15, color: kPrimaryBlueDark, fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: _batchMode,
                                    activeColor: kPrimaryBlue,
                                    onChanged: (v) {
                                      setState(() {
                                        _batchMode = v;
                                        if (v) {
                                          _batchEntries.add(_BatchEntry());
                                        } else {
                                          for (var e in _batchEntries) e.amountController.dispose();
                                          _batchEntries.clear();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 2a. SINGLE MODE: bill + amount + date together
                        if (!_batchMode)
                          glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Bill / Receipt picker
                                Text("Bill / Receipt", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kPrimaryBlueDark)),
                                const SizedBox(height: 12),
                                if (_billFile != null) ...[
                                  _buildFilePreview(
                                    file: _billFile!,
                                    onClear: () => setState(() => _billFile = null),
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _pickFile('bill'),
                                          icon: Icon(Icons.upload_file, color: kPrimaryBlue),
                                          label: Text("Select File", style: TextStyle(color: kPrimaryBlue)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _pickWithCamera,
                                          icon: Icon(Icons.camera_alt, color: kPrimaryBlue),
                                          label: Text("Camera", style: TextStyle(color: kPrimaryBlue)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),

                                // Description (non-parking only)
                                if (_selectedCategory != 'Parking') ...[
                                  TextFormField(
                                    controller: _descriptionController,
                                    decoration: InputDecoration(
                                      labelText: 'Description',
                                      hintText: 'Enter bill details',
                                      prefixIcon: Icon(Icons.description_rounded, color: kPrimaryBlue),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    validator: (value) {
                                      if (_selectedCategory != 'Parking' && (value == null || value.isEmpty)) {
                                        return 'Please enter a description';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Amount
                                TextFormField(
                                  controller: _amountController,
                                  decoration: InputDecoration(
                                    labelText: 'Amount (₹)',
                                    prefixIcon: Icon(Icons.currency_rupee_rounded, color: kPrimaryBlue),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0)
                                      ? 'Enter valid amount'
                                      : null,
                                ),

                                const SizedBox(height: 16),

                                // Date
                                InkWell(
                                  onTap: _selectDate,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Date of Bill',
                                      prefixIcon: Icon(Icons.calendar_today_rounded, color: kPrimaryBlue),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // 2b. BATCH MODE: description (shared) + entry list
                        if (_batchMode) ...[
                          if (_selectedCategory != 'Parking')
                            glassCard(
                              child: TextFormField(
                                controller: _descriptionController,
                                decoration: InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'Enter bill details',
                                  prefixIcon: Icon(Icons.description_rounded, color: kPrimaryBlue),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                validator: (value) {
                                  if (_selectedCategory != 'Parking' && (value == null || value.isEmpty)) {
                                    return 'Please enter a description';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                          ...List.generate(_batchEntries.length, (i) => _buildBatchEntryCard(i)),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () => setState(() => _batchEntries.add(_BatchEntry())),
                            icon: Icon(Icons.add_circle_outline, color: kPrimaryBlue),
                            label: Text("Add Another Bill", style: TextStyle(color: kPrimaryBlue, fontSize: 15)),
                          ),
                        ],

                        // 4. SUPPORTING DOCS (non-parking)
                        // Approval mail is always shared; payment proof is per-entry in batch mode
                        if (_selectedCategory != 'Parking') ...[
                          const SizedBox(height: 20),
                          _buildFileUploadSection(
                            title: _batchMode
                                ? "Approval Mail — shared for all entries"
                                : "Approval Mail (Screenshot/PDF)",
                            file: _approvalMailFile,
                            onPick: () => _pickFile('approval'),
                            onClear: () => setState(() => _approvalMailFile = null),
                          ),
                          // Payment proof only shown here in single mode; in batch mode it's per-entry
                          if (!_batchMode) ...[
                            const SizedBox(height: 20),
                            _buildFileUploadSection(
                              title: "Payment Proof (Screenshot/PDF)",
                              file: _paymentProofFile,
                              onPick: () => _pickFile('payment'),
                              onClear: () => setState(() => _paymentProofFile = null),
                            ),
                          ],
                        ],

                        const SizedBox(height: 24),

                        // 5. SUBMIT BUTTON
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
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    _batchMode
                                        ? "Submit ${_batchEntries.length} Bill${_batchEntries.length == 1 ? '' : 's'}"
                                        : "Submit Bill",
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
            ),

            // OCR overlay
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

  /// Card for a single entry in batch mode.
  Widget _buildBatchEntryCard(int index) {
    final entry = _batchEntries[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Bill ${index + 1}",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kPrimaryBlueDark),
                ),
                const Spacer(),
                if (_batchEntries.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: "Remove",
                    onPressed: () {
                      setState(() {
                        _batchEntries[index].amountController.dispose();
                        _batchEntries.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Bill file picker for this entry (first — OCR auto-fills amount & date)
            _buildFileUploadSection(
              title: "Bill / Receipt",
              file: entry.billFile,
              onPick: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                );
                if (result != null) {
                  setState(() => entry.billFile = result.files.first);
                  final f = result.files.first;
                  if (f.extension?.toLowerCase() != 'pdf' && f.path != null) {
                    _runOcr(File(f.path!));
                  }
                }
              },
              onClear: () => setState(() => entry.billFile = null),
              allowCamera: true,
              onCamera: () async {
                try {
                  final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
                  if (pickedFile == null) return;
                  setState(() {
                    entry.billFile = PlatformFile(
                      name: pickedFile.name,
                      size: 0,
                      path: pickedFile.path,
                    );
                  });
                  _runOcr(File(pickedFile.path));
                } on PlatformException catch (e) {
                  if (e.code == 'camera_access_denied' && mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Camera Permission Required'),
                        content: const Text('Please enable camera access from your device settings.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () { Navigator.pop(context); openAppSettings(); },
                            child: const Text('Open Settings'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
            ),

            const SizedBox(height: 12),

            // Amount (OCR may have pre-filled this)
            TextFormField(
              controller: entry.amountController,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded, color: kPrimaryBlue),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 12),

            // Date (OCR may have pre-filled this)
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: entry.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => entry.date = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date of Bill',
                  prefixIcon: Icon(Icons.calendar_today_rounded, color: kPrimaryBlue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(entry.date), style: const TextStyle(fontSize: 16)),
              ),
            ),

            // Payment proof per entry (non-parking only)
            if (_selectedCategory != 'Parking') ...[
              const SizedBox(height: 12),
              _buildFileUploadSection(
                title: "Payment Proof",
                file: entry.paymentProofFile,
                onPick: () async {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                  );
                  if (result != null) setState(() => entry.paymentProofFile = result.files.first);
                },
                onClear: () => setState(() => entry.paymentProofFile = null),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shows the selected file preview row (thumbnail or PDF icon + filename + clear button).
  /// Used inline inside combined cards where the pick buttons are built separately.
  Widget _buildFilePreview({required PlatformFile file, required VoidCallback onClear}) {
    final bool isPdf = file.extension?.toLowerCase() == 'pdf';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          if (!isPdf && !kIsWeb && file.path != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(file.path!), width: 60, height: 60, fit: BoxFit.cover),
            )
          else
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
            ),
          const SizedBox(width: 12),
          Expanded(child: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
          IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), onPressed: onClear),
        ],
      ),
    );
  }

  // REUSABLE FILE UPLOAD UI (used for approval mail, payment proof, and batch entry bill pickers)
  Widget _buildFileUploadSection({
    required String title,
    required PlatformFile? file,
    required VoidCallback onPick,
    required VoidCallback onClear,
    bool allowCamera = false,
    VoidCallback? onCamera,
  }) {
    bool isPdf = file?.extension?.toLowerCase() == 'pdf';

    return glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kPrimaryBlueDark)),
          const SizedBox(height: 12),

          if (file != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  if (!isPdf && !kIsWeb && file.path != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(file.path!), width: 60, height: 60, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                    ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: onClear,
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPick,
                    icon: Icon(Icons.upload_file, color: kPrimaryBlue),
                    label: Text("Select File", style: TextStyle(color: kPrimaryBlue)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (allowCamera) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCamera ?? _pickWithCamera,
                      icon: Icon(Icons.camera_alt, color: kPrimaryBlue),
                      label: Text("Camera", style: TextStyle(color: kPrimaryBlue)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]
              ],
            )
          ]
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      setState(() {
        if (type == 'bill') _billFile = file;
        else if (type == 'approval') _approvalMailFile = file;
        else if (type == 'payment') _paymentProofFile = file;
      });

      if (type == 'bill' && file.extension?.toLowerCase() != 'pdf' && file.path != null) {
        _runOcr(File(file.path!));
      }
    }
  }

  Future<void> _pickWithCamera() async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
      if (pickedFile == null) return;

      setState(() {
        _billFile = PlatformFile(
          name: pickedFile.name,
          size: 0,
          path: pickedFile.path,
        );
      });

      _runOcr(File(pickedFile.path));

    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Camera Permission Required'),
            content: const Text(
              'Camera access is required to capture bill images. '
                  'Please enable it from your device settings.',
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open camera: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runOcr(File image) async {
    setState(() => _isAnalyzing = true);
    try {
      final extractedData = await OcrService.processImage(image);
      if (extractedData['amount'] != null && _amountController.text.isEmpty) {
        _amountController.text = (extractedData['amount'] as double).toStringAsFixed(2);
      }
      if (extractedData['date'] != null) setState(() => _selectedDate = extractedData['date'] as DateTime);
      if (extractedData['category'] != null) setState(() => _selectedCategory = extractedData['category'] as String);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not analyze image.'), backgroundColor: Colors.orange));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _submitBill() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final password = prefs.getString('password');
      if (password == null) return;

      final employeeId = widget.employeeId.toInt();

      // ── BATCH MODE ──────────────────────────────────────────────
      if (_batchMode) {
        // Validate all entries
        for (int i = 0; i < _batchEntries.length; i++) {
          final entry = _batchEntries[i];
          if (entry.billFile == null || entry.billFile!.path == null) {
            _showErrorDialog("Please upload a bill receipt for Bill ${i + 1}.");
            return;
          }
          final amt = double.tryParse(entry.amountController.text);
          if (amt == null || amt <= 0) {
            _showErrorDialog("Please enter a valid amount for Bill ${i + 1}.");
            return;
          }
          if (_selectedCategory != 'Parking' && entry.paymentProofFile == null) {
            _showErrorDialog("Please upload a payment proof for Bill ${i + 1}.");
            return;
          }
        }
        if (_selectedCategory != 'Parking' && _approvalMailFile == null) {
          _showErrorDialog("Approval Mail is required for this category.");
          return;
        }

        final bool backendAvailable = await ConnectivityService.isBackendAvailable();
        if (!backendAvailable) {
          _showErrorDialog("Unable to connect to server. Please try again when connected.");
          return;
        }

        // Compress shared approval mail once
        File? sharedApproval = await CompressionService.compressNullable(
            _approvalMailFile?.path != null ? File(_approvalMailFile!.path!) : null);

        int successCount = 0;
        for (final entry in _batchEntries) {
          File billFile = await CompressionService.compressFile(File(entry.billFile!.path!));
          File? entryPayment = await CompressionService.compressNullable(
              entry.paymentProofFile?.path != null ? File(entry.paymentProofFile!.path!) : null);
          final ok = await ApiService.addBill(
            employeeId: employeeId,
            password: password,
            reimbursementFor: _selectedCategory,
            description: _descriptionController.text.trim(),
            amount: double.parse(entry.amountController.text),
            date: entry.date,
            billImage: billFile,
            approvalMail: sharedApproval,
            paymentProof: entryPayment,
          );
          if (ok) successCount++;
        }

        if (!mounted) return;
        if (successCount == _batchEntries.length) {
          Navigator.pop(context, true);
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount of ${_batchEntries.length} bills submitted successfully.'),
              backgroundColor: successCount > 0 ? Colors.orange : Colors.red,
            ),
          );
        }
        return;
      }

      // ── SINGLE MODE ─────────────────────────────────────────────
      if (_billFile == null || _billFile!.path == null) {
        _showErrorDialog("Please upload the main bill receipt.");
        return;
      }
      if (_selectedCategory != 'Parking') {
        if (_approvalMailFile == null || _paymentProofFile == null) {
          _showErrorDialog("Approval Mail and Payment Proof are required for this category.");
          return;
        }
      }

      final bool backendAvailable = await ConnectivityService.isBackendAvailable();

      File mainBill = await CompressionService.compressFile(File(_billFile!.path!));
      File? approvalMail = await CompressionService.compressNullable(
          _approvalMailFile?.path != null ? File(_approvalMailFile!.path!) : null);
      File? paymentProof = await CompressionService.compressNullable(
          _paymentProofFile?.path != null ? File(_paymentProofFile!.path!) : null);

      if (!backendAvailable) {
        _showErrorDialog("Unable to connect to server. Bill saved locally and will auto-upload when connected.");
        setState(() => _isLoading = false);

        await OfflineQueueService.queueBill(
          category: _selectedCategory,
          amount: double.parse(_amountController.text),
          date: _selectedDate,
          image: XFile(mainBill.path),
        );
        return;
      }

      final success = await ApiService.addBill(
        employeeId: employeeId,
        password: password,
        reimbursementFor: _selectedCategory,
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        date: _selectedDate,
        billImage: mainBill,
        approvalMail: approvalMail,
        paymentProof: paymentProof,
      );

      if (success && mounted) {
        Navigator.pop(context, true);
      } else {
        _showErrorDialog("Submission failed. Please try again.");
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

  void _showErrorDialog(String msg) {
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [TextButton(child: const Text("OK"), onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    for (var e in _batchEntries) e.amountController.dispose();
    super.dispose();
  }
}
