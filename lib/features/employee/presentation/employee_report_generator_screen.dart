import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/services/service_report_pdf_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/e_signature_pad.dart';
import '../../../database/local_database_service.dart';
import 'employee_reports_list_screen.dart';

class EmployeeReportGeneratorScreen extends StatefulWidget {
  final ServiceReportData? existingReport;
  const EmployeeReportGeneratorScreen({super.key, this.existingReport});

  @override
  State<EmployeeReportGeneratorScreen> createState() =>
      _EmployeeReportGeneratorScreenState();
}

class _EmployeeReportGeneratorScreenState
    extends State<EmployeeReportGeneratorScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final _formKey = GlobalKey<FormState>();

  late String _refNumber;
  DateTime _reportDate = DateTime.now();

  // Section 1: Property & Call Details Controllers
  final TextEditingController _propertyDetailsController = TextEditingController();
  final TextEditingController _jobNoController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _appointmentTimeController = TextEditingController();
  final TextEditingController _attendedTimeController = TextEditingController();
  final TextEditingController _callBookingTimeController = TextEditingController();
  String _selectedCallType = ''; // 'Complaint', 'Breakdown', 'Preventive'

  // Section 2: Service Required & Priority
  final Set<String> _selectedServices = {};
  final List<String> _allServices = [
    'A/C',
    'CCTV',
    'Fire Fighting',
    'Carpentry',
    'BMS',
    'Electrical',
    'SMATV',
    'Generator',
    'Civil',
    'Access Control',
    'Plumbing',
    'Intercom',
    'Cleaning Service',
    'Painting',
    'Soft Services',
  ];
  final TextEditingController _othersServiceController = TextEditingController();
  String _selectedPriority = ''; // 'Urgent', 'Normal'

  // Section 3: Defects Found on Inspection
  final TextEditingController _defectsFoundController = TextEditingController();

  // Section 4: Material Used Table (5 rows x 2 pairs)
  late List<TextEditingController> _matControllers1;
  late List<TextEditingController> _qtyControllers1;
  late List<TextEditingController> _matControllers2;
  late List<TextEditingController> _qtyControllers2;

  // Section 5: Details of work done
  final TextEditingController _detailsOfWorkDoneController = TextEditingController();

  // Section 6: Client/Customer Remark
  final TextEditingController _clientRemarkController = TextEditingController();

  // Section 7: Service Performance Report & Housekeeping
  String _performanceRating = ''; // 'Satisfactory', 'Unsatisfactory'
  final TextEditingController _supervisorRemarksController = TextEditingController();
  String _housekeepingCompleted = ''; // 'Yes', 'No'

  // Section 8: 4 Digital Signatures in a row
  final TextEditingController _technicianNameController = TextEditingController();
  final TextEditingController _engineerNameController = TextEditingController();
  final TextEditingController _supervisorNameController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();

  Uint8List? _technicianSigBytes;
  Uint8List? _engineerSigBytes;
  Uint8List? _supervisorSigBytes;
  Uint8List? _customerSigBytes;

  @override
  void initState() {
    super.initState();
    
    // Initialize 5 rows x 2 pairs material controllers
    _matControllers1 = List.generate(5, (_) => TextEditingController());
    _qtyControllers1 = List.generate(5, (_) => TextEditingController());
    _matControllers2 = List.generate(5, (_) => TextEditingController());
    _qtyControllers2 = List.generate(5, (_) => TextEditingController());

    if (widget.existingReport != null) {
      _loadExistingReport(widget.existingReport!);
    } else {
      _initRefNumber();
      _loadEmployeeData();
    }

    // Attempt automatic background sync if connected
    SupabaseService().syncPendingServiceReports();
  }

  void _loadExistingReport(ServiceReportData ex) {
    _refNumber = ex.reportRefNumber;
    _reportDate = ex.reportDate;
    _propertyDetailsController.text = ex.propertyDetails;
    _jobNoController.text = ex.jobNo;
    _contactNameController.text = ex.contactName;
    _contactNumberController.text = ex.contactNumber;
    _locationController.text = ex.location;
    _appointmentTimeController.text = ex.appointmentTime;
    _attendedTimeController.text = ex.attendedTime;
    _callBookingTimeController.text = ex.callBookingTime;
    _selectedCallType = ex.callType;
    _selectedServices.addAll(ex.selectedServices);
    _othersServiceController.text = ex.otherServices;
    _selectedPriority = ex.priority;
    _defectsFoundController.text = ex.defectsFound;
    _detailsOfWorkDoneController.text = ex.detailsOfWorkDone;
    _clientRemarkController.text = ex.clientRemark;
    _performanceRating = ex.performanceRating;
    _supervisorRemarksController.text = ex.supervisorRemarks;
    _housekeepingCompleted = ex.housekeepingCompleted;
    _technicianNameController.text = ex.technicianName;
    _engineerNameController.text = ex.engineerName;
    _supervisorNameController.text = ex.supervisorName;
    _customerNameController.text = ex.customerName;
    _technicianSigBytes = ex.technicianSigBytes;
    _engineerSigBytes = ex.engineerSigBytes;
    _supervisorSigBytes = ex.supervisorSigBytes;
    _customerSigBytes = ex.customerSigBytes;

    for (int i = 0; i < 5; i++) {
      if (i < ex.materialsTable.length) {
        _matControllers1[i].text = ex.materialsTable[i].material1;
        _qtyControllers1[i].text = ex.materialsTable[i].qty1;
        _matControllers2[i].text = ex.materialsTable[i].material2;
        _qtyControllers2[i].text = ex.materialsTable[i].qty2;
      }
    }
  }

  bool _hasAnyData(ServiceReportData data) {
    if (data.propertyDetails.isNotEmpty) return true;
    if (data.jobNo.isNotEmpty) return true;
    if (data.contactName.isNotEmpty) return true;
    if (data.contactNumber.isNotEmpty) return true;
    if (data.location.isNotEmpty) return true;
    if (data.appointmentTime.isNotEmpty) return true;
    if (data.attendedTime.isNotEmpty) return true;
    if (data.callBookingTime.isNotEmpty) return true;
    if (data.callType.isNotEmpty) return true;
    if (data.selectedServices.isNotEmpty) return true;
    if (data.otherServices.isNotEmpty) return true;
    if (data.priority.isNotEmpty) return true;
    if (data.defectsFound.isNotEmpty) return true;
    if (data.detailsOfWorkDone.isNotEmpty) return true;
    if (data.clientRemark.isNotEmpty) return true;
    if (data.performanceRating.isNotEmpty) return true;
    if (data.supervisorRemarks.isNotEmpty) return true;
    if (data.housekeepingCompleted.isNotEmpty) return true;
    if (data.materialsTable.any((m) =>
        m.material1.isNotEmpty ||
        m.qty1.isNotEmpty ||
        m.material2.isNotEmpty ||
        m.qty2.isNotEmpty)) return true;
    if (data.technicianSigBytes != null ||
        data.engineerSigBytes != null ||
        data.supervisorSigBytes != null ||
        data.customerSigBytes != null) return true;
    return false;
  }

  void _initRefNumber() {
    setState(() {
      _refNumber = _db.generateNextFullRefNumber();
    });
  }

  Future<void> _triggerManualSync() async {
    final pendingCount = _db.getPendingLocalServiceReports().length;
    if (pendingCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All service reports are synchronized to cloud DB.'),
            backgroundColor: Colors.blueAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final count = await SupabaseService().syncPendingServiceReports();
    if (mounted) {
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synchronized $count offline service report(s) to cloud DB.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect to cloud DB. Reports remain safely saved on your phone.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _loadEmployeeData() {
    final user = _db.currentUser;
    if (user != null) {
      final empName = user.fullName.isNotEmpty ? user.fullName : user.name;
      if (empName.isNotEmpty) {
        setState(() {
          _technicianNameController.text = empName;
        });
      }
    }
  }

  @override
  void dispose() {
    _propertyDetailsController.dispose();
    _jobNoController.dispose();
    _contactNameController.dispose();
    _contactNumberController.dispose();
    _locationController.dispose();
    _appointmentTimeController.dispose();
    _attendedTimeController.dispose();
    _callBookingTimeController.dispose();
    _othersServiceController.dispose();
    _defectsFoundController.dispose();
    _detailsOfWorkDoneController.dispose();
    _clientRemarkController.dispose();
    _supervisorRemarksController.dispose();
    _technicianNameController.dispose();
    _engineerNameController.dispose();
    _supervisorNameController.dispose();
    _customerNameController.dispose();

    for (int i = 0; i < 5; i++) {
      _matControllers1[i].dispose();
      _qtyControllers1[i].dispose();
      _matControllers2[i].dispose();
      _qtyControllers2[i].dispose();
    }
    super.dispose();
  }

  ServiceReportData _buildServiceReportData() {
    final List<MaterialItemRow> materials = [];
    for (int i = 0; i < 5; i++) {
      final m1 = _matControllers1[i].text.trim();
      final q1 = _qtyControllers1[i].text.trim();
      final m2 = _matControllers2[i].text.trim();
      final q2 = _qtyControllers2[i].text.trim();
      if (m1.isNotEmpty || q1.isNotEmpty || m2.isNotEmpty || q2.isNotEmpty) {
        materials.add(MaterialItemRow(
          material1: m1,
          qty1: q1,
          material2: m2,
          qty2: q2,
        ));
      }
    }

    return ServiceReportData(
      reportRefNumber: _refNumber,
      reportDate: _reportDate,
      propertyDetails: _propertyDetailsController.text.trim(),
      jobNo: _jobNoController.text.trim(),
      contactName: _contactNameController.text.trim(),
      contactNumber: _contactNumberController.text.trim(),
      location: _locationController.text.trim(),
      appointmentTime: _appointmentTimeController.text.trim(),
      attendedTime: _attendedTimeController.text.trim(),
      callBookingTime: _callBookingTimeController.text.trim(),
      callType: _selectedCallType,
      selectedServices: _selectedServices.toList(),
      otherServices: _othersServiceController.text.trim(),
      priority: _selectedPriority,
      defectsFound: _defectsFoundController.text.trim(),
      materialsTable: materials,
      detailsOfWorkDone: _detailsOfWorkDoneController.text.trim(),
      clientRemark: _clientRemarkController.text.trim(),
      performanceRating: _performanceRating,
      supervisorRemarks: _supervisorRemarksController.text.trim(),
      housekeepingCompleted: _housekeepingCompleted,
      technicianName: _technicianNameController.text.trim(),
      engineerName: _engineerNameController.text.trim(),
      supervisorName: _supervisorNameController.text.trim(),
      customerName: _customerNameController.text.trim(),
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

  Future<void> _previewPdfReport() async {
    final reportData = _buildServiceReportData();

    // Save locally & attempt background cloud save
    await _db.saveServiceReportLocally(reportData.toJson());
    SupabaseService().syncPendingServiceReports();

    if (!mounted) return;

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
                        'Service Report PDF Preview',
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
                build: (format) => ServiceReportPdfService.buildReportPdfBytes(reportData),
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
    final reportData = _buildServiceReportData();

    if (!_hasAnyData(reportData)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in at least one detail or field before exporting the report.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 1. Save locally to phone offline storage
    await _db.saveServiceReportLocally(reportData.toJson());
    if (widget.existingReport == null) {
      await _db.incrementLocalServiceReportSeq(_db.currentEmployeePrefix);
    }

    // 2. Cloud sync if internet is available
    final synced = await SupabaseService().syncPendingServiceReports();

    if (mounted) {
      if (synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service Report #$_refNumber saved & synced to cloud DB.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service Report #$_refNumber saved locally on phone (Offline mode).'),
            backgroundColor: Colors.blueGrey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // 3. Share/Export PDF
    await ServiceReportPdfService.shareOrDownloadReportPdf(reportData);

    // 4. Clear all form fields & advance sequence for the next report
    _clearAllFields();
  }

  void _clearAllFields() {
    setState(() {
      _propertyDetailsController.clear();
      _jobNoController.clear();
      _contactNameController.clear();
      _contactNumberController.clear();
      _locationController.clear();
      _appointmentTimeController.clear();
      _attendedTimeController.clear();
      _callBookingTimeController.clear();
      _selectedCallType = '';

      _selectedServices.clear();
      _othersServiceController.clear();
      _selectedPriority = '';

      _defectsFoundController.clear();

      for (int i = 0; i < 5; i++) {
        _matControllers1[i].clear();
        _qtyControllers1[i].clear();
        _matControllers2[i].clear();
        _qtyControllers2[i].clear();
      }

      _detailsOfWorkDoneController.clear();
      _clientRemarkController.clear();

      _performanceRating = '';
      _supervisorRemarksController.clear();
      _housekeepingCompleted = '';

      _engineerNameController.clear();
      _supervisorNameController.clear();
      _customerNameController.clear();

      _technicianSigBytes = null;
      _engineerSigBytes = null;
      _supervisorSigBytes = null;
      _customerSigBytes = null;
    });

    _loadEmployeeData();
    _initRefNumber();
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.currentColors.primaryFor(Theme.of(context).brightness);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FUSION',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                Text(
                  'Official Field Service Report',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Saved Reports History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EmployeeReportsListScreen(),
                ),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
          ),
          IconButton(
            tooltip: 'Sync Offline Reports',
            icon: const Icon(Icons.cloud_upload_rounded),
            onPressed: _triggerManualSync,
          ),
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
              // ================= 1st Section: Property & Call Details =================
              _buildSectionCard(
                isDark: isDark,
                title: '1. Property Details & Call Booking Info',
                icon: Icons.home_work_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _propertyDetailsController,
                            decoration: _inputDecoration('Property Details', isDark),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _jobNoController,
                            decoration: _inputDecoration('Job No', isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _contactNameController,
                            decoration: _inputDecoration('Contact Name', isDark),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _contactNumberController,
                            decoration: _inputDecoration('Contact Number', isDark),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationController,
                      decoration: _inputDecoration('Location', isDark),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _appointmentTimeController,
                            readOnly: true,
                            onTap: () => _selectTime(_appointmentTimeController),
                            decoration: _inputDecoration('Appointment Time', isDark).copyWith(
                              suffixIcon: const Icon(Icons.access_time_rounded, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _attendedTimeController,
                            readOnly: true,
                            onTap: () => _selectTime(_attendedTimeController),
                            decoration: _inputDecoration('Attended Time', isDark).copyWith(
                              suffixIcon: const Icon(Icons.access_time_filled_rounded, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _callBookingTimeController,
                            readOnly: true,
                            onTap: () => _selectTime(_callBookingTimeController),
                            decoration: _inputDecoration('Call Booking Time', isDark).copyWith(
                              suffixIcon: const Icon(Icons.more_time_rounded, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Call Type: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Wrap(
                          spacing: 16,
                          children: ['Complaint', 'Breakdown', 'Preventive'].map((type) {
                            final isSelected = _selectedCallType == type;
                            return ChoiceChip(
                              label: Text(type),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                setState(() => _selectedCallType = val ? type : '');
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ================= 2nd Section: Service Required & Priority =================
              _buildSectionCard(
                isDark: isDark,
                title: '2. Service Required & Priority',
                icon: Icons.build_circle_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Required Services:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allServices.map((service) {
                        final isSelected = _selectedServices.contains(service);
                        return FilterChip(
                          label: Text(service, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedServices.add(service);
                              } else {
                                _selectedServices.remove(service);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _othersServiceController,
                      decoration: _inputDecoration('Others (Please Specify)', isDark),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Priority: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Wrap(
                          spacing: 16,
                          children: ['Urgent', 'Normal'].map((prio) {
                            final isSelected = _selectedPriority == prio;
                            return ChoiceChip(
                              label: Text(prio),
                              selected: isSelected,
                              selectedColor: prio == 'Urgent' ? Colors.redAccent : AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                setState(() => _selectedPriority = val ? prio : '');
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ================= 3rd Section: Defects Found on Inspection =================
              _buildSectionCard(
                isDark: isDark,
                title: '3. Defects Found on Inspection',
                icon: Icons.search_off_rounded,
                child: TextFormField(
                  controller: _defectsFoundController,
                  maxLines: 3,
                  decoration: _inputDecoration('Enter defects found during inspection...', isDark),
                ),
              ),
              const SizedBox(height: 16),

              // ================= 4th Section: Material Used Table (4 Cols, 5 Rows) =================
              _buildSectionCard(
                isDark: isDark,
                title: '4. Material Used (Table)',
                icon: Icons.inventory_2_rounded,
                child: Column(
                  children: [
                    // Header Row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Material Used', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 6),
                          Expanded(flex: 1, child: Text('Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 12),
                          Expanded(flex: 3, child: Text('Material Used', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 6),
                          Expanded(flex: 1, child: Text('Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 5 Rows
                    for (int i = 0; i < 5; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _matControllers1[i],
                              decoration: _inputDecoration('Material ${i + 1}A', isDark),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _qtyControllers1[i],
                              decoration: _inputDecoration('Qty', isDark),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _matControllers2[i],
                              decoration: _inputDecoration('Material ${i + 1}B', isDark),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _qtyControllers2[i],
                              decoration: _inputDecoration('Qty', isDark),
                            ),
                          ),
                        ],
                      ),
                      if (i < 4) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ================= 5th Section: Details of work done =================
              _buildSectionCard(
                isDark: isDark,
                title: '5. Details of Work Done',
                icon: Icons.handyman_rounded,
                child: TextFormField(
                  controller: _detailsOfWorkDoneController,
                  maxLines: 3,
                  decoration: _inputDecoration('Enter full details of work executed...', isDark),
                ),
              ),
              const SizedBox(height: 16),

              // ================= 6th Section: Client/Customer Remark =================
              _buildSectionCard(
                isDark: isDark,
                title: '6. Client / Customer Remark',
                icon: Icons.rate_review_rounded,
                child: TextFormField(
                  controller: _clientRemarkController,
                  maxLines: 3,
                  decoration: _inputDecoration('Enter client feedback / remarks...', isDark),
                ),
              ),
              const SizedBox(height: 16),

              // ================= 7th Section: Service Performance Report =================
              _buildSectionCard(
                isDark: isDark,
                title: '7. Service Performance Report',
                icon: Icons.verified_user_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Service Performance: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Wrap(
                          spacing: 12,
                          children: ['Satisfactory', 'Unsatisfactory'].map((rating) {
                            final isSelected = _performanceRating == rating;
                            return ChoiceChip(
                              label: Text(rating),
                              selected: isSelected,
                              selectedColor: rating == 'Satisfactory' ? Colors.green : Colors.deepOrange,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                setState(() => _performanceRating = val ? rating : '');
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _supervisorRemarksController,
                      maxLines: 2,
                      decoration: _inputDecoration("Supervisor's Remarks", isDark),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Housekeeping Completed: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Wrap(
                          spacing: 16,
                          children: ['Yes', 'No'].map((opt) {
                            final isSelected = _housekeepingCompleted == opt;
                            return ChoiceChip(
                              label: Text(opt),
                              selected: isSelected,
                              selectedColor: opt == 'Yes' ? Colors.green : Colors.red,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                setState(() => _housekeepingCompleted = val ? opt : '');
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ================= 8th Section: Four Signatures in a Row =================
              _buildSectionCard(
                isDark: isDark,
                title: '8. Authorizations & 4 Signatures (In Row)',
                icon: Icons.draw_rounded,
                child: Row(
                  children: [
                        Expanded(
                          child: ESignaturePreviewBox(
                            label: 'Technician',
                            signatureBytes: _technicianSigBytes,
                            onTapSign: () => _openSignatureModalForRole('technician'),
                            onClear: () => setState(() => _technicianSigBytes = null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ESignaturePreviewBox(
                            label: 'Engineer',
                            signatureBytes: _engineerSigBytes,
                            onTapSign: () => _openSignatureModalForRole('engineer'),
                            onClear: () => setState(() => _engineerSigBytes = null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ESignaturePreviewBox(
                            label: 'Supervisor',
                            signatureBytes: _supervisorSigBytes,
                            onTapSign: () => _openSignatureModalForRole('supervisor'),
                            onClear: () => setState(() => _supervisorSigBytes = null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ESignaturePreviewBox(
                            label: 'Customer',
                            signatureBytes: _customerSigBytes,
                            onTapSign: () => _openSignatureModalForRole('customer'),
                            onClear: () => setState(() => _customerSigBytes = null),
                          ),
                        ),
                      ],
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

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
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
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
