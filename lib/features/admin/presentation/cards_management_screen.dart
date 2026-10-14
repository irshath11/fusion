import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/employee_card.dart';
import '../domain/employee_entity.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/card_ocr_service.dart';
import '../../attendance/presentation/camera_capture_modal.dart';
import '../../../core/widgets/app_bounceable.dart';
import '../../../core/widgets/app_glass_card.dart';
import '../../../core/widgets/employee_avatar.dart';

class CardsManagementScreen extends StatefulWidget {
  const CardsManagementScreen({super.key});

  @override
  State<CardsManagementScreen> createState() => _CardsManagementScreenState();
}

class _CardsManagementScreenState extends State<CardsManagementScreen>
    with SingleTickerProviderStateMixin {
  final LocalDatabaseService _db = LocalDatabaseService();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  late TabController _tabController;
  List<EmployeeCard> _cards = [];
  List<EmployeeEntity> _employees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL';

  // Dedicated tabs for: Emirates ID, Visa, Passport, Insurance, MOPA pass, CISPA pass + All
  final List<Map<String, dynamic>> _tabsConfig = const [
    {
      'id': 'EMIRATES_ID',
      'label': 'Emirates ID',
      'icon': Icons.badge_rounded,
      'color': Colors.cyan,
      'fullName': 'Emirates ID (EID)',
      'placeholder': '784-1990-1234567-1',
    },
    {
      'id': 'VISA',
      'label': 'Visa',
      'icon': Icons.airplane_ticket_rounded,
      'color': Colors.purpleAccent,
      'fullName': 'UAE Residence / Work Visa',
      'placeholder': '201/2024/1234567',
    },
    {
      'id': 'PASSPORT',
      'label': 'Passport',
      'icon': Icons.menu_book_rounded,
      'color': Colors.blueAccent,
      'fullName': 'International Passport',
      'placeholder': 'A12345678',
    },
    {
      'id': 'INSURANCE',
      'label': 'Insurance',
      'icon': Icons.health_and_safety_rounded,
      'color': Colors.teal,
      'fullName': 'Health & Medical Insurance',
      'placeholder': 'DAMAN-GLD-998877',
    },
    {
      'id': 'MOPA_PASS',
      'label': 'MOPA Pass',
      'icon': Icons.security_rounded,
      'color': Colors.amber,
      'fullName': 'MOPA Pass (Private Clearance)',
      'placeholder': 'MOPA-SEC-2024-01',
    },
    {
      'id': 'CISPA_PASS',
      'label': 'CISPA Pass',
      'icon': Icons.anchor_rounded,
      'color': Color(0xFFF43F5E),
      'fullName': 'CISPA Pass (Critical Infrastructure)',
      'placeholder': 'CISPA-PORT-8899',
    },
    {
      'id': 'ALL',
      'label': 'All Cards',
      'icon': Icons.folder_shared_rounded,
      'color': Colors.indigoAccent,
      'fullName': 'All Cards & Passes',
      'placeholder': 'Card Number',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabsConfig.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Fetch Employees
    _employees = _db.getEmployees();

    // 2. Fetch Cards from Supabase (or load local saved cards)
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('employee_cards')
          .select()
          .eq('is_deleted', false)
          .order('expiry_date', ascending: true);

      if ((response as List).isNotEmpty) {
        _cards = (response as List)
            .map((item) => EmployeeCard.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _persistCardsLocally();
      } else {
        _loadLocalSavedCards();
      }
    } catch (e) {
      _loadLocalSavedCards();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _loadLocalSavedCards() {
    final saved = _db.getSavedEmployeeCards();
    if (saved.isNotEmpty) {
      _cards = saved.map((json) => EmployeeCard.fromJson(json)).toList();
    } else {
      // Clean start: No sample/demo cards as requested by the user
      _cards = [];
    }
  }

  void _persistCardsLocally() {
    final jsonList = _cards.map((c) => c.toJson()).toList();
    _db.persistEmployeeCards(jsonList);
  }

  EmployeeEntity? _getEmployee(String empId) {
    try {
      return _employees.firstWhere((e) => e.id == empId);
    } catch (_) {
      return null;
    }
  }

  String get _currentTabId => _tabsConfig[_tabController.index]['id'] as String;

  List<EmployeeCard> _getCardsForTab(String tabId) {
    if (tabId == 'ALL') {
      return _cards;
    }
    return _cards.where((c) => c.cardType == tabId).toList();
  }

  int _countForTab(String tabId) {
    return _getCardsForTab(tabId).length;
  }

  int _criticalCountForTab(String tabId) {
    return _getCardsForTab(tabId).where((c) => c.isCritical || c.isExpired).length;
  }

  // 1-Click WhatsApp Compliance Trigger
  Future<void> _notifyWhatsApp(EmployeeCard card) async {
    final emp = _getEmployee(card.employeeId);
    final empName = emp?.name ?? 'Employee';
    final empCode = emp?.employeeCode ?? 'N/A';
    final dept = emp?.department ?? 'Operations';
    final phone = (emp?.mobileNumber ?? '').replaceAll(RegExp(r'[^0-9]'), '');

    final message = '''
🚨 *URGENT COMPLIANCE NOTICE: CARD EXPIRATION*
----------------------------------------
👤 *Employee:* $empName ($empCode)
🏢 *Department:* $dept
🪪 *Document Type:* ${card.cardName}
🔢 *Card/Doc Number:* ${card.cardNumber}
📅 *Expiry Date:* ${_dateFormat.format(card.expiryDate)}
⏳ *Status:* ${card.statusLabel}

⚠️ *Action Required:* This document is expiring within the critical 3-day window (or has expired). Please submit the renewed document or in-process renewal receipt immediately.
----------------------------------------
_Fusion 360 Workforce Document Control_''';

    final encodedMsg = Uri.encodeComponent(message);
    final urlStr = phone.isNotEmpty
        ? 'https://wa.me/$phone?text=$encodedMsg'
        : 'https://wa.me/?text=$encodedMsg';

    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() {
        final idx = _cards.indexWhere((c) => c.id == card.id);
        if (idx != -1) {
          _cards[idx] = _cards[idx].copyWith(lastNotifiedAt: DateTime.now());
          _persistCardsLocally();
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  // 1-Click Email Compliance Trigger
  Future<void> _notifyEmail(EmployeeCard card) async {
    final emp = _getEmployee(card.employeeId);
    final empName = emp?.name ?? 'Employee';
    final empCode = emp?.employeeCode ?? 'N/A';
    final email = emp?.email ?? '';

    final subject = '[URGENT] Expiry Notice: ${card.cardName} for $empName (${card.statusLabel})';
    final body = '''
Dear $empName & Administration,

This is an automated compliance notification from Fusion 360 Operations Control.

The following employee document is expiring within the critical 3-day notification threshold or has already expired:

• Employee Name: $empName
• Employee Code: $empCode
• Department: ${emp?.department ?? 'Operations'}
• Document / Pass: ${card.cardName}
• Card / Document Number: ${card.cardNumber}
• Expiry Date: ${_dateFormat.format(card.expiryDate)}
• Status: ${card.statusLabel}

ACTION REQUIRED:
Please arrange for the submission of the renewed document or in-process renewal receipt immediately to prevent gate/site access deactivation and regulatory compliance penalties.

Best regards,
Fusion 360 Compliance & Operations Desk''';

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      setState(() {
        final idx = _cards.indexWhere((c) => c.id == card.id);
        if (idx != -1) {
          _cards[idx] = _cards[idx].copyWith(lastNotifiedAt: DateTime.now());
          _persistCardsLocally();
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client.')),
        );
      }
    }
  }

  // Consolidated Broadcast Digest via WhatsApp
  Future<void> _notifyBroadcastDigest() async {
    final critical = _cards.where((c) => c.isCritical || c.isExpired).toList();
    if (critical.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All documents are valid. No critical expirations.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('🚨 *FUSION 360: CRITICAL CARD EXPIRATION COMPLIANCE DIGEST*');
    buffer.writeln('Date: ${_dateFormat.format(DateTime.now())}');
    buffer.writeln('Total Urgent Items: ${critical.length}');
    buffer.writeln('----------------------------------------');

    for (int i = 0; i < critical.length; i++) {
      final c = critical[i];
      final emp = _getEmployee(c.employeeId);
      buffer.writeln('${i + 1}. *${emp?.name ?? 'Staff'}* - ${c.cardName}');
      buffer.writeln('   Card #: ${c.cardNumber}');
      buffer.writeln('   Expiry: ${_dateFormat.format(c.expiryDate)} (${c.statusLabel})');
      buffer.writeln('');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('⚠️ Immediate renewal required.');

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Upload or Edit Card Dialog with active tab pre-selection
  void _showAddEditCardDialog({EmployeeCard? cardToEdit, String? defaultType}) {
    final isEditing = cardToEdit != null;

    String initialType = cardToEdit?.cardType ?? defaultType ?? _currentTabId;
    if (initialType == 'ALL') {
      initialType = 'EMIRATES_ID';
    }

    String selectedEmpId = isEditing
        ? cardToEdit.employeeId
        : (_employees.isNotEmpty ? _employees.first.id : '');
    String selectedType = initialType;

    final cardConfig = _tabsConfig.firstWhere(
      (t) => t['id'] == selectedType,
      orElse: () => _tabsConfig.first,
    );

    final cardNameController = TextEditingController(
      text: isEditing ? cardToEdit.cardName : (cardConfig['fullName'] as String),
    );
    final cardNumController = TextEditingController(
      text: isEditing ? cardToEdit.cardNumber : '',
    );
    final notesController = TextEditingController(
      text: isEditing ? (cardToEdit.notes ?? '') : '',
    );

    DateTime? selectedIssue = isEditing ? cardToEdit.issueDate : null;
    DateTime selectedExpiry = isEditing
        ? cardToEdit.expiryDate
        : DateTime.now().add(const Duration(days: 365));

    bool isScanning = false;
    OcrCardResult? scanResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedEmp = _employees.firstWhere(
            (e) => e.id == selectedEmpId,
            orElse: () => _employees.isNotEmpty
                ? _employees.first
                : EmployeeEntity(id: '', name: 'Staff', employeeCode: 'EMP', department: '', designation: '', mobileNumber: '', email: ''),
          );

          Future<void> runOcrScan({String? rawText, String? rawOcrText}) async {
            setDialogState(() {
              isScanning = true;
            });

            try {
              final result = await CardOcrService.extractCardData(
                cardType: selectedType,
                employee: selectedEmp,
                rawOcrText: rawOcrText ?? rawText,
              );

              setDialogState(() {
                isScanning = false;
                scanResult = result;
                cardNumController.text = result.cardNumber;
                cardNameController.text = result.cardName;
                if (result.issueDate != null) selectedIssue = result.issueDate;
                selectedExpiry = result.expiryDate;
              });
            } catch (_) {
              setDialogState(() => isScanning = false);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.document_scanner_rounded,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Document' : 'Smart Card & Pass Upload',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(
                        'Select employee and auto-extract card details & expiry',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Selector
                    const Text('Select Employee *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('emp_${selectedEmpId}'),
                      initialValue: selectedEmpId.isNotEmpty ? selectedEmpId : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        hintText: 'Choose employee',
                      ),
                      items: _employees.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.id,
                          child: Text('${e.name} (${e.employeeCode}) - ${e.department}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedEmpId = val;
                            scanResult = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Card Type Selector
                    const Text('Document / Pass Type *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('card_${selectedType}'),
                      initialValue: selectedType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _tabsConfig
                          .where((t) => t['id'] != 'ALL')
                          .map((t) {
                        return DropdownMenuItem<String>(
                          value: t['id'] as String,
                          child: Row(
                            children: [
                              Icon(t['icon'] as IconData, size: 18, color: t['color'] as Color),
                              const SizedBox(width: 10),
                              Text(t['fullName'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedType = val;
                            scanResult = null;
                            final conf = _tabsConfig.firstWhere((t) => t['id'] == val);
                            cardNameController.text = conf['fullName'] as String;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // AUTOMATED SCAN & OCR EXTRACTION SECTION (NO MANUAL ENTRY)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryLight.withValues(alpha: 0.08),
                            AppColors.primaryLight.withValues(alpha: 0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.document_scanner_rounded, size: 16, color: AppColors.primaryLight),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Automated Document Scanning (OCR)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'NO TYPING REQUIRED',
                                  style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Scan with live camera or auto-extract card values & expiry date instantly:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),

                          if (isScanning)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Analyzing document & extracting expiry dates via OCR...',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryLight,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                                    label: const Text('Auto-Extract Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () => runOcrScan(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                    label: const Text('Live Camera Scan', style: TextStyle(fontSize: 12)),
                                    onPressed: () async {
                                      await showDialog(
                                        context: context,
                                        builder: (c) => CameraCaptureModal(
                                          stepName: 'Card Document Capture',
                                          onPhotoCaptured: (camRes) {
                                            runOcrScan(rawOcrText: camRes.base64Image);
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),

                          if (scanResult != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (scanResult!.isUrgentAlert ? Colors.red : Colors.green).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (scanResult!.isUrgentAlert ? Colors.red : Colors.green).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    scanResult!.isUrgentAlert ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                                    size: 20,
                                    color: scanResult!.isUrgentAlert ? Colors.red : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Data Successfully Extracted!',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: scanResult!.isUrgentAlert ? Colors.red : Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          scanResult!.extractionSummary,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card Name
                    const Text('Document Title',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: cardNameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card / Document Number
                    const Text('Card / Document Number (Auto-Extracted)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: cardNumController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        hintText: 'Auto-filled via OCR or enter card number',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Issue Date & Expiry Date row
                    Row(
                      children: [
                        // Issue Date (Optional)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Issue Date',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedIssue ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => selectedIssue = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        selectedIssue != null
                                            ? _dateFormat.format(selectedIssue!)
                                            : 'Not set',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: selectedIssue != null ? null : Colors.grey,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_month_rounded, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Expiry Date (Required)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Expiry Date *',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedExpiry,
                                    firstDate: DateTime(2015),
                                    lastDate: DateTime(2040),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => selectedExpiry = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _dateFormat.format(selectedExpiry),
                                        style: const TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const Icon(Icons.event_busy_rounded,
                                          size: 16, color: Colors.redAccent),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Remarks / Notes
                    const Text('Notes / Renewal Status',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        hintText: 'e.g. Renewal submitted to authority, receipt pending',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                onPressed: () async {
                  if (selectedEmpId.isEmpty || cardNumController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select an employee and enter card number.')),
                    );
                    return;
                  }

                  final newCard = EmployeeCard(
                    id: isEditing ? cardToEdit.id : 'card_${DateTime.now().millisecondsSinceEpoch}',
                    organizationId: _db.currentUser?.organizationId ?? '00000000-0000-0000-0000-000000000001',
                    employeeId: selectedEmpId,
                    cardType: selectedType,
                    cardName: cardNameController.text.trim(),
                    cardNumber: cardNumController.text.trim(),
                    issueDate: selectedIssue,
                    expiryDate: selectedExpiry,
                    notes: notesController.text.trim(),
                  );

                  // 1. Save to Supabase (if online)
                  try {
                    final supabase = Supabase.instance.client;
                    await supabase.from('employee_cards').upsert(newCard.toJson());
                  } catch (_) {}

                  // 2. Update local state & Hive
                  setState(() {
                    if (isEditing) {
                      final idx = _cards.indexWhere((c) => c.id == cardToEdit.id);
                      if (idx != -1) _cards[idx] = newCard;
                    } else {
                      _cards.insert(0, newCard);
                    }
                    _persistCardsLocally();
                  });

                  // Switch tab to the uploaded card's category if needed
                  final targetTabIndex = _tabsConfig.indexWhere((t) => t['id'] == selectedType);
                  if (targetTabIndex != -1 && _tabController.index != targetTabIndex && _tabController.index != _tabsConfig.length - 1) {
                    _tabController.animateTo(targetTabIndex);
                  }

                  Navigator.pop(ctx);

                  // Critical 3-day notice feedback
                  if (newCard.isCritical || newCard.isExpired) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.amber.shade900,
                        content: Text(
                          '⚠️ Document Notice: ${newCard.cardName} (${newCard.statusLabel})! Send WhatsApp reminder?',
                        ),
                        action: SnackBarAction(
                          label: 'WhatsApp',
                          textColor: Colors.white,
                          onPressed: () => _notifyWhatsApp(newCard),
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.teal.shade800,
                        content: Text('✓ ${newCard.cardName} uploaded successfully!'),
                      ),
                    );
                  }
                },
                child: Text(
                  isEditing ? 'Save Changes' : 'Upload Document',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteCard(EmployeeCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete ${card.cardName} (${card.cardNumber})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('employee_cards')
            .update({'is_deleted': true}).eq('id', card.id);
      } catch (_) {}

      setState(() {
        _cards.removeWhere((c) => c.id == card.id);
        _persistCardsLocally();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Overall critical count
    final totalCriticalCount = _cards.where((c) => c.isCritical).length;
    final totalExpiredCount = _cards.where((c) => c.isExpired).length;
    final totalUrgentCount = totalCriticalCount + totalExpiredCount;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryLight,
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(
          _currentTabId == 'ALL'
              ? 'Upload Card'
              : 'Upload ${_tabsConfig[_tabController.index]['label']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showAddEditCardDialog(
          defaultType: _currentTabId == 'ALL' ? 'EMIRATES_ID' : _currentTabId,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Header with TabBar
                Container(
                  color: Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      // Alert Banner for Expirations ≤ 3 Days
                      if (totalUrgentCount > 0)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Compliance Alert: $totalCriticalCount expiring ≤ 3 days, $totalExpiredCount expired documents.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                              AppBounceable(
                                onTap: _notifyBroadcastDigest,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat_rounded, color: Colors.white, size: 13),
                                      SizedBox(width: 5),
                                      Text(
                                        'WhatsApp Digest',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Dedicated Scrollable TabBar
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: AppColors.primaryLight,
                        labelColor: isDark ? Colors.white : Colors.black87,
                        unselectedLabelColor: Colors.grey,
                        indicatorWeight: 3,
                        tabs: _tabsConfig.map((t) {
                          final count = _countForTab(t['id'] as String);
                          final urgentCount = _criticalCountForTab(t['id'] as String);

                          return Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(t['icon'] as IconData, size: 17, color: t['color'] as Color),
                                const SizedBox(width: 8),
                                Text(
                                  t['label'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: urgentCount > 0
                                        ? Colors.redAccent
                                        : (count > 0
                                            ? (t['color'] as Color).withValues(alpha: 0.2)
                                            : Colors.grey.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: urgentCount > 0 ? Colors.white : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Tab Content View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabsConfig.map((t) {
                      return _buildTabView(
                        tabId: t['id'] as String,
                        tabName: t['label'] as String,
                        tabFullName: t['fullName'] as String,
                        tabIcon: t['icon'] as IconData,
                        tabColor: t['color'] as Color,
                        isDark: isDark,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabView({
    required String tabId,
    required String tabName,
    required String tabFullName,
    required IconData tabIcon,
    required Color tabColor,
    required bool isDark,
  }) {
    final tabCards = _getCardsForTab(tabId);

    // Apply search and status filter
    final filtered = tabCards.where((card) {
      final emp = _getEmployee(card.employeeId);
      final query = _searchQuery.toLowerCase();
      final matchQuery = (emp?.name.toLowerCase().contains(query) ?? false) ||
          (emp?.employeeCode.toLowerCase().contains(query) ?? false) ||
          card.cardName.toLowerCase().contains(query) ||
          card.cardNumber.toLowerCase().contains(query);

      if (!matchQuery) return false;

      if (_selectedStatusFilter == 'CRITICAL' && !card.isCritical) return false;
      if (_selectedStatusFilter == 'EXPIRED' && !card.isExpired) return false;
      if (_selectedStatusFilter == 'SOON' && !card.isExpiringSoon) return false;
      if (_selectedStatusFilter == 'VALID' && !card.isValid) return false;

      return true;
    }).toList();

    final totalCount = tabCards.length;
    final criticalCount = tabCards.where((c) => c.isCritical).length;
    final expiredCount = tabCards.where((c) => c.isExpired).length;
    final validCount = tabCards.where((c) => c.isValid).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Tab Metric Summary Tiles (if cards exist)
          if (totalCount > 0) ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _buildMetricCard(
                  title: 'Total $tabName',
                  value: '$totalCount',
                  icon: tabIcon,
                  color: tabColor,
                ),
                _buildMetricCard(
                  title: 'Expiring ≤ 3 Days',
                  value: '$criticalCount',
                  icon: Icons.hourglass_bottom_rounded,
                  color: Colors.amber.shade800,
                  isAlert: criticalCount > 0,
                ),
                _buildMetricCard(
                  title: 'Expired Documents',
                  value: '$expiredCount',
                  icon: Icons.cancel_outlined,
                  color: Colors.redAccent,
                  isAlert: expiredCount > 0,
                ),
                _buildMetricCard(
                  title: 'Active & Valid',
                  value: '$validCount',
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.teal.shade700,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search and Status Filter Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search $tabName by employee name, code, or number...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedStatusFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'CRITICAL', child: Text('🚨 ≤ 3 Days')),
                    DropdownMenuItem(value: 'EXPIRED', child: Text('❌ Expired')),
                    DropdownMenuItem(value: 'SOON', child: Text('⚠️ ≤ 30 Days')),
                    DropdownMenuItem(value: 'VALID', child: Text('✅ Valid')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatusFilter = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // 2. Cards List or Dedicated Empty State
          if (filtered.isEmpty)
            _buildEmptyState(
              tabId: tabId,
              tabName: tabName,
              tabFullName: tabFullName,
              tabIcon: tabIcon,
              tabColor: tabColor,
              isDark: isDark,
              isSearchFiltered: totalCount > 0,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final card = filtered[index];
                final emp = _getEmployee(card.employeeId);
                final cardColor = _getCardTypeColor(card.cardType);

                Color statusBg = Colors.teal.withValues(alpha: 0.15);
                Color statusFg = Colors.teal;
                if (card.isExpired) {
                  statusBg = Colors.red.withValues(alpha: 0.18);
                  statusFg = Colors.redAccent;
                } else if (card.isCritical) {
                  statusBg = Colors.orange.withValues(alpha: 0.2);
                  statusFg = Colors.deepOrange;
                } else if (card.isExpiringSoon) {
                  statusBg = Colors.amber.withValues(alpha: 0.15);
                  statusFg = Colors.amber.shade800;
                }

                return AppGlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Employee Avatar
                          EmployeeAvatar(
                            photoUrl: emp?.photoUrl,
                            fullName: emp?.name ?? 'Staff',
                            radius: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emp?.name ?? 'Staff Member',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '${emp?.employeeCode ?? 'EMP'} • ${emp?.department ?? 'Operations'}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusFg.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              card.statusLabel,
                              style: TextStyle(
                                color: statusFg,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18),

                      // Document Info Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cardColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cardColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(tabIcon, size: 12, color: cardColor),
                                const SizedBox(width: 5),
                                Text(
                                  card.cardName,
                                  style: TextStyle(
                                    color: cardColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '# ${card.cardNumber}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            'Expiry: ${_dateFormat.format(card.expiryDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey[300] : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),

                      if (card.notes != null && card.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Note: ${card.notes}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Actions: WhatsApp, Email, Edit, Delete
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // 1-Click WhatsApp Notification Trigger
                          AppBounceable(
                            onTap: () => _notifyWhatsApp(card),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_rounded, color: Colors.white, size: 13),
                                  SizedBox(width: 5),
                                  Text(
                                    'WhatsApp',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 1-Click Email Notification Trigger
                          AppBounceable(
                            onTap: () => _notifyEmail(card),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.email_rounded, color: Colors.white, size: 13),
                                  SizedBox(width: 5),
                                  Text(
                                    'Email',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Edit Button
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            tooltip: 'Edit Document',
                            onPressed: () => _showAddEditCardDialog(cardToEdit: card),
                          ),

                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            tooltip: 'Delete Document',
                            onPressed: () => _deleteCard(card),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String tabId,
    required String tabName,
    required String tabFullName,
    required IconData tabIcon,
    required Color tabColor,
    required bool isDark,
    required bool isSearchFiltered,
  }) {
    if (isSearchFiltered) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No $tabName documents match your search criteria.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tabColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tabColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(tabIcon, size: 48, color: tabColor),
          ),
          const SizedBox(height: 16),
          Text(
            'No $tabFullName Uploaded Yet',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Upload employee $tabName cards to track expiration dates and trigger automatic WhatsApp/Email compliance notices 3 days before expiry.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: tabColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'Upload First $tabName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => _showAddEditCardDialog(
              defaultType: tabId == 'ALL' ? 'EMIRATES_ID' : tabId,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCardTypeColor(String cardType) {
    final conf = _tabsConfig.firstWhere(
      (t) => t['id'] == cardType,
      orElse: () => _tabsConfig.last,
    );
    return conf['color'] as Color;
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? color.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.2),
          width: isAlert ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
