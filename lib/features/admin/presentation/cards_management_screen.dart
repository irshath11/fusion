import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import '../domain/employee_card.dart';
import '../domain/employee_entity.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/card_ocr_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../attendance/presentation/camera_capture_modal.dart';
import '../../../core/widgets/app_bounceable.dart';
import '../../../core/widgets/app_glass_card.dart';
import '../../../core/widgets/employee_avatar.dart';
import '../../../core/services/card_expiry_notification_service.dart';
import '../../../core/utils/employee_directory_helper.dart';
import '../../auth/domain/user_entity.dart';

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
  final Map<String, String> _empIdCrossReference = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL';
  bool _isGridView = true;

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
      'id': 'EXPIRING_SOON',
      'label': 'Expiring Soon',
      'icon': Icons.hourglass_top_rounded,
      'color': Color(0xFFF59E0B),
      'fullName': 'Documents Expiring Soon (< 30 Days)',
      'placeholder': 'Card Number',
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

    // 1. Fetch Local Employees & seed master enterprise directory
    final localEmps = _db.getEmployees();
    final Map<String, EmployeeEntity> empMap = {};

    // 1a. Master Directory Seed (guarantees offline & immediate availability of all official staff)
    for (final official in EmployeeDirectoryHelper.masterDirectory) {
      final seed = EmployeeEntity(
        id: official.employeeId,
        employeeCode: official.employeeId,
        name: official.fullName,
        mobileNumber: '',
        photoUrl: official.photoAsset,
        email: official.email,
        designation: official.designation,
        department: official.department,
      );
      empMap[official.employeeId.toUpperCase()] = seed;
      empMap[official.fullName.toLowerCase()] = seed;
      if (official.email.isNotEmpty) empMap[official.email.toLowerCase()] = seed;
    }

    // 1b. Merge local DB employees
    for (final e in localEmps) {
      empMap[e.id] = e;
      if (e.employeeCode.isNotEmpty) {
        empMap[e.employeeCode.toUpperCase()] = e;
      }
      if (e.email.isNotEmpty) {
        empMap[e.email.toLowerCase()] = e;
      }
      if (e.name.isNotEmpty) {
        empMap[e.name.toLowerCase()] = e;
      }
    }

    _employees = empMap.values.toSet().toList();

    // 2. Load Local Saved Cards First (ensures offline and restart persistence)
    final savedCardsJson = await _db.loadSavedEmployeeCardsAsync();
    if (savedCardsJson.isNotEmpty) {
      _cards = savedCardsJson.map((json) => EmployeeCard.fromJson(json)).toList();
    }

    // 3. Fetch Cards & Employees from Supabase
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('employee_cards')
          .select()
          .eq('is_deleted', false)
          .order('expiry_date', ascending: true);

      if (response.isNotEmpty) {
        final cloudCards = response
            .map((item) => EmployeeCard.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        // Merge keeping both local and cloud records (never wipe local cards)
        final Map<String, EmployeeCard> mergedMap = {};
        for (final c in _cards) {
          mergedMap[c.id] = c;
        }
        for (final c in cloudCards) {
          if (mergedMap.containsKey(c.id)) {
            final local = mergedMap[c.id]!;
            final hasLocalDoc = local.documentUrl != null && local.documentUrl!.isNotEmpty;
            final hasCloudDoc = c.documentUrl != null && c.documentUrl!.isNotEmpty;
            mergedMap[c.id] = (!hasCloudDoc && hasLocalDoc)
                ? c.copyWith(documentUrl: local.documentUrl, fileName: local.fileName)
                : c;
          } else {
            mergedMap[c.id] = c;
          }
        }
        _cards = mergedMap.values.toList();
        _cards.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
        await _persistCardsLocally();
      }

      // Authoritative cloud employee synchronization
      try {
        final orgId = _db.currentUser?.organizationId;
        final cloudEmployees = await SupabaseService().fetchEmployeesFromSupabase(orgId);
        final cloudUsers = (orgId != null && orgId.isNotEmpty)
            ? await SupabaseService().fetchOrganizationUsers(orgId)
            : <UserEntity>[];

        for (final ce in cloudEmployees) {
          empMap[ce.id] = ce;
          if (ce.employeeCode.isNotEmpty) empMap[ce.employeeCode.toUpperCase()] = ce;
          if (ce.name.isNotEmpty) empMap[ce.name.toLowerCase()] = ce;
        }
        for (final u in cloudUsers) {
          final code = (u.employeeCode != null && u.employeeCode!.isNotEmpty) ? u.employeeCode! : '';
          final official = EmployeeDirectoryHelper.resolveOfficialRecord(
            code: code,
            name: u.fullName,
            email: u.email,
            id: u.id,
          );
          final fullName = official?.fullName ?? (u.fullName.isNotEmpty && u.fullName != 'Staff' && u.fullName != 'Staff Member' ? u.fullName : (official?.fullName ?? u.fullName));
          final photo = EmployeeDirectoryHelper.resolvePhoto(
            customPhotoUrl: null,
            employeeCode: code.isNotEmpty ? code : official?.employeeId,
            fullName: fullName,
            email: u.email,
            id: u.id,
          ) ?? official?.photoAsset;

          final entity = EmployeeEntity(
            id: u.id,
            employeeCode: code.isNotEmpty ? code : (official?.employeeId ?? 'EMP-${u.id.length >= 4 ? u.id.substring(0, 4).toUpperCase() : u.id}'),
            name: fullName.isNotEmpty ? fullName : 'Staff Member',
            mobileNumber: u.phoneNumber ?? '',
            email: u.email,
            photoUrl: photo,
            designation: official?.designation ?? u.designation ?? 'Staff',
            department: official?.department ?? u.department ?? 'Operations',
            isActive: u.isActive,
          );
          empMap[u.id] = entity;
          if (code.isNotEmpty) empMap[code.toUpperCase()] = entity;
          if (official != null) empMap[official.employeeId.toUpperCase()] = entity;
          if (fullName.isNotEmpty) empMap[fullName.toLowerCase()] = entity;
          if (u.fullName.isNotEmpty) empMap[u.fullName.toLowerCase()] = entity;
        }

        // Fetch Supabase raw employees table to map employees.id -> user_id & employee_code
        final empRows = await supabase
            .from('employees')
            .select('id, user_id, employee_code, name, full_name, email, photo_url, designation, department')
            .eq('is_deleted', false);
        for (final r in empRows) {
          final m = Map<String, dynamic>.from(r);
          final eId = m['id']?.toString() ?? '';
          final uId = m['user_id']?.toString() ?? '';
          final code = m['employee_code']?.toString() ?? '';
          final name = m['name']?.toString() ?? m['full_name']?.toString() ?? '';
          final email = m['email']?.toString() ?? '';
          final photoUrl = m['photo_url']?.toString();
          final desig = m['designation']?.toString();
          final dept = m['department']?.toString();

          final official = EmployeeDirectoryHelper.resolveOfficialRecord(
            code: code,
            name: name,
            email: email,
            id: eId,
          );

          final resolvedFullName = official?.fullName ?? (name.isNotEmpty && name != 'Staff' ? name : (official?.fullName ?? name));
          final resolvedPhoto = EmployeeDirectoryHelper.resolvePhoto(
            customPhotoUrl: photoUrl,
            employeeCode: code.isNotEmpty ? code : official?.employeeId,
            fullName: resolvedFullName,
            email: email,
            id: eId,
          ) ?? official?.photoAsset;

          if (eId.isNotEmpty) {
            if (uId.isNotEmpty) _empIdCrossReference[eId.toLowerCase()] = uId;
            if (code.isNotEmpty) _empIdCrossReference[eId.toLowerCase()] = code;
            if (official != null) _empIdCrossReference[eId.toLowerCase()] = official.employeeId;

            // If user already in empMap, enrich with photo and official full name
            if (empMap.containsKey(uId)) {
              final existing = empMap[uId]!;
              final enriched = existing.copyWith(
                photoUrl: existing.photoUrl ?? resolvedPhoto,
                name: (official?.fullName != null && official!.fullName.isNotEmpty) ? official.fullName : existing.name,
                designation: official?.designation ?? existing.designation,
                department: official?.department ?? existing.department,
              );
              empMap[uId] = enriched;
              empMap[eId] = enriched;
            } else {
              final newEntity = EmployeeEntity(
                id: eId,
                employeeCode: code.isNotEmpty ? code : (official?.employeeId ?? 'EMP-${eId.length >= 4 ? eId.substring(0, 4).toUpperCase() : eId}'),
                name: resolvedFullName.isNotEmpty ? resolvedFullName : 'Staff',
                mobileNumber: '',
                email: email,
                photoUrl: resolvedPhoto,
                designation: official?.designation ?? desig ?? 'Staff',
                department: official?.department ?? dept ?? 'Operations',
              );
              empMap[eId] = newEntity;
              if (code.isNotEmpty) empMap[code.toUpperCase()] = newEntity;
              if (official != null) empMap[official.employeeId.toUpperCase()] = newEntity;
            }
          }
          if (uId.isNotEmpty && eId.isNotEmpty) {
            _empIdCrossReference[uId.toLowerCase()] = eId;
          }
          if (code.isNotEmpty && eId.isNotEmpty) {
            _empIdCrossReference[code.toLowerCase()] = eId;
          }
          if (name.isNotEmpty && eId.isNotEmpty) {
            _empIdCrossReference[name.toLowerCase()] = eId;
          }
          if (email.isNotEmpty && eId.isNotEmpty) {
            _empIdCrossReference[email.toLowerCase()] = eId;
          }
        }
      } catch (eSync) {
        debugPrint('Supabase employee fetch note: $eSync');
      }

      _employees = empMap.values.toSet().toList();
    } catch (e) {
      debugPrint('Cloud cards query failed, relying on local cards: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }

    // Trigger silent automated compliance check in background
    _checkAutomatedComplianceRobot();
  }

  Future<void> _checkAutomatedComplianceRobot() async {
    try {
      final res = await CardExpiryNotificationService.runAutomatedDailyCheck(
        cards: _cards,
        employeeMap: _getEmployeeMap(),
      );
      if (res['triggered'] == true && mounted) {
        final count = res['count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🤖 Compliance Robot: Dispatched $count renewal notice(s) to sr.irshath@gmail.com & +971586939371.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF6366F1),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Background compliance robot check error: $e');
    }
  }

  Future<void> _persistCardsLocally() async {
    final jsonList = _cards.map((c) => c.toJson()).toList();
    await _db.persistEmployeeCards(jsonList);
  }

  EmployeeEntity _enrichEmployee(EmployeeEntity emp, [EmployeeCard? card]) {
    OfficialEmployeeRecord? official = EmployeeDirectoryHelper.resolveOfficialRecord(
      code: emp.employeeCode,
      name: emp.name,
      email: emp.email,
      id: emp.id,
    );

    if (official == null && card != null) {
      final texts = [
        card.employeeId,
        card.fileName ?? '',
        card.notes ?? '',
        card.cardName,
      ];
      for (final t in texts) {
        if (t.trim().isEmpty) continue;
        official = EmployeeDirectoryHelper.resolveOfficialRecord(
          code: t,
          name: t,
          email: t,
          id: t,
        );
        if (official != null) break;
      }
    }

    final fullName = official?.fullName ??
        EmployeeDirectoryHelper.getCompleteFullName(
          currentName: emp.name,
          email: emp.email,
          code: emp.employeeCode,
          id: emp.id,
        );

    final resolvedPhoto = EmployeeDirectoryHelper.resolvePhoto(
      customPhotoUrl: emp.photoUrl,
      employeeCode: emp.employeeCode.isNotEmpty ? emp.employeeCode : official?.employeeId,
      fullName: fullName,
      email: emp.email,
      id: emp.id,
    ) ?? official?.photoAsset;

    return emp.copyWith(
      name: fullName.isNotEmpty && fullName != 'Staff' && fullName != 'Staff Member'
          ? fullName
          : (official?.fullName ?? emp.name),
      photoUrl: resolvedPhoto ?? emp.photoUrl,
      employeeCode: (emp.employeeCode.isNotEmpty && emp.employeeCode != 'EMP-000')
          ? emp.employeeCode
          : (official?.employeeId ?? emp.employeeCode),
      designation: (official != null && (emp.designation.isEmpty || emp.designation == 'Staff'))
          ? official.designation
          : emp.designation,
      department: (official != null && (emp.department.isEmpty || emp.department == 'Operations'))
          ? official.department
          : emp.department,
    );
  }

  EmployeeEntity? _getEmployee(String empId, [EmployeeCard? card]) {
    final cleanId = empId.trim();

    // 1. Direct ID match in _employees
    if (cleanId.isNotEmpty) {
      for (final e in _employees) {
        if (e.id.toLowerCase() == cleanId.toLowerCase()) {
          return _enrichEmployee(e, card);
        }
      }
    }

    // 2. Cross-reference mapping match (e.g. employees.id UUID <-> users.id UUID / employee_code)
    if (cleanId.isNotEmpty && _empIdCrossReference.containsKey(cleanId.toLowerCase())) {
      final target = _empIdCrossReference[cleanId.toLowerCase()]!;
      for (final e in _employees) {
        if (e.id.toLowerCase() == target.toLowerCase() ||
            e.employeeCode.toUpperCase() == target.toUpperCase() ||
            e.name.toLowerCase() == target.toLowerCase()) {
          return _enrichEmployee(e, card);
        }
      }
    }

    // 3. Employee Code match (e.g. N-1003, 1003, EMP-1003)
    if (cleanId.isNotEmpty) {
      final normCode = cleanId.toUpperCase().replaceAll('EMP-', '');
      for (final e in _employees) {
        final eCode = e.employeeCode.toUpperCase().replaceAll('EMP-', '');
        if (eCode.isNotEmpty && (eCode == normCode || e.employeeCode.toUpperCase() == cleanId.toUpperCase())) {
          return _enrichEmployee(e, card);
        }
      }
    }

    // 4. Email match
    if (cleanId.isNotEmpty && cleanId.contains('@')) {
      for (final e in _employees) {
        if (e.email.trim().toLowerCase() == cleanId.toLowerCase()) {
          return _enrichEmployee(e, card);
        }
      }
    }

    // 5. Name match
    if (cleanId.isNotEmpty) {
      for (final e in _employees) {
        if (e.name.trim().toLowerCase() == cleanId.toLowerCase()) {
          return _enrichEmployee(e, card);
        }
      }
    }

    // 6. Master enterprise directory lookup via EmployeeDirectoryHelper
    if (cleanId.isNotEmpty) {
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: cleanId,
        name: cleanId,
        id: cleanId,
        email: cleanId,
      );
      if (official != null) {
        return EmployeeEntity(
          id: official.employeeId,
          employeeCode: official.employeeId,
          name: official.fullName,
          mobileNumber: '',
          photoUrl: official.photoAsset,
          email: official.email,
          designation: official.designation,
          department: official.department,
        );
      }
    }

    // 7. Check card file name or notes for employee name/code
    if (card != null) {
      final texts = [
        card.fileName ?? '',
        card.notes ?? '',
        card.cardName,
      ];
      for (final t in texts) {
        if (t.trim().isEmpty) continue;
        final tLower = t.toLowerCase();

        // Check against _employees
        for (final e in _employees) {
          if (e.name.length >= 3 && tLower.contains(e.name.toLowerCase())) {
            return _enrichEmployee(e, card);
          }
          final eCode = e.employeeCode.toUpperCase().replaceAll('EMP-', '');
          if (eCode.length >= 3 && t.toUpperCase().contains(eCode)) {
            return _enrichEmployee(e, card);
          }
        }

        // Check against master directory
        for (final off in EmployeeDirectoryHelper.masterDirectory) {
          if (off.fullName.length >= 3 && tLower.contains(off.fullName.toLowerCase())) {
            return EmployeeEntity(
              id: off.employeeId,
              employeeCode: off.employeeId,
              name: off.fullName,
              mobileNumber: '',
              photoUrl: off.photoAsset,
              email: off.email,
              designation: off.designation,
              department: off.department,
            );
          }
          for (final alias in off.aliases) {
            if (alias.length >= 3 && tLower.contains(alias.toLowerCase())) {
              return EmployeeEntity(
                id: off.employeeId,
                employeeCode: off.employeeId,
                name: off.fullName,
                mobileNumber: '',
                photoUrl: off.photoAsset,
                email: off.email,
                designation: off.designation,
                department: off.department,
              );
            }
          }
        }
      }
    }

    return null;
  }

  String _resolveEmployeeDisplayName(EmployeeEntity? emp, EmployeeCard card) {
    if (emp != null) {
      final legalName = EmployeeDirectoryHelper.getCompleteFullName(
        currentName: emp.name,
        email: emp.email,
        code: emp.employeeCode,
        id: emp.id,
      );
      if (legalName.isNotEmpty && legalName != 'Staff' && legalName != 'Staff Member') {
        return legalName;
      }
    }

    // Direct official lookup from card.employeeId
    if (card.employeeId.isNotEmpty) {
      final off = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: card.employeeId,
        id: card.employeeId,
        name: card.employeeId,
      );
      if (off != null) return off.fullName;
    }

    // Attempt extraction from file name (e.g. "Mohammed_Iburahim_Baseer_Ahamed_EMIRATES_ID.pdf" -> "Mohammed Iburahim Baseer Ahamed")
    if (card.fileName != null && card.fileName!.isNotEmpty) {
      var raw = card.fileName!;
      raw = raw.replaceAll(RegExp(r'\.(pdf|png|jpg|jpeg|webp)$', caseSensitive: false), '');
      raw = raw.replaceAll(RegExp(r'_(EMIRATES_ID|VISA|PASSPORT|INSURANCE|MOPA|CISPA|PASS|CARD).*$', caseSensitive: false), '');
      raw = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
      if (raw.isNotEmpty && raw.length >= 3 && !raw.toLowerCase().contains('unnamed') && !raw.toLowerCase().contains('scan')) {
        final off = EmployeeDirectoryHelper.resolveOfficialRecord(name: raw);
        if (off != null) return off.fullName;
        return raw;
      }
    }

    // Check if card notes contain holder name
    if (card.notes != null && card.notes!.isNotEmpty) {
      final match = RegExp(r'holder[:\s]+([^\n\r,]+)', caseSensitive: false).firstMatch(card.notes!);
      if (match != null && match.group(1) != null) {
        final candidate = match.group(1)!.trim();
        if (candidate.isNotEmpty) {
          final off = EmployeeDirectoryHelper.resolveOfficialRecord(name: candidate);
          if (off != null) return off.fullName;
          return candidate;
        }
      }
    }

    if (card.employeeId.isNotEmpty && !card.employeeId.contains('-') && card.employeeId.length <= 10) {
      return 'Staff (${card.employeeId})';
    }
    return (emp != null && emp.name.isNotEmpty && emp.name != 'Staff') ? emp.name : 'Staff';
  }

  String get _currentTabId => _tabsConfig[_tabController.index]['id'] as String;

  List<EmployeeCard> _getCardsForTab(String tabId) {
    if (tabId == 'ALL') {
      return _cards;
    }
    if (tabId == 'EXPIRING_SOON') {
      return _cards.where((c) => !c.isExpired && c.daysUntilExpiry <= 30).toList();
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
    final emp = _getEmployee(card.employeeId, card);
    final empName = _resolveEmployeeDisplayName(emp, card);
    final empCode = emp?.employeeCode ?? (card.employeeId.length <= 10 ? card.employeeId : 'N/A');
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
    final emp = _getEmployee(card.employeeId, card);
    final empName = _resolveEmployeeDisplayName(emp, card);
    final empCode = emp?.employeeCode ?? (card.employeeId.length <= 10 ? card.employeeId : 'N/A');
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

  // Preview Uploaded Document
  void _showDocumentPreviewDialog(EmployeeCard card) async {
    final rawDocUrl = card.documentUrl;
    final fileName = card.fileName ?? 'Document';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (rawDocUrl == null || rawDocUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document attachment found for this card.')),
      );
      return;
    }

    // Generate time-limited signed URL for zero-trust security
    final docUrl = await SupabaseService().getSignedEmployeeCardUrl(rawDocUrl) ?? rawDocUrl;
    if (!mounted) return;

    Uint8List? imageBytes;
    final isPdf = fileName.toLowerCase().endsWith('.pdf') || docUrl.startsWith('data:application/pdf');

    if (docUrl.startsWith('data:image/')) {
      try {
        final commaIdx = docUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? docUrl.substring(commaIdx + 1) : docUrl;
        imageBytes = base64Decode(base64Str);
      } catch (_) {}
    } else if (!isPdf && !docUrl.startsWith('http')) {
      try {
        imageBytes = base64Decode(docUrl);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPdf ? Colors.red.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                color: isPdf ? Colors.redAccent : Colors.blueAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${card.cardName} • #${card.cardNumber}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              if (imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 380),
                    color: Colors.black12,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                )
              else if (docUrl.startsWith('http') && !isPdf)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 380),
                    color: Colors.black12,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Image.network(
                        docUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                )
              else if (isPdf)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 56, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(
                        fileName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PDF Document (${(docUrl.length * 0.75 / 1024).toStringAsFixed(1)} KB)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Extracted Card #: ${card.cardNumber}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.insert_drive_file_rounded, size: 48, color: Colors.blueGrey),
                      const SizedBox(height: 10),
                      Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        'Attached document stored with record',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download Document'),
            onPressed: () {
              Navigator.pop(ctx);
              _downloadCardDocument(card);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // DOWNLOAD & EXPORT CONTROLLER (PDF / ORIGINAL ATTACHMENTS)
  // --------------------------------------------------------------------------

  Future<void> _downloadCardDocument(EmployeeCard card) async {
    final docUrl = card.documentUrl;
    final emp = _getEmployee(card.employeeId, card);
    final empName = _resolveEmployeeDisplayName(emp, card);
    final safeEmpName = empName.replaceAll(RegExp(r'[^\w\s]+'), '_').trim();
    final fileName = card.fileName ?? '${safeEmpName}_${card.cardName}.pdf';

    try {
      if (docUrl != null && docUrl.isNotEmpty) {
        if (docUrl.startsWith('data:')) {
          final commaIdx = docUrl.indexOf(',');
          final base64Str = commaIdx != -1 ? docUrl.substring(commaIdx + 1) : docUrl;
          final bytes = base64Decode(base64Str);
          await Printing.sharePdf(bytes: bytes, filename: fileName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('⬇️ Downloading document: $fileName')),
            );
          }
          return;
        } else if (docUrl.startsWith('http://') || docUrl.startsWith('https://')) {
          final secureUrl = await SupabaseService().getSignedEmployeeCardUrl(docUrl) ?? docUrl;
          final uri = Uri.parse(secureUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        }
      }

      // If no raw file is attached, generate a branded official card certificate / pass
      final pdfBytes = await _generateCardPassPdf(card, emp);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${safeEmpName}_${card.cardType}_Official_Pass.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⬇️ Downloading official pass for $empName...')),
        );
      }
    } catch (e) {
      debugPrint('Error downloading card document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download document: $e')),
        );
      }
    }
  }

  Future<Uint8List> _generateCardPassPdf(EmployeeCard card, EmployeeEntity? emp) async {
    final pdf = pw.Document();
    final empName = emp?.name ?? 'Employee';
    final empCode = emp?.employeeCode ?? 'N/A';
    final dept = emp?.department ?? 'General';
    final desig = emp?.designation ?? 'Staff';
    final issueStr = card.issueDate != null ? _dateFormat.format(card.issueDate!) : 'N/A';
    final expiryStr = _dateFormat.format(card.expiryDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey700, width: 2),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FUSION 360 WORKFORCE RECORD',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          'Official Document & Card Control Record',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: card.isExpired ? PdfColors.red100 : (card.isCritical ? PdfColors.amber100 : PdfColors.teal100),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        card.statusLabel.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: card.isExpired ? PdfColors.red900 : (card.isCritical ? PdfColors.amber900 : PdfColors.teal900),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.blueGrey300),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('DOCUMENT TYPE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text(card.cardName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Text('CARD / DOCUMENT NUMBER', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text(card.cardNumber, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                          pw.SizedBox(height: 10),
                          pw.Row(
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('ISSUE DATE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                                  pw.Text(issueStr, style: const pw.TextStyle(fontSize: 10)),
                                ],
                              ),
                              pw.SizedBox(width: 24),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('EXPIRY DATE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                                  pw.Text(expiryStr, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: card.isExpired ? PdfColors.red : PdfColors.black)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('HOLDER / EMPLOYEE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text(empName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Employee Code: $empCode', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.Text('Designation: $desig', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.Text('Department: $dept', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (card.notes != null && card.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Text('NOTES / RENEWAL STATUS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text(card.notes!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                ],
                pw.Spacer(),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Generated by Fusion 360 Workforce System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    pw.Text('Date: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _downloadAllCardsReport(List<EmployeeCard> cardsList, String title) async {
    if (cardsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available to download.')),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('FUSION 360 — $title REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text('Total: ${cardsList.length} cards • Generated: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: ['Employee', 'Code', 'Document Type', 'Document #', 'Issue Date', 'Expiry Date', 'Status'],
                data: cardsList.map((c) {
                  final emp = _getEmployee(c.employeeId, c);
                  return [
                    _resolveEmployeeDisplayName(emp, c),
                    emp?.employeeCode ?? (c.employeeId.length <= 10 ? c.employeeId : 'N/A'),
                    c.cardName,
                    c.cardNumber,
                    c.issueDate != null ? _dateFormat.format(c.issueDate!) : 'N/A',
                    _dateFormat.format(c.expiryDate),
                    c.statusLabel,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellHeight: 22,
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '_').trim();
      await Printing.sharePdf(bytes: bytes, filename: '${safeTitle}_Cards_Report.pdf');
    } catch (e) {
      debugPrint('Error generating cards report PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export cards report: $e')),
        );
      }
    }
  }

  // Gemini AI Vision API Key Setup Dialog
  void _showGeminiKeyDialog(BuildContext context, [VoidCallback? onSaved]) {
    final currentKey = _db.getGeminiApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight),
            SizedBox(width: 8),
            Text('Gemini AI Vision Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Powers 100% accurate extraction for Emirates ID, UAE Visas, Passports, Insurance cards, and PDFs.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.key_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final uri = Uri.parse('https://aistudio.google.com/app/apikey');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text(
                'Get free Gemini API Key at Google AI Studio ↗',
                style: TextStyle(fontSize: 11, color: Colors.blueAccent, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        actions: [
          if (currentKey.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _db.saveGeminiApiKey(null);
                if (mounted) setState(() {});
                if (onSaved != null) onSaved();
                Navigator.pop(ctx);
              },
              child: const Text('Clear Key', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await _db.saveGeminiApiKey(controller.text.trim());
              if (mounted) setState(() {});
              if (onSaved != null) onSaved();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Gemini AI API Key saved! AI Vision is now active.')),
              );
            },
            child: const Text('Save Key', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Map<String, EmployeeEntity> _getEmployeeMap() {
    final map = <String, EmployeeEntity>{};
    for (final e in _employees) {
      map[e.id] = e;
      if (e.employeeCode.isNotEmpty) {
        map[e.employeeCode.toUpperCase()] = e;
        map[e.employeeCode.toUpperCase().replaceAll('EMP-', '')] = e;
      }
      if (e.email.isNotEmpty) {
        map[e.email.toLowerCase()] = e;
      }
      if (e.name.isNotEmpty) {
        map[e.name.toLowerCase()] = e;
      }
    }
    for (final entry in _empIdCrossReference.entries) {
      if (!map.containsKey(entry.key) && map.containsKey(entry.value)) {
        map[entry.key] = map[entry.value]!;
      }
    }
    return map;
  }

  void _markCardsNotified(List<EmployeeCard> notifiedCards) {
    setState(() {
      final now = DateTime.now();
      for (final c in notifiedCards) {
        final idx = _cards.indexWhere((item) => item.id == c.id);
        if (idx != -1) {
          _cards[idx] = _cards[idx].copyWith(lastNotifiedAt: now);
        }
      }
      _persistCardsLocally();
    });
  }

  // 1-Click Automated WhatsApp to +971586939371
  Future<void> _notifyAdminWhatsAppDigest() async {
    final expiring = CardExpiryNotificationService.getExpiringCardsWithinDays(_cards, days: 3);
    if (expiring.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All documents are valid. No cards expiring within 3 days.')),
        );
      }
      return;
    }

    final success = await CardExpiryNotificationService.launchWhatsAppClient(
      cards: expiring,
      employeeMap: _getEmployeeMap(),
      targetPhone: CardExpiryNotificationService.defaultAdminPhone,
    );

    if (success) {
      _markCardsNotified(expiring);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Launched WhatsApp with 3-day renewal alerts for +971586939371'),
            backgroundColor: Color(0xFF25D366),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp.')),
        );
      }
    }
  }

  // 1-Click Automated Email to sr.irshath@gmail.com
  Future<void> _notifyAdminEmailDigest() async {
    final expiring = CardExpiryNotificationService.getExpiringCardsWithinDays(_cards, days: 3);
    if (expiring.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All documents are valid. No cards expiring within 3 days.')),
        );
      }
      return;
    }

    final success = await CardExpiryNotificationService.launchEmailClient(
      cards: expiring,
      employeeMap: _getEmployeeMap(),
      targetEmail: CardExpiryNotificationService.defaultAdminEmail,
    );

    if (success) {
      _markCardsNotified(expiring);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prepared 3-day renewal email alert for sr.irshath@gmail.com'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client.')),
        );
      }
    }
  }

  // Automated Compliance Robot Configuration Modal
  void _showRobotConfigDialog() {
    final resendController = TextEditingController(text: _db.getResendApiKey() ?? '');
    final callMeBotController = TextEditingController(text: _db.getCallMeBotApiKey() ?? '');
    final targetEmailController = TextEditingController(text: _db.getNotificationTargetEmail());
    bool isRobotEnabled = _db.isAutoNotificationRobotEnabled();
    bool isTestingEmail = false;
    bool isTestingWhatsApp = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF6366F1), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Background Robot Config',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Automated 3-day silent alerts (Email & WhatsApp)',
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
                      // Target Email(s) Input
                      const Text(
                        '📬 Recipient Email Address(es)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Separate multiple emails with commas. Verified domain: fusionmaint.org',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: targetEmailController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'sr.irshath@gmail.com, nasuru@fusionmaint.com',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.email_outlined, size: 16),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // WhatsApp Summary
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.chat_outlined, size: 14, color: Color(0xFF25D366)),
                            SizedBox(width: 8),
                            Text(
                              'Target WhatsApp: +971 58 693 9371',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(height: 16),

                      // Enable Toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Daily Automated Robot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Silently triggers check at startup & via daily cloud cron', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        value: isRobotEnabled,
                        activeThumbColor: const Color(0xFF6366F1),
                        onChanged: (val) => setDialogState(() => isRobotEnabled = val),
                      ),
                      const Divider(height: 20),

                      // 1. Resend Free API Key
                      Row(
                        children: [
                          const Icon(Icons.mark_email_read_rounded, size: 16, color: Colors.blueAccent),
                          const SizedBox(width: 6),
                          const Text('Resend API Key (Free Email Robot)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          const Text('3,000 Free/Mo', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get your free key from resend.com/api-keys. Sends formatted HTML alerts silently.',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: resendController,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 're_123456789...',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.key, size: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isTestingEmail
                                ? null
                                : () async {
                                    final key = resendController.text.trim();
                                    if (key.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter a Resend API key first')),
                                      );
                                      return;
                                    }
                                    setDialogState(() => isTestingEmail = true);
                                    final res = await CardExpiryNotificationService.testResendEmailConnection(
                                      resendApiKey: key,
                                      targetEmail: targetEmailController.text.trim(),
                                    );
                                    setDialogState(() => isTestingEmail = false);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message'] ?? ''),
                                          backgroundColor: res['success'] == true ? Colors.green : Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                            child: isTestingEmail
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Test Email', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 2. CallMeBot Free WhatsApp API Key
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF25D366)),
                          const SizedBox(width: 6),
                          const Text('CallMeBot API Key (Free WhatsApp Robot)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          const Text('100% Free', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'To get free key: Text "I allow callmebot to send me messages" to +34 911 98 05 60 on WhatsApp.',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: callMeBotController,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'CallMeBot apikey...',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isTestingWhatsApp
                                ? null
                                : () async {
                                    final key = callMeBotController.text.trim();
                                    if (key.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter a CallMeBot API key first')),
                                      );
                                      return;
                                    }
                                    setDialogState(() => isTestingWhatsApp = true);
                                    final res = await CardExpiryNotificationService.testCallMeBotConnection(callMeBotApiKey: key);
                                    setDialogState(() => isTestingWhatsApp = false);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message'] ?? ''),
                                          backgroundColor: res['success'] == true ? Colors.green : Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                            child: isTestingWhatsApp
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Test WA', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
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
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final resendKey = resendController.text.trim();
                    final callMeBotKey = callMeBotController.text.trim();
                    final targetEmail = targetEmailController.text.trim();

                    await _db.saveResendApiKey(resendKey);
                    await _db.saveCallMeBotApiKey(callMeBotKey);
                    await _db.saveNotificationTargetEmail(targetEmail);
                    await _db.setAutoNotificationRobotEnabled(isRobotEnabled);

                    // Sync to Supabase compliance_notification_settings if online
                    try {
                      final supabase = Supabase.instance.client;
                      await supabase.from('compliance_notification_settings').upsert({
                        'resend_api_key': resendKey,
                        'callmebot_api_key': callMeBotKey,
                        'target_email': targetEmail.isNotEmpty ? targetEmail : CardExpiryNotificationService.defaultAdminEmail,
                        'target_phone': CardExpiryNotificationService.defaultAdminPhone.replaceAll(RegExp(r'[^0-9]'), ''),
                        'is_automated_enabled': isRobotEnabled,
                        'updated_at': DateTime.now().toIso8601String(),
                      });
                    } catch (e) {
                      debugPrint('Supabase settings sync error: $e');
                    }

                    if (ctx.mounted) Navigator.pop(ctx);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Compliance Robot settings saved & synced successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Trigger immediate check with new credentials
                      _checkAutomatedComplianceRobot();
                    }
                  },
                  child: const Text('Save Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Upload or Edit Card Dialog with active tab pre-selection
  void _showAddEditCardDialog({EmployeeCard? cardToEdit, String? defaultType}) {
    final isEditing = cardToEdit != null;

    String initialType = cardToEdit?.cardType ?? defaultType ?? _currentTabId;
    if (initialType == 'ALL' || initialType == 'EXPIRING_SOON') {
      initialType = 'EMIRATES_ID';
    }

    EmployeeEntity? matchedInitialEmp;
    if (isEditing) {
      matchedInitialEmp = _getEmployee(cardToEdit.employeeId, cardToEdit);
    }
    String selectedEmpId = matchedInitialEmp != null
        ? matchedInitialEmp.id
        : (isEditing
            ? cardToEdit.employeeId
            : (_employees.isNotEmpty ? _employees.first.id : ''));
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
    String? uploadedFileName = cardToEdit?.fileName;
    String? uploadedFileUrl = cardToEdit?.documentUrl;
    Uint8List? uploadedFileBytes;
    int? uploadedFileSize;

    if (uploadedFileUrl != null && uploadedFileUrl.startsWith('data:image')) {
      try {
        final commaIdx = uploadedFileUrl.indexOf(',');
        if (commaIdx != -1) {
          uploadedFileBytes = base64Decode(uploadedFileUrl.substring(commaIdx + 1));
        }
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedEmp = _getEmployee(selectedEmpId) ??
              matchedInitialEmp ??
              (_employees.isNotEmpty
                  ? _employees.first
                  : EmployeeEntity(id: '', name: 'Staff', employeeCode: 'EMP', department: '', designation: '', mobileNumber: '', email: ''));

          Future<void> pickDocumentFromComputer() async {
            try {
              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'bmp'],
                withData: true,
              );

              if (result == null || result.files.isEmpty) return;
              final file = result.files.first;

              Uint8List? rawBytes = file.bytes;
              if (rawBytes == null && file.path != null && !kIsWeb) {
                try {
                  rawBytes = await io.File(file.path!).readAsBytes();
                } catch (e) {
                  debugPrint('Could not read bytes from file.path: $e');
                }
              }

              Uint8List? compressedBytes = rawBytes;
              final isPdf = file.name.toLowerCase().endsWith('.pdf');
              if (rawBytes != null && !isPdf) {
                try {
                  final decoded = img.decodeImage(rawBytes);
                  if (decoded != null) {
                    img.Image resized = decoded;
                    if (decoded.width > 1280 || decoded.height > 1280) {
                      if (decoded.width > decoded.height) {
                        resized = img.copyResize(decoded, width: 1280);
                      } else {
                        resized = img.copyResize(decoded, height: 1280);
                      }
                    }
                    compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 78));
                    debugPrint('Card compressed: ${rawBytes.length} -> ${compressedBytes.length} bytes (${((1 - compressedBytes.length / rawBytes.length) * 100).toStringAsFixed(1)}% reduction)');
                  }
                } catch (e) {
                  debugPrint('Card image compression fallback: $e');
                }
              }

              setDialogState(() {
                isScanning = true;
                uploadedFileName = file.name;
                uploadedFileBytes = compressedBytes;
                uploadedFileSize = compressedBytes?.length ?? file.size;
                if (compressedBytes != null) {
                  final mime = isPdf ? 'application/pdf' : 'image/jpeg';
                  uploadedFileUrl = 'data:$mime;base64,${base64Encode(compressedBytes)}';
                }
              });

              final ocrRes = await CardOcrService.extractFromFile(
                fileName: file.name,
                fileBytes: compressedBytes,
                filePath: file.path,
                preferredCardType: selectedType,
                employee: selectedEmp,
              );

              setDialogState(() {
                isScanning = false;
                scanResult = ocrRes;
                if (ocrRes.confidence > 0) {
                  selectedType = ocrRes.cardType;
                  if (ocrRes.cardNumber.isNotEmpty) {
                    cardNumController.text = ocrRes.cardNumber;
                  }
                  cardNameController.text = ocrRes.cardName;
                  selectedExpiry = ocrRes.expiryDate;
                  if (ocrRes.issueDate != null) selectedIssue = ocrRes.issueDate;
                  if (ocrRes.notes != null && ocrRes.notes!.isNotEmpty) {
                    notesController.text = ocrRes.notes!;
                  }
                  if (ocrRes.holderName != null && ocrRes.holderName!.isNotEmpty) {
                    final hLower = ocrRes.holderName!.toLowerCase();
                    try {
                      final matched = _employees.firstWhere(
                        (e) => e.name.toLowerCase().contains(hLower) || hLower.contains(e.name.toLowerCase()),
                      );
                      if (matched.id.isNotEmpty) {
                        selectedEmpId = matched.id;
                      }
                    } catch (_) {}
                  }
                }
              });
            } catch (err) {
              setDialogState(() => isScanning = false);
              debugPrint('Error picking or extracting document: $err');
            }
          }

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
                      items: () {
                        final dropdownEmployees = List<EmployeeEntity>.from(_employees);
                        if (selectedEmpId.isNotEmpty && !dropdownEmployees.any((e) => e.id == selectedEmpId)) {
                          dropdownEmployees.insert(0, selectedEmp);
                        }
                        return dropdownEmployees.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.id,
                            child: Text('${e.name} (${e.employeeCode}) - ${e.department}'),
                          );
                        }).toList();
                      }(),
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
                          .where((t) => t['id'] != 'ALL' && t['id'] != 'EXPIRING_SOON')
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
                              InkWell(
                                onTap: () => _showGeminiKeyDialog(context, () => setDialogState(() {})),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _db.getGeminiApiKey() != null
                                        ? Colors.teal.withValues(alpha: 0.15)
                                        : Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _db.getGeminiApiKey() != null ? Colors.teal : Colors.amber.shade700,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _db.getGeminiApiKey() != null ? Icons.auto_awesome_rounded : Icons.key_rounded,
                                        size: 11,
                                        color: _db.getGeminiApiKey() != null ? Colors.teal : Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _db.getGeminiApiKey() != null ? 'Gemini AI Vision ✓' : 'Set Gemini AI Key',
                                        style: TextStyle(
                                          color: _db.getGeminiApiKey() != null ? Colors.teal : Colors.amber.shade800,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Upload a document from your computer (PDF, PNG, JPG) or scan with camera:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),

                          // Document File Dropzone Box
                          InkWell(
                            onTap: isScanning ? null : pickDocumentFromComputer,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: uploadedFileName != null
                                    ? AppColors.primaryLight.withValues(alpha: 0.08)
                                    : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: uploadedFileName != null
                                      ? AppColors.primaryLight
                                      : Colors.grey.withValues(alpha: 0.35),
                                  width: uploadedFileName != null ? 1.5 : 1.0,
                                ),
                              ),
                              child: uploadedFileName != null
                                  ? Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: (uploadedFileBytes != null &&
                                                  !uploadedFileName!.toLowerCase().endsWith('.pdf'))
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.memory(
                                                    uploadedFileBytes!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(
                                                        Icons.description_rounded,
                                                        color: AppColors.primaryLight),
                                                  ),
                                                )
                                              : Icon(
                                                  uploadedFileName!.toLowerCase().endsWith('.pdf')
                                                      ? Icons.picture_as_pdf_rounded
                                                      : Icons.insert_drive_file_rounded,
                                                  color: uploadedFileName!.toLowerCase().endsWith('.pdf')
                                                      ? Colors.redAccent
                                                      : AppColors.primaryLight,
                                                  size: 24,
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      uploadedFileName!,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      '✓ Attached',
                                                      style: TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                uploadedFileSize != null
                                                    ? '${(uploadedFileSize! / (1024 * 1024)).toStringAsFixed(2)} MB • Auto-extracted details below'
                                                    : 'Document attached • Auto-extracted details below',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                                          tooltip: 'Remove Attachment',
                                          onPressed: () {
                                            setDialogState(() {
                                              uploadedFileName = null;
                                              uploadedFileBytes = null;
                                              uploadedFileUrl = null;
                                              uploadedFileSize = null;
                                            });
                                          },
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.upload_file_rounded,
                                              color: AppColors.primaryLight, size: 24),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Choose Document from Computer',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppColors.primaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Click to browse PDF, PNG, JPG from your computer • Auto-fetches all card details',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),

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
                                      'Reading document & extracting numbers & expiry dates via OCR...',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryLight,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                                  label: const Text('Upload from Computer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () => pickDocumentFromComputer(),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                          try {
                                            final cleanBytes = base64Decode(camRes.base64Image);
                                            setDialogState(() {
                                              uploadedFileName = 'camera_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                              uploadedFileBytes = cleanBytes;
                                              uploadedFileSize = cleanBytes.length;
                                              uploadedFileUrl = 'data:image/jpeg;base64,${camRes.base64Image}';
                                            });
                                          } catch (_) {}
                                          runOcrScan(rawOcrText: camRes.base64Image);
                                        },
                                      ),
                                    );
                                  },
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                                  label: const Text('Auto-Extract Data', style: TextStyle(fontSize: 11)),
                                  onPressed: () => runOcrScan(),
                                ),
                              ],
                            ),

                          if (scanResult != null) ...[
                            const SizedBox(height: 10),
                            Builder(
                              builder: (context) {
                                final isSuccess = scanResult!.confidence > 0;
                                final isWarning = !isSuccess && scanResult!.extractionSummary.contains('not configured');
                                final Color cardColor = isSuccess
                                    ? (scanResult!.isUrgentAlert ? Colors.red : Colors.green)
                                    : (isWarning ? Colors.amber.shade800 : Colors.red);

                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cardColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: cardColor.withValues(alpha: 0.35)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isSuccess
                                                ? (scanResult!.isUrgentAlert ? Icons.warning_amber_rounded : Icons.check_circle_rounded)
                                                : Icons.error_outline_rounded,
                                            size: 20,
                                            color: cardColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isSuccess
                                                  ? (scanResult!.isUrgentAlert ? '⚠️ Expiring Soon' : 'Data Successfully Extracted!')
                                                  : (isWarning ? '⚠️ Action Required' : '❌ Extraction Failed'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: cardColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        scanResult!.extractionSummary,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      if (!isSuccess) ...[
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _showGeminiKeyDialog(context, () => setDialogState(() {})),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: cardColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: cardColor, width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.key_rounded, size: 12, color: cardColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Configure / Update Gemini AI Key',
                                                  style: TextStyle(
                                                    color: cardColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
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

                  final cardId = isEditing
                      ? cardToEdit.id
                      : ((cardToEdit?.id.isNotEmpty == true) ? cardToEdit!.id : const Uuid().v4());

                  String? finalDocUrl = uploadedFileUrl ?? cardToEdit?.documentUrl;

                  // Ultra-optimized cloud storage: upload binary file to Supabase Storage 'employee_documents' bucket
                  // This keeps PostgreSQL database row < 1 KB by storing an ~85-byte CDN URL instead of megabytes!
                  if (uploadedFileBytes != null && (uploadedFileName != null || cardToEdit?.fileName != null)) {
                    final targetFileName = uploadedFileName ?? cardToEdit?.fileName ?? 'card.jpg';
                    final isPdf = targetFileName.toLowerCase().endsWith('.pdf');
                    try {
                      final cdnUrl = await SupabaseService().uploadEmployeeCardDocument(
                        employeeId: selectedEmpId,
                        cardId: cardId,
                        bytes: uploadedFileBytes!,
                        fileName: targetFileName,
                        mimeType: isPdf ? 'application/pdf' : 'image/jpeg',
                      );
                      if (cdnUrl != null && cdnUrl.isNotEmpty) {
                        finalDocUrl = cdnUrl;
                        debugPrint('Stored card in Supabase Storage: $cdnUrl');
                      }
                    } catch (storageErr) {
                      debugPrint('Storage upload note (fallback to compressed data): $storageErr');
                    }
                  }

                  final newCard = EmployeeCard(
                    id: cardId,
                    organizationId: _db.currentUser?.organizationId ?? '00000000-0000-0000-0000-000000000001',
                    employeeId: selectedEmpId,
                    cardType: selectedType,
                    cardName: cardNameController.text.trim(),
                    cardNumber: cardNumController.text.trim(),
                    issueDate: selectedIssue,
                    expiryDate: selectedExpiry,
                    notes: notesController.text.trim(),
                    documentUrl: finalDocUrl,
                    fileName: uploadedFileName ?? cardToEdit?.fileName,
                  );

                  // 1. Immediately commit to local state & Hive storage
                  setState(() {
                    if (isEditing) {
                      final idx = _cards.indexWhere((c) => c.id == cardToEdit.id);
                      if (idx != -1) {
                        _cards[idx] = newCard;
                      } else {
                        _cards.insert(0, newCard);
                      }
                    } else {
                      _cards.insert(0, newCard);
                    }
                  });
                  await _persistCardsLocally();

                  // 2. Sync to Supabase cloud table (non-blocking)
                  try {
                    final supabase = Supabase.instance.client;
                    await supabase.from('employee_cards').upsert(newCard.toJson());
                  } catch (dbErr) {
                    debugPrint('Supabase employee_cards sync note (saved locally): $dbErr');
                  }

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
      });
      await _persistCardsLocally();

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
          (_currentTabId == 'ALL' || _currentTabId == 'EXPIRING_SOON')
              ? 'Upload Card'
              : 'Upload ${_tabsConfig[_tabController.index]['label']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showAddEditCardDialog(
          defaultType: (_currentTabId == 'ALL' || _currentTabId == 'EXPIRING_SOON')
              ? 'EMIRATES_ID'
              : _currentTabId,
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
                            color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.2),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: isDark ? 0.25 : 0.08),
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
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '🚨 Urgent Renewal Notice: $totalUrgentCount document(s) expiring within 3 days!',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        Text(
                                          'Automated alerts configured for sr.irshath@gmail.com and +971586939371',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  // WhatsApp Action to +971586939371
                                  AppBounceable(
                                    onTap: _notifyAdminWhatsAppDigest,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF25D366).withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.chat_rounded, color: Colors.white, size: 13),
                                          SizedBox(width: 5),
                                          Text(
                                            'WhatsApp Alert (+971 58 693 9371)',
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

                                  // Email Action to sr.irshath@gmail.com
                                  AppBounceable(
                                    onTap: _notifyAdminEmailDigest,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blueAccent.withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.email_rounded, color: Colors.white, size: 13),
                                          SizedBox(width: 5),
                                          Text(
                                            'Email Alert (sr.irshath@gmail.com)',
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

                                  // Robot Config Action
                                  AppBounceable(
                                    onTap: _showRobotConfigDialog,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.smart_toy_rounded, color: Colors.white, size: 13),
                                          SizedBox(width: 5),
                                          Text(
                                            'Robot Config (Auto-Send)',
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

                // Tab Content View - Only build the currently active tab to prevent 7x layout overhead
                Expanded(
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      final t = _tabsConfig[_tabController.index];
                      return _buildTabView(
                        tabId: t['id'] as String,
                        tabName: t['label'] as String,
                        tabFullName: t['fullName'] as String,
                        tabIcon: t['icon'] as IconData,
                        tabColor: t['color'] as Color,
                        isDark: isDark,
                      );
                    },
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
      final emp = _getEmployee(card.employeeId, card);
      final displayName = _resolveEmployeeDisplayName(emp, card);
      final query = _searchQuery.toLowerCase();
      final matchQuery = displayName.toLowerCase().contains(query) ||
          (emp?.name.toLowerCase().contains(query) ?? false) ||
          (emp?.employeeCode.toLowerCase().contains(query) ?? false) ||
          card.cardName.toLowerCase().contains(query) ||
          card.cardNumber.toLowerCase().contains(query) ||
          (card.fileName?.toLowerCase().contains(query) ?? false);

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

            // Search and Status Filter Bar (Responsive to prevent RenderFlex overflow)
            LayoutBuilder(
              builder: (context, searchConstraints) {
                final isCompact = searchConstraints.maxWidth < 680;
                final searchField = TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search $tabName by employee name, code, or number...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                );

                final filterControls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    const SizedBox(width: 8),
                    // View Mode Toggle (Grid vs List)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.grid_view_rounded,
                              size: 18,
                              color: _isGridView ? AppColors.primaryLight : (isDark ? Colors.grey : Colors.grey.shade600),
                            ),
                            tooltip: 'Digital ID Wallet Passes (Grid)',
                            onPressed: () => setState(() => _isGridView = true),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.view_agenda_rounded,
                              size: 18,
                              color: !_isGridView ? AppColors.primaryLight : (isDark ? Colors.grey : Colors.grey.shade600),
                            ),
                            tooltip: 'Compact List View',
                            onPressed: () => setState(() => _isGridView = false),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(color: AppColors.primaryLight, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _downloadAllCardsReport(filtered, tabFullName),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: filterControls,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 10),
                    filterControls,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // 2. Cards Grid / List or Dedicated Empty State
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
          else if (_isGridView)
            _buildCardsGrid(filtered, isDark, tabIcon, tabColor)
          else
            _buildCardsList(filtered, isDark, tabIcon, tabColor),

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
              defaultType: (tabId == 'ALL' || tabId == 'EXPIRING_SOON') ? 'EMIRATES_ID' : tabId,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCardColor(String cardType, bool isDark) {
    if (isDark) {
      switch (cardType) {
        case 'EMIRATES_ID':
          return const Color(0xFF13221C); // Deep muted emerald
        case 'VISA':
          return const Color(0xFF121B2B); // Deep muted navy
        case 'PASSPORT':
          return const Color(0xFF24151B); // Deep muted wine
        case 'INSURANCE':
          return const Color(0xFF102424); // Deep muted teal
        case 'MOPA_PASS':
          return const Color(0xFF211D12); // Deep muted slate-gold
        case 'CISPA_PASS':
          return const Color(0xFF241618); // Deep muted crimson-slate
        case 'CUSTOM_PASS':
        default:
          return const Color(0xFF1B1B26); // Deep muted slate
      }
    } else {
      switch (cardType) {
        case 'EMIRATES_ID':
          return const Color(0xFFF0FDF4); // Softest emerald tint
        case 'VISA':
          return const Color(0xFFF0F7FF); // Softest sky tint
        case 'PASSPORT':
          return const Color(0xFFFFF1F2); // Softest rose tint
        case 'INSURANCE':
          return const Color(0xFFF0FDFA); // Softest teal tint
        case 'MOPA_PASS':
          return const Color(0xFFFEFCE8); // Softest warm amber tint
        case 'CISPA_PASS':
          return const Color(0xFFFFF7ED); // Softest warm orange tint
        case 'CUSTOM_PASS':
        default:
          return const Color(0xFFF8FAFC); // Clean enterprise neutral slate
      }
    }
  }

  Color _getCardAccentBorder(String cardType, bool isDark) {
    switch (cardType) {
      case 'EMIRATES_ID':
        return const Color(0xFF059669);
      case 'VISA':
        return const Color(0xFF2563EB);
      case 'PASSPORT':
        return const Color(0xFFE11D48);
      case 'INSURANCE':
        return const Color(0xFF0D9488);
      case 'MOPA_PASS':
        return const Color(0xFFD97706);
      case 'CISPA_PASS':
        return const Color(0xFFEA580C);
      case 'CUSTOM_PASS':
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _formatCardNumber(String number, String cardType) {
    if (number.isEmpty) return '•••• •••• ••••';
    final clean = number.trim();
    if (cardType == 'EMIRATES_ID') {
      final digits = clean.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 15) {
        return '${digits.substring(0, 3)} • ${digits.substring(3, 7)} • ${digits.substring(7, 14)} • ${digits.substring(14)}';
      }
    }
    final noSpaces = clean.replaceAll(' ', '');
    if (RegExp(r'^[A-Za-z0-9]{12,19}$').hasMatch(noSpaces)) {
      final buffer = StringBuffer();
      for (int i = 0; i < noSpaces.length; i++) {
        if (i > 0 && i % 4 == 0) buffer.write(' • ');
        buffer.write(noSpaces[i]);
      }
      return buffer.toString();
    }
    return clean;
  }

  Widget _buildEmvChip() {
    return Container(
      width: 36,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFDE68A),
            Color(0xFFD97706),
            Color(0xFFFBBF24),
            Color(0xFFB45309),
          ],
        ),
        border: Border.all(color: const Color(0xFFB45309), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 26,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: const Color(0xFF78350F).withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  height: 0.8,
                  color: const Color(0xFF78350F).withValues(alpha: 0.5),
                ),
              ),
              Center(
                child: Container(
                  width: 0.8,
                  color: const Color(0xFF78350F).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardsGrid(
    List<EmployeeCard> filtered,
    bool isDark,
    IconData tabIcon,
    Color tabColor,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        if (width >= 1150) {
          crossAxisCount = 3;
        } else if (width >= 650) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        if (crossAxisCount == 1) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildProfessionalWalletCard(
                filtered[index],
                isDark,
                tabIcon,
                tabColor,
              );
            },
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 320,
          ),
          itemBuilder: (context, index) {
            return _buildProfessionalWalletCard(
              filtered[index],
              isDark,
              tabIcon,
              tabColor,
            );
          },
        );
      },
    );
  }

  Widget _buildProfessionalWalletCard(
    EmployeeCard card,
    bool isDark,
    IconData tabIcon,
    Color tabColor,
  ) {
    final emp = _getEmployee(card.employeeId, card);
    final cardBgColor = _getCardColor(card.cardType, isDark);
    final accentBorder = _getCardAccentBorder(card.cardType, isDark);
    final formattedNumber = _formatCardNumber(card.cardNumber, card.cardType);

    Color statusGlowColor = const Color(0xFF10B981);
    Color statusBg = isDark
        ? const Color(0xFF10B981).withValues(alpha: 0.22)
        : const Color(0xFF10B981).withValues(alpha: 0.12);
    Color statusTextColor = isDark ? Colors.white : const Color(0xFF047857);
    String statusText = 'VALID (${card.daysUntilExpiry}d)';
    bool isAlertPulse = false;

    if (card.isExpired) {
      statusGlowColor = const Color(0xFFEF4444);
      statusBg = isDark
          ? const Color(0xFFEF4444).withValues(alpha: 0.32)
          : const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusTextColor = isDark ? Colors.white : const Color(0xFFB91C1C);
      statusText = 'EXPIRED (${card.daysUntilExpiry.abs()}d ago)';
      isAlertPulse = true;
    } else if (card.isCritical) {
      statusGlowColor = const Color(0xFFEF4444);
      statusBg = isDark
          ? const Color(0xFFEF4444).withValues(alpha: 0.32)
          : const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusTextColor = isDark ? Colors.white : const Color(0xFFB91C1C);
      statusText = card.daysUntilExpiry == 0 ? 'EXPIRES TODAY' : '${card.daysUntilExpiry}D LEFT';
      isAlertPulse = true;
    } else if (card.isExpiringSoon) {
      statusGlowColor = const Color(0xFFF59E0B);
      statusBg = isDark
          ? const Color(0xFFF59E0B).withValues(alpha: 0.26)
          : const Color(0xFFF59E0B).withValues(alpha: 0.12);
      statusTextColor = isDark ? Colors.white : const Color(0xFFB45309);
      statusText = '${card.daysUntilExpiry} DAYS LEFT';
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlertPulse
              ? const Color(0xFFEF4444).withValues(alpha: 0.85)
              : accentBorder.withValues(alpha: 0.45),
          width: isAlertPulse ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isAlertPulse
                ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.35 : 0.2)
                : (isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.05)),
            blurRadius: isDark ? 10 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Top specular shine
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2.5,
                color: isAlertPulse ? const Color(0xFFEF4444) : accentBorder,
              ),
            ),



            // Card Body
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Header Row (EMV Chip + Contactless + Pass Pill)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          _buildEmvChip(),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.wifi_tethering_rounded,
                            size: 18,
                            color: isDark ? Colors.white60 : Colors.blueGrey.shade400,
                          ),
                          const Spacer(),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: accentBorder.withValues(alpha: isDark ? 0.4 : 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(tabIcon, size: 12, color: accentBorder),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      card.cardName.toUpperCase(),
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Employee Identity Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentBorder.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black38 : Colors.grey.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: EmployeeAvatar(
                              photoUrl: emp?.photoUrl ?? EmployeeDirectoryHelper.resolvePhoto(
                                employeeCode: emp?.employeeCode ?? card.employeeId,
                                fullName: _resolveEmployeeDisplayName(emp, card),
                                email: emp?.email,
                                id: card.employeeId,
                              ),
                              fullName: _resolveEmployeeDisplayName(emp, card),
                              radius: 19,
                              borderColor: accentBorder,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _resolveEmployeeDisplayName(emp, card),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    height: 1.2,
                                    letterSpacing: 0.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(emp?.employeeCode.isNotEmpty == true ? emp!.employeeCode : (card.employeeId.length <= 10 && !card.employeeId.contains('-') ? card.employeeId : 'EMP'))} • ${emp?.department ?? 'Operations'}',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 3. Monospaced Embossed Number with Click-to-Copy
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: card.cardNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied card number: ${card.cardNumber}'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  formattedNumber,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    letterSpacing: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: isDark ? Colors.white60 : Colors.blueGrey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 4. Expiry Date & Urgency Status Glow Banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VALID THRU',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dateFormat.format(card.expiryDate),
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: statusGlowColor.withValues(alpha: 0.65)),
                              boxShadow: [
                                BoxShadow(
                                  color: statusGlowColor.withValues(alpha: isDark ? 0.3 : 0.15),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusGlowColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusGlowColor,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusTextColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (card.notes != null && card.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Note: ${card.notes}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            fontSize: 10.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    // 5. Attached Document Indicator
                    if (card.documentUrl != null || card.fileName != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: InkWell(
                          onTap: card.documentUrl != null
                              ? () => _showDocumentPreviewDialog(card)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  card.fileName?.toLowerCase().endsWith('.pdf') == true
                                      ? Icons.picture_as_pdf_rounded
                                      : Icons.attach_file_rounded,
                                  size: 11,
                                  color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    card.fileName ?? 'Attached Document',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (card.documentUrl != null) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '• View',
                                    style: TextStyle(
                                      color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // 6. Actions Dock
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.03),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (card.documentUrl != null && card.documentUrl!.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.visibility_rounded,
                                size: 16,
                                color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                              ),
                              tooltip: 'Preview Document',
                              onPressed: () => _showDocumentPreviewDialog(card),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.download_rounded,
                              size: 16,
                              color: isDark ? Colors.white : const Color(0xFF475569),
                            ),
                            tooltip: 'Download Document / Pass',
                            onPressed: () => _downloadCardDocument(card),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBounceable(
                                onTap: () => _notifyWhatsApp(card),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat_rounded, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'WhatsApp',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              AppBounceable(
                                onTap: () => _notifyEmail(card),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.email_rounded, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Email',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                ),
                                tooltip: 'Edit Card',
                                onPressed: () => _showAddEditCardDialog(cardToEdit: card),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: isDark ? Colors.redAccent : const Color(0xFFDC2626),
                                ),
                                tooltip: 'Delete Card',
                                onPressed: () => _deleteCard(card),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsList(
    List<EmployeeCard> filtered,
    bool isDark,
    IconData tabIcon,
    Color tabColor,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final card = filtered[index];
        final emp = _getEmployee(card.employeeId, card);
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
                  EmployeeAvatar(
                    photoUrl: emp?.photoUrl ?? EmployeeDirectoryHelper.resolvePhoto(
                      employeeCode: emp?.employeeCode ?? card.employeeId,
                      fullName: _resolveEmployeeDisplayName(emp, card),
                      email: emp?.email,
                      id: card.employeeId,
                    ),
                    fullName: _resolveEmployeeDisplayName(emp, card),
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resolveEmployeeDisplayName(emp, card),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '${(emp?.employeeCode.isNotEmpty == true ? emp!.employeeCode : (card.employeeId.length <= 10 && !card.employeeId.contains('-') ? card.employeeId : 'EMP'))} • ${emp?.department ?? 'Operations'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
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
              if (card.fileName != null || card.documentUrl != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.blue.shade800.withValues(alpha: 0.3) : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        card.fileName?.toLowerCase().endsWith('.pdf') == true
                            ? Icons.picture_as_pdf_rounded
                            : Icons.attach_file_rounded,
                        size: 14,
                        color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          card.fileName ?? 'Uploaded Document',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (card.documentUrl != null && card.documentUrl!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showDocumentPreviewDialog(card),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_rounded,
                                  size: 13,
                                  color: isDark ? Colors.cyanAccent : Colors.teal.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'View',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.cyanAccent : Colors.teal.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      InkWell(
                        onTap: () => _downloadCardDocument(card),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download_rounded,
                                size: 13,
                                color: isDark ? Colors.amberAccent : Colors.amber.shade900,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Download',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.amberAccent : Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.primaryLight),
                    tooltip: 'Download Document / Card Pass',
                    onPressed: () => _downloadCardDocument(card),
                  ),
                  const SizedBox(width: 4),
                  if (card.documentUrl != null && card.documentUrl!.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.teal),
                      tooltip: 'View Uploaded Document',
                      onPressed: () => _showDocumentPreviewDialog(card),
                    ),
                    const SizedBox(width: 4),
                  ],
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
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    tooltip: 'Edit Document',
                    onPressed: () => _showAddEditCardDialog(cardToEdit: card),
                  ),
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
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
