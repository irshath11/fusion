import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/services/employee_report_pdf_service.dart';
import '../../../core/widgets/e_signature_pad.dart';
import '../../../database/local_database_service.dart';

class EmployeeReportGeneratorScreen extends StatefulWidget {
  const EmployeeReportGeneratorScreen({super.key});

  @override
  State<EmployeeReportGeneratorScreen> createState() =>
      _EmployeeReportGeneratorScreenState();
}

class _EmployeeReportGeneratorScreenState
    extends State<EmployeeReportGeneratorScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final _formKey = GlobalKey<FormState>();

  // Report Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _workOrderController = TextEditingController();

  // Site & Client Location Controllers
  final TextEditingController _siteController = TextEditingController();
  final TextEditingController _locationDetailsController = TextEditingController();
  final TextEditingController _clientController = TextEditingController();

  // Personnel Controllers
  final TextEditingController _technicianNameController = TextEditingController();
  final TextEditingController _technicianCodeController = TextEditingController();
  final TextEditingController _engineerNameController = TextEditingController();
  final TextEditingController _supervisorController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerTitleController = TextEditingController();

  // Remarks Controller
  final TextEditingController _remarksController = TextEditingController();

  String _selectedCategory = 'Daily Work Report';
  DateTime _reportDate = DateTime.now();
  late String _refNumber;

  // 4 Digital Signatures
  Uint8List? _technicianSigBytes;
  Uint8List? _engineerSigBytes;
  Uint8List? _supervisorSigBytes;
  Uint8List? _customerSigBytes;

  String _empDept = 'Technical & Contracting';

  // Task entries list
  final List<_TaskFormItem> _taskItems = [];

  final List<String> _reportCategories = [
    'Daily Work Report',
    'Field Duty Report',
    'Site Inspection Report',
    'Maintenance Service Report',
    'Incident & Safety Report',
  ];

  @override
  void initState() {
    super.initState();
    _refNumber = 'REP-${DateFormat('yyyyMMdd').format(DateTime.now())}-${Random().nextInt(900) + 100}';
    _titleController.text = 'Daily Work Activity Report';
    _workOrderController.text = 'WO-${Random().nextInt(9000) + 1000}';
    _locationDetailsController.text = 'Building 1, Main Duty Area';
    _engineerNameController.text = 'Eng. Mohamed Al-Mansoori';
    _supervisorController.text = 'Eng. Hassan Ahmed';
    _customerNameController.text = 'Mr. John Smith';
    _customerTitleController.text = 'Facility Operations Manager';
    _loadEmployeeData();
    _addInitialTask();
  }

  void _loadEmployeeData() {
    final user = _db.currentUser;
    if (user != null) {
      final employees = _db.getEmployees();
      final emp = employees.where((e) => e.id == user.id || e.email == user.email).firstOrNull;
      final assignedSite = emp?.assignedOfficeName ?? user.assignedOfficeName ?? 'Abu Dhabi Main Work Site';

      final empName = user.fullName.isNotEmpty ? user.fullName : (user.name.isNotEmpty ? user.name : 'Technician');
      final empCode = user.employeeCode ?? (user.id.length >= 4 ? 'EMP-${user.id.substring(0, 4)}' : 'EMP-1001');

      setState(() {
        _technicianNameController.text = empName;
        _technicianCodeController.text = empCode;
        _empDept = user.department ?? 'Field Engineering';
        _siteController.text = assignedSite;
        _clientController.text = 'Fusion Neo Contracting';
      });
    } else {
      setState(() {
        _technicianNameController.text = 'Technician Name';
        _technicianCodeController.text = 'EMP-1001';
        _empDept = 'Technical Department';
        _siteController.text = 'Abu Dhabi Site 1';
        _clientController.text = 'Client Enterprise';
      });
    }
  }

  void _addInitialTask() {
    _taskItems.add(_TaskFormItem(
      descController: TextEditingController(text: 'Site inspection and workforce duty coordination'),
      durationController: TextEditingController(text: '4.0 hrs'),
      status: 'Completed',
      notesController: TextEditingController(text: 'Completed according to safety schedule'),
    ));
    _taskItems.add(_TaskFormItem(
      descController: TextEditingController(text: 'Equipment check and maintenance verification'),
      durationController: TextEditingController(text: '3.5 hrs'),
      status: 'Completed',
      notesController: TextEditingController(text: 'All mechanical systems operational'),
    ));
  }

  void _addNewTaskRow() {
    setState(() {
      _taskItems.add(_TaskFormItem(
        descController: TextEditingController(),
        durationController: TextEditingController(text: '1.0 hr'),
        status: 'Completed',
        notesController: TextEditingController(),
      ));
    });
  }

  void _removeTaskRow(int index) {
    if (_taskItems.length <= 1) return;
    setState(() {
      final item = _taskItems.removeAt(index);
      item.dispose();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _workOrderController.dispose();
    _siteController.dispose();
    _locationDetailsController.dispose();
    _clientController.dispose();
    _technicianNameController.dispose();
    _technicianCodeController.dispose();
    _engineerNameController.dispose();
    _supervisorController.dispose();
    _customerNameController.dispose();
    _customerTitleController.dispose();
    _remarksController.dispose();
    for (final t in _taskItems) {
      t.dispose();
    }
    super.dispose();
  }

  EmployeeReportData _buildReportData() {
    final taskEntries = _taskItems.map((item) {
      return ReportTaskEntry(
        description: item.descController.text.trim().isNotEmpty
            ? item.descController.text.trim()
            : 'General Field Task',
        durationOrQty: item.durationController.text.trim().isNotEmpty
            ? item.durationController.text.trim()
            : '1.0 hr',
        status: item.status,
        notes: item.notesController.text.trim().isNotEmpty
            ? item.notesController.text.trim()
            : '--',
      );
    }).toList();

    return EmployeeReportData(
      reportTitle: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : _selectedCategory,
      reportCategory: _selectedCategory,
      reportRefNumber: _refNumber,
      reportDate: _reportDate,
      workOrderNumber: _workOrderController.text.trim().isNotEmpty
          ? _workOrderController.text.trim()
          : 'WO-1001',
      siteLocation: _siteController.text.trim().isNotEmpty
          ? _siteController.text.trim()
          : 'Field Site',
      locationDetails: _locationDetailsController.text.trim(),
      clientName: _clientController.text.trim(),
      technicianName: _technicianNameController.text.trim(),
      technicianCode: _technicianCodeController.text.trim(),
      department: _empDept,
      engineerName: _engineerNameController.text.trim(),
      supervisorName: _supervisorController.text.trim(),
      customerName: _customerNameController.text.trim(),
      customerTitle: _customerTitleController.text.trim(),
      taskEntries: taskEntries,
      generalRemarks: _remarksController.text.trim(),
      technicianSigBytes: _technicianSigBytes,
      engineerSigBytes: _engineerSigBytes,
      supervisorSigBytes: _supervisorSigBytes,
      customerSigBytes: _customerSigBytes,
    );
  }

  Future<void> _openSignatureModalForRole(String roleKey) async {
    final bytes = await showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ESignatureDialog(),
    );

    if (bytes != null && bytes.isNotEmpty) {
      setState(() {
        switch (roleKey) {
          case 'technician':
            _technicianSigBytes = bytes;
            break;
          case 'engineer':
            _engineerSigBytes = bytes;
            break;
          case 'supervisor':
            _supervisorSigBytes = bytes;
            break;
          case 'customer':
            _customerSigBytes = bytes;
            break;
        }
      });
    }
  }

  void _previewPdfReport() {
    if (!_formKey.currentState!.validate()) return;
    final reportData = _buildReportData();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'PDF Report Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (format) => EmployeeReportPdfService.buildReportPdfBytes(reportData),
                allowPrinting: true,
                allowSharing: true,
                canChangePageFormat: false,
                canChangeOrientation: false,
                maxPageWidth: 700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndSharePdf() async {
    if (!_formKey.currentState!.validate()) return;

    if (_technicianSigBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add Technician E-Signature before exporting the final report.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final reportData = _buildReportData();
    await EmployeeReportPdfService.shareOrDownloadReportPdf(reportData);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.currentColors.primaryFor(Theme.of(context).brightness);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employee Report Generator',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Create Custom PDF with 4-Role Signatures & Company Seal',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Preview PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _previewPdfReport,
          ),
        ],
      ),
      body: Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Card 1: Header & Report Metadata
              _buildSectionCard(
                isDark: isDark,
                title: 'Report Type & Metadata',
                icon: Icons.assignment_rounded,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: _inputDecoration('Report Category', isDark),
                      items: _reportCategories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                            _titleController.text = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration('Report Title', isDark),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter report title' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _reportDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  _reportDate = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: _inputDecoration('Report Date', isDark),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(DateFormat('dd MMM yyyy').format(_reportDate)),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _workOrderController,
                            decoration: _inputDecoration('Work Order / LPO #', isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 2: Client & Site Location Details
              _buildSectionCard(
                isDark: isDark,
                title: 'Client & Work Site Location',
                icon: Icons.location_city_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _clientController,
                            decoration: _inputDecoration('Client / Company Name', isDark),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter client name' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _siteController,
                            decoration: _inputDecoration('Work Site / Project Name', isDark),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter work site' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationDetailsController,
                      decoration: _inputDecoration('Location Specifics (Building, Zone, Area)', isDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 3: Personnel & Team Info
              _buildSectionCard(
                isDark: isDark,
                title: 'Project Personnel & Team',
                icon: Icons.badge_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _technicianNameController,
                            decoration: _inputDecoration('Technician Name', isDark),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter technician name' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _technicianCodeController,
                            decoration: _inputDecoration('Technician Code', isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _engineerNameController,
                            decoration: _inputDecoration('Site Engineer Name', isDark),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _supervisorController,
                            decoration: _inputDecoration('Supervisor Name', isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _customerNameController,
                            decoration: _inputDecoration('Customer Rep Name', isDark),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _customerTitleController,
                            decoration: _inputDecoration('Customer Designation / Title', isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 4: Work Activities & Task Table
              _buildSectionCard(
                isDark: isDark,
                title: 'Work Activities & Task Breakdown',
                icon: Icons.list_alt_rounded,
                action: ElevatedButton.icon(
                  onPressed: _addNewTaskRow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Task', style: TextStyle(fontSize: 12)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _taskItems.length; i++) ...[
                      _buildTaskRow(i, _taskItems[i], isDark),
                      if (i < _taskItems.length - 1) const Divider(height: 24),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card 5: Remarks & Field Observations
              _buildSectionCard(
                isDark: isDark,
                title: 'General Remarks & Field Observations',
                icon: Icons.notes_rounded,
                child: TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: _inputDecoration('Enter any general notes, site conditions, or remarks...', isDark),
                ),
              ),
              const SizedBox(height: 16),

              // Card 6: Authorization & 4-Role E-Signatures
              _buildSectionCard(
                isDark: isDark,
                title: 'Authorization & 4-Role E-Signatures',
                icon: Icons.draw_rounded,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 480;
                    if (isMobile) {
                      return Column(
                        children: [
                          ESignaturePreviewBox(
                            label: '1. Technician E-Signature',
                            signatureBytes: _technicianSigBytes,
                            onTapSign: () => _openSignatureModalForRole('technician'),
                            onClear: () => setState(() => _technicianSigBytes = null),
                          ),
                          const SizedBox(height: 14),
                          ESignaturePreviewBox(
                            label: '2. Engineer E-Signature',
                            signatureBytes: _engineerSigBytes,
                            onTapSign: () => _openSignatureModalForRole('engineer'),
                            onClear: () => setState(() => _engineerSigBytes = null),
                          ),
                          const SizedBox(height: 14),
                          ESignaturePreviewBox(
                            label: '3. Supervisor E-Signature',
                            signatureBytes: _supervisorSigBytes,
                            onTapSign: () => _openSignatureModalForRole('supervisor'),
                            onClear: () => setState(() => _supervisorSigBytes = null),
                          ),
                          const SizedBox(height: 14),
                          ESignaturePreviewBox(
                            label: '4. Customer E-Signature',
                            signatureBytes: _customerSigBytes,
                            onTapSign: () => _openSignatureModalForRole('customer'),
                            onClear: () => setState(() => _customerSigBytes = null),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ESignaturePreviewBox(
                                label: '1. Technician E-Signature',
                                signatureBytes: _technicianSigBytes,
                                onTapSign: () => _openSignatureModalForRole('technician'),
                                onClear: () => setState(() => _technicianSigBytes = null),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ESignaturePreviewBox(
                                label: '2. Engineer E-Signature',
                                signatureBytes: _engineerSigBytes,
                                onTapSign: () => _openSignatureModalForRole('engineer'),
                                onClear: () => setState(() => _engineerSigBytes = null),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ESignaturePreviewBox(
                                label: '3. Supervisor E-Signature',
                                signatureBytes: _supervisorSigBytes,
                                onTapSign: () => _openSignatureModalForRole('supervisor'),
                                onClear: () => setState(() => _supervisorSigBytes = null),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ESignaturePreviewBox(
                                label: '4. Customer E-Signature',
                                signatureBytes: _customerSigBytes,
                                onTapSign: () => _openSignatureModalForRole('customer'),
                                onClear: () => setState(() => _customerSigBytes = null),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _previewPdfReport,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: primaryColor, width: 1.5),
                      ),
                      icon: Icon(Icons.remove_red_eye_rounded, color: primaryColor),
                      label: Text('Preview PDF', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generateAndSharePdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Export & Share PDF', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildTaskRow(int index, _TaskFormItem item, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Task #${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
            ),
            if (_taskItems.length > 1)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: () => _removeTaskRow(index),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: item.descController,
          decoration: _inputDecoration('Task Description / Activity', isDark),
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter task description' : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: item.durationController,
                decoration: _inputDecoration('Duration / Hours', isDark),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: item.status,
                decoration: _inputDecoration('Status', isDark),
                items: ['Completed', 'In Progress', 'Pending'].map((st) {
                  return DropdownMenuItem(value: st, child: Text(st, style: const TextStyle(fontSize: 12)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => item.status = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: item.notesController,
          decoration: _inputDecoration('Notes / Location specifics', isDark),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                action,
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _TaskFormItem {
  final TextEditingController descController;
  final TextEditingController durationController;
  final TextEditingController notesController;
  String status;

  _TaskFormItem({
    required this.descController,
    required this.durationController,
    required this.notesController,
    required this.status,
  });

  void dispose() {
    descController.dispose();
    durationController.dispose();
    notesController.dispose();
  }
}
