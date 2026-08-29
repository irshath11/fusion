import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/work_photo_report_pdf_service.dart';
import '../../../core/utils/work_photo_picker.dart';
import '../../../database/local_database_service.dart';
import '../../attendance/presentation/camera_capture_modal.dart';
import 'work_photo_history_screen.dart';

class WorkPhotosReportScreen extends StatefulWidget {
  const WorkPhotosReportScreen({super.key});

  @override
  State<WorkPhotosReportScreen> createState() => _WorkPhotosReportScreenState();
}

class _WorkPhotosReportScreenState extends State<WorkPhotosReportScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final _formKey = GlobalKey<FormState>();

  DateTime _reportDate = DateTime.now();

  late TextEditingController _dateController;
  final TextEditingController _workTitleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _employeeNameController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  final List<String> _photosList = [];

  bool _isSyncing = false;
  int _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateFormat('dd MMM yyyy').format(_reportDate),
    );
    _loadEmployeeData();
    _updatePendingCount();
  }

  void _updatePendingCount() {
    final pending = _db.getPendingWorkPhotoSubmissions();
    setState(() {
      _pendingSyncCount = pending.length;
    });
  }

  void _loadEmployeeData() {
    final user = _db.currentUser;
    if (user != null) {
      final empName = user.fullName.isNotEmpty ? user.fullName : user.name;
      if (empName.isNotEmpty) {
        setState(() {
          _employeeNameController.text = empName;
        });
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _workTitleController.dispose();
    _locationController.dispose();
    _employeeNameController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  WorkPhotoReportData _buildReportData() {
    return WorkPhotoReportData(
      reportRefNumber: '',
      reportDate: _reportDate,
      workTitle: _workTitleController.text.trim(),
      location: _locationController.text.trim(),
      employeeName: _employeeNameController.text.trim(),
      remarks: _remarksController.text.trim(),
      photos: List.from(_photosList),
    );
  }

  Future<void> _captureWorkPhotoFromCamera() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CameraCaptureModal(
        stepName: 'Work Photo Evidence',
        onPhotoCaptured: (cameraResult) {
          if (cameraResult.base64Image.isNotEmpty) {
            setState(() {
              _photosList.add(cameraResult.base64Image);
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Work photo captured successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _uploadWorkPhotosFromGallery() async {
    try {
      final pickedList = await WorkPhotoPicker.pickGalleryImages();
      if (pickedList.isNotEmpty) {
        setState(() {
          _photosList.addAll(pickedList);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${pickedList.length} photo(s) to report.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Gallery picker error: $e');
    }
  }

  Future<void> _previewPdfReport() async {
    if (_photosList.isEmpty &&
        _workTitleController.text.trim().isEmpty &&
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add work title, location, or attach photos before previewing.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final data = _buildReportData();
    final pdfBytes = await WorkPhotoReportPdfService.buildPdfBytes(data);

    if (!mounted) return;
    final dateStr = DateFormat('yyyyMMdd').format(_reportDate);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Work_Photos_Report_$dateStr.pdf',
    );
  }

  Future<void> _exportAndSharePdf() async {
    if (_photosList.isEmpty &&
        _workTitleController.text.trim().isEmpty &&
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add work title, location, or attach photos before exporting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final data = _buildReportData();
    final pdfBytes = await WorkPhotoReportPdfService.buildPdfBytes(data);

    final dateStr = DateFormat('yyyyMMdd').format(_reportDate);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Work_Photos_Report_$dateStr.pdf',
    );
  }

  void _openImagePreview(Uint8List bytes, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.7),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncPendingReports({bool showToast = true}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final count = await SupabaseService().syncPendingWorkPhotoSubmissions();
      _updatePendingCount();
      if (!mounted) return;

      if (showToast) {
        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully synced $count offline work photo report(s) to cloud!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All work photo reports are up to date!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _saveAndUploadWorkPhotos() async {
    if (_photosList.isEmpty &&
        _workTitleController.text.trim().isEmpty &&
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add work title, location, or attach photos before uploading.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final submission = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'reportDate': _reportDate.toIso8601String(),
        'workTitle': _workTitleController.text.trim(),
        'location': _locationController.text.trim(),
        'employeeName': _employeeNameController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'photos': List<String>.from(_photosList),
      };

      await _db.saveWorkPhotoSubmissionLocally(submission);
      _updatePendingCount();

      // Trigger automatic cloud sync
      final syncedCount = await SupabaseService().syncPendingWorkPhotoSubmissions();
      _updatePendingCount();

      if (!mounted) return;
      final bool isSynced = syncedCount > 0 || _pendingSyncCount == 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSynced ? Icons.check_circle_rounded : Icons.offline_pin_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSynced
                      ? 'Successfully saved and synced ${_photosList.length} work photo(s) to cloud!'
                      : 'Saved locally (Offline mode)! ${_pendingSyncCount} report(s) pending sync.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'View Records',
            textColor: Colors.amberAccent,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkPhotoHistoryScreen()),
              );
            },
          ),
          backgroundColor: isSynced ? Colors.green.shade700 : Colors.orange.shade800,
          duration: const Duration(seconds: 4),
        ),
      );

      _clearAllFields();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save photos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearAllFields() {
    setState(() {
      _reportDate = DateTime.now();
      _dateController.text = DateFormat('dd MMM yyyy').format(_reportDate);
      _workTitleController.clear();
      _locationController.clear();
      _remarksController.clear();
      _photosList.clear();
    });
    _loadEmployeeData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Upload Work Site Photos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Sync Offline Reports',
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, color: Colors.white),
                onPressed: () => _syncPendingReports(showToast: true),
              ),
              if (_pendingSyncCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_pendingSyncCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'View Uploaded Records',
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkPhotoHistoryScreen()),
              ).then((_) => _updatePendingCount());
            },
          ),
          IconButton(
            tooltip: 'Clear Form',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Form'),
                  content: const Text('Are you sure you want to reset all fields and photos?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearAllFields();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Clear', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Details Form Section
              _buildSectionCard(
                isDark: isDark,
                title: '1. Work & Location Information',
                icon: Icons.info_outline_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2, // Wider Date tab for comfortable display
                          child: TextFormField(
                            controller: _dateController,
                            readOnly: true,
                            decoration: _inputDecoration('Report Date', isDark).copyWith(
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_month_rounded, size: 20),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _reportDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _reportDate = picked;
                                      _dateController.text =
                                          DateFormat('dd MMM yyyy').format(picked);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _workTitleController,
                            decoration: _inputDecoration(
                              'Work Title (e.g. AHU Fan Replacement)',
                              isDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            decoration: _inputDecoration(
                              'Location / Site (e.g. Tower A Floor 5)',
                              isDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _employeeNameController,
                            decoration: _inputDecoration('Prepared By (Technician)', isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 2,
                      decoration: _inputDecoration(
                        'Work Description / Notes (Optional)',
                        isDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Photos Section
              _buildSectionCard(
                isDark: isDark,
                title: '2. Upload Site Photos & Evidence',
                icon: Icons.photo_camera_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _captureWorkPhotoFromCamera,
                              icon: const Icon(Icons.camera_alt_rounded, size: 20),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4.0),
                                child: Text(
                                  'Take Camera Photo',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _uploadWorkPhotosFromGallery,
                              icon: const Icon(Icons.photo_library_rounded, size: 20),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4.0),
                                child: Text(
                                  'Upload from Device',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_photosList.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Attached Work Photos (${_photosList.length}):',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _photosList.clear();
                              });
                            },
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            label: const Text('Remove All', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _photosList.length,
                        itemBuilder: (ctx, idx) {
                          final b64 = _photosList[idx];
                          final cleanB64 = b64.contains(',') ? b64.split(',').last : b64;
                          Uint8List? bytes;
                          try {
                            bytes = base64Decode(cleanB64);
                          } catch (_) {}

                          return GestureDetector(
                            onTap: () {
                              if (bytes != null) _openImagePreview(bytes, idx);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: bytes != null
                                          ? Image.memory(bytes, fit: BoxFit.cover)
                                          : Container(
                                              color: Colors.grey.shade800,
                                              child: const Icon(Icons.image, color: Colors.white),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '#${idx + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _photosList.removeAt(idx);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 40,
                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No photos attached yet.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use Camera or Upload from Device above to add work photos.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons Row: Direct Image Upload Primary Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveAndUploadWorkPhotos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 22),
                  label: const Text(
                    'Upload & Save Work Photos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _previewPdfReport,
                    icon: Icon(Icons.visibility_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black54),
                    label: Text(
                      'Preview PDF',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _exportAndSharePdf,
                    icon: Icon(Icons.picture_as_pdf_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black54),
                    label: Text(
                      'Export / Share PDF',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardBoxDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardBoxDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 1),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.white60 : Colors.black54,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

