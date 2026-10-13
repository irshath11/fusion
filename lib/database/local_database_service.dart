import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_enums.dart';
import '../core/services/supabase_service.dart';
import '../features/setup/domain/organization_setup.dart';
import '../features/auth/domain/user_entity.dart';
import '../features/admin/domain/employee_entity.dart';
import '../features/admin/domain/office_entity.dart';
import '../features/admin/domain/work_site_entity.dart';
import '../features/attendance/domain/attendance_record.dart';
import '../core/utils/employee_directory_helper.dart';
import '../features/reconciliation/domain/expense_bill_entity.dart';
import '../features/reconciliation/domain/statement_transaction_entity.dart';
import '../features/reconciliation/services/reconciliation_matching_service.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  final Uuid _uuid = const Uuid();

  bool _isSetupCompleted = false;
  OrganizationSetup? _organization;
  UserEntity? _currentUser;
  Box? _settingsBox;

  final List<UserEntity> _users = [];
  final List<EmployeeEntity> _employees = [];
  final List<OfficeEntity> _offices = [];
  final List<WorkSiteEntity> _workSites = [];
  final List<AttendanceRecord> _attendanceRecords = [];
  final List<ExpenseBillEntity> _expenseBills = [];
  final List<StatementTransactionEntity> _statementTransactions = [];

  // Initialize with Hive persistence & seed enterprise defaults
  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _settingsBox = await Hive.openBox('app_settings');

      _isSetupCompleted =
          _settingsBox?.get('is_setup_completed', defaultValue: false) ?? false;

      final orgJsonStr = _settingsBox?.get('organization_json');
      if (orgJsonStr != null && orgJsonStr.toString().isNotEmpty) {
        try {
          _organization = OrganizationSetup.fromJson(jsonDecode(orgJsonStr));
        } catch (_) {}
      }

      final savedUserJson = _settingsBox?.get('current_user_json');
      if (savedUserJson != null && savedUserJson.toString().isNotEmpty) {
        try {
          _currentUser = UserEntity.fromJson(jsonDecode(savedUserJson));
        } catch (_) {}
      }

      final savedUsersJson = _settingsBox?.get('users_json');
      if (savedUsersJson != null && savedUsersJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedUsersJson);
          _users.clear();
          for (final item in decoded) {
            _users.add(UserEntity.fromJson(item));
          }
        } catch (_) {}
      }

      final savedEmployeesJson = _settingsBox?.get('employees_json');
      if (savedEmployeesJson != null &&
          savedEmployeesJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedEmployeesJson);
          _employees.clear();
          for (final item in decoded) {
            final emp = EmployeeEntity.fromJson(item);
            int index = _employees.indexWhere((e) =>
                e.id == emp.id ||
                (e.email.isNotEmpty &&
                    emp.email.isNotEmpty &&
                    e.email.trim().toLowerCase() == emp.email.trim().toLowerCase()) ||
                (e.name.trim().toLowerCase() == emp.name.trim().toLowerCase() && emp.name.trim().isNotEmpty));
            if (index >= 0) {
              _employees[index] = emp;
            } else {
              _employees.add(emp);
            }
          }
        } catch (_) {}
      }

      final savedOfficesJson = _settingsBox?.get('offices_json');
      if (savedOfficesJson != null && savedOfficesJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedOfficesJson);
          _offices.clear();
          for (final item in decoded) {
            _offices.add(OfficeEntity.fromJson(item));
          }
        } catch (_) {}
      }

      final savedWorkSitesJson = _settingsBox?.get('worksites_json');
      if (savedWorkSitesJson != null &&
          savedWorkSitesJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedWorkSitesJson);
          _workSites.clear();
          for (final item in decoded) {
            _workSites.add(WorkSiteEntity.fromJson(item));
          }
        } catch (_) {}
      }

      if (kIsWeb) {
        clearAttendanceCache();
      } else {
        final savedAttendanceJson = _settingsBox?.get('attendance_records_json');
        if (savedAttendanceJson != null &&
            savedAttendanceJson.toString().isNotEmpty) {
          try {
            final List<dynamic> decoded = jsonDecode(savedAttendanceJson);
            _attendanceRecords.clear();
            for (final item in decoded) {
              _attendanceRecords.add(AttendanceRecord.fromJson(item));
            }
          } catch (_) {}
        }
      }

      // Load Reconciliation Expense Bills
      final savedBillsJson = _settingsBox?.get('expense_bills_json');
      if (savedBillsJson != null && savedBillsJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedBillsJson);
          _expenseBills.clear();
          for (final item in decoded) {
            _expenseBills.add(ExpenseBillEntity.fromJson(item));
          }
        } catch (_) {}
      }

      // Load Reconciliation Statement Transactions
      final savedStatementJson = _settingsBox?.get('statement_transactions_json');
      if (savedStatementJson != null && savedStatementJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedStatementJson);
          _statementTransactions.clear();
          for (final item in decoded) {
            _statementTransactions.add(StatementTransactionEntity.fromJson(item));
          }
        } catch (_) {}
      }

      // Check live setup status against Supabase table 'organizations'
      await checkSetupStatusFromSupabase();
    } catch (e) {
      debugPrint('Hive database initialization warning: $e');
    }

    // Purge any previously seeded sample data
    _employees.removeWhere((e) => e.id == 'emp-001' || e.id == 'emp-002');
    _workSites.removeWhere((w) => w.id == 'site-musaffah-001');
    _offices.removeWhere((o) => o.id == 'office-musaffah-m12-001' || o.id == 'office-main-001');
    _attendanceRecords.removeWhere((r) => r.id.startsWith('rec-001-') || r.id.startsWith('rec-002-'));

    // Automatically resolve any dangling check-ins older than 24 hours
    autoResolveExpiredCheckIns();

    // Sanitize phantom/duplicate employee records strictly for Anandh, Rafi, and Azharudeen
    sanitizeDuplicateEmployees();

    _persistOffices();
    _persistEmployees();
    _persistWorkSites();
    _persistAttendanceRecords();
  }

  // Setup Wizard Flag
  bool get isSetupCompleted => _isSetupCompleted;
  OrganizationSetup? get organization => _organization;

  Future<void> completeFirstTimeSetup(OrganizationSetup setup) async {
    _organization = setup;
    _isSetupCompleted = true;

    try {
      await _settingsBox?.put('is_setup_completed', true);
      await _settingsBox?.put('organization_json', jsonEncode(setup.toJson()));
    } catch (e) {
      debugPrint('Error persisting setup to Hive: $e');
    }
  }

  /// Queries Supabase live for organization setup status.
  Future<bool> checkSetupStatusFromSupabase() async {
    try {
      final exists = await SupabaseService().checkOrganizationExists();
      if (exists) {
        _isSetupCompleted = true;
        await _settingsBox?.put('is_setup_completed', true);
        return true;
      } else {
        // No organization found in Supabase (or table not created yet)
        if (_isSetupCompleted || _organization != null) {
          // Keep existing local setup status
          return true;
        }
        _isSetupCompleted = false;
        await _settingsBox?.put('is_setup_completed', false);
        return false;
      }
    } catch (e) {
      debugPrint('Supabase setup status check note: $e');
      return _isSetupCompleted;
    }
  }

  // Auth User
  UserEntity? get currentUser => _currentUser;
  void setCurrentUser(UserEntity user) {
    _currentUser = user;
    try {
      _settingsBox?.put('current_user_json', jsonEncode(user.toJson()));
    } catch (_) {}
  }

  void logout() {
    _currentUser = null;
    try {
      _settingsBox?.delete('current_user_json');
    } catch (_) {}
  }

  // Users CRUD
  List<UserEntity> getUsers() {
    final Map<String, UserEntity> uniqueMap = {};
    for (final u in _users) {
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: u.employeeCode,
        name: u.fullName,
        email: u.email,
        id: u.id,
      );
      final key = official != null
          ? official.employeeId.toUpperCase()
          : (u.email.trim().isNotEmpty
              ? u.email.trim().toLowerCase()
              : (u.fullName.trim().isNotEmpty ? u.fullName.trim().toLowerCase() : u.id));
      uniqueMap[key] = u;
    }
    for (final e in _employees) {
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: e.employeeCode,
        name: e.name,
        email: e.email,
        id: e.id,
      );
      final key = official != null
          ? official.employeeId.toUpperCase()
          : (e.email.trim().isNotEmpty
              ? e.email.trim().toLowerCase()
              : (e.name.trim().isNotEmpty ? e.name.trim().toLowerCase() : e.id));
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = UserEntity(
          id: e.id,
          firebaseUid: e.id,
          email: e.email,
          fullName: official != null ? official.fullName : e.name,
          phoneNumber: e.mobileNumber,
          employeeCode: official != null ? official.employeeId : e.employeeCode,
          designation: official != null ? official.designation : e.designation,
          department: official != null ? official.department : e.department,
          role: UserRole.employee,
          organizationId: _organization?.id ?? '00000000-0000-0000-0000-000000000001',
          isActive: e.isActive,
          useDefaultOffice: e.useDefaultOffice,
          assignedOfficeId: e.assignedOfficeId,
          assignedOfficeName: e.assignedOfficeName,
          photoUrl: official != null ? official.photoAsset : e.photoUrl,
        );
      } else {
        final existing = uniqueMap[key]!;
        uniqueMap[key] = existing.copyWith(
          fullName: official != null ? official.fullName : existing.fullName,
          employeeCode: official != null
              ? official.employeeId
              : ((existing.employeeCode != null && existing.employeeCode!.isNotEmpty && existing.employeeCode != 'EMP-000')
                  ? existing.employeeCode
                  : e.employeeCode),
          designation: official != null
              ? official.designation
              : ((existing.designation != null && existing.designation!.isNotEmpty)
                  ? existing.designation
                  : e.designation),
          department: official != null
              ? official.department
              : ((existing.department != null && existing.department!.isNotEmpty)
                  ? existing.department
                  : e.department),
          photoUrl: official != null ? official.photoAsset : (existing.photoUrl ?? e.photoUrl),
        );
      }
    }
    if (_currentUser != null) {
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: _currentUser!.employeeCode,
        name: _currentUser!.fullName,
        email: _currentUser!.email,
        id: _currentUser!.id,
      );
      final key = official != null
          ? official.employeeId.toUpperCase()
          : (_currentUser!.email.trim().isNotEmpty
              ? _currentUser!.email.trim().toLowerCase()
              : (_currentUser!.fullName.trim().isNotEmpty ? _currentUser!.fullName.trim().toLowerCase() : _currentUser!.id));
      if (!uniqueMap.containsKey(key) || _currentUser!.role == UserRole.superAdmin || _currentUser!.role == UserRole.admin) {
        uniqueMap[key] = _currentUser!;
      }
    }

    final result = uniqueMap.values.map((u) {
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: u.employeeCode,
        name: u.fullName,
        email: u.email,
        id: u.id,
      );
      if (official != null) {
        return u.copyWith(
          fullName: official.fullName,
          employeeCode: official.employeeId,
          photoUrl: (u.photoUrl != null && u.photoUrl!.isNotEmpty)
              ? u.photoUrl
              : official.photoAsset,
          designation: (u.designation != null && u.designation!.isNotEmpty && u.designation != 'Staff')
              ? u.designation
              : official.designation,
          department: (u.department != null && u.department!.isNotEmpty && u.department != 'Operations')
              ? u.department
              : official.department,
        );
      }
      return u;
    }).toList();

    result.sort((a, b) => a.fullName.trim().toLowerCase().compareTo(b.fullName.trim().toLowerCase()));
    return List.unmodifiable(result);
  }

  void saveUser(UserEntity user) {
    int index = _users.indexWhere((u) =>
        u.id == user.id ||
        (u.email.isNotEmpty &&
            user.email.isNotEmpty &&
            u.email.trim().toLowerCase() == user.email.trim().toLowerCase()));
    if (index >= 0) {
      _users[index] = user;
    } else {
      _users.add(user);
    }
    _persistUsers();
  }

  void setUsers(List<UserEntity> users) {
    _users.clear();
    _users.addAll(users);
    _persistUsers();
  }

  void saveUsers(List<UserEntity> users) {
    for (final user in users) {
      saveUser(user);
    }
  }

  void deleteUser(String idOrEmail) {
    final clean = idOrEmail.trim().toLowerCase();
    _users.removeWhere((u) =>
        u.id == idOrEmail ||
        u.id.toLowerCase() == clean ||
        (u.firebaseUid.isNotEmpty && u.firebaseUid.toLowerCase() == clean) ||
        (u.email.isNotEmpty && u.email.trim().toLowerCase() == clean) ||
        (clean.isNotEmpty && u.fullName.trim().toLowerCase() == clean));
    _persistUsers();
  }

  void _persistUsers() {
    try {
      final jsonList = _users.map((u) => u.toJson()).toList();
      _settingsBox?.put('users_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error persisting users to Hive: $e');
    }
  }

  // Offices CRUD
  List<OfficeEntity> getOffices() => List.unmodifiable(_offices);

  void setOffices(List<OfficeEntity> offices) {
    _offices.clear();
    _offices.addAll(offices);
    _persistOffices();
  }

  void saveOffice(OfficeEntity office) {
    int index = _offices.indexWhere((o) => o.id == office.id);
    if (index >= 0) {
      _offices[index] = office;
    } else {
      _offices.add(office);
    }
    _persistOffices();
  }

  void deleteOffice(String officeId) {
    _offices.removeWhere((o) => o.id == officeId);
    _persistOffices();
    bool employeesModified = false;
    for (int i = 0; i < _employees.length; i++) {
      if (_employees[i].assignedOfficeId == officeId) {
        _employees[i] = _employees[i].copyWith(
          useDefaultOffice: true,
          clearAssignedOffice: true,
        );
        employeesModified = true;
      }
    }
    if (employeesModified) {
      _persistEmployees();
    }
  }

  void _persistOffices() {
    try {
      final jsonList = _offices.map((o) => o.toJson()).toList();
      _settingsBox?.put('offices_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error persisting offices to Hive: $e');
    }
  }

  // Employees CRUD
  List<EmployeeEntity> getEmployees() {
    final Map<String, EmployeeEntity> uniqueMap = {};
    for (final e in _employees) {
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: e.employeeCode,
        name: e.name,
        email: e.email,
        id: e.id,
      );
      final String key = official != null
          ? official.employeeId.toUpperCase()
          : (e.email.trim().isNotEmpty
              ? e.email.trim().toLowerCase()
              : (e.name.trim().isNotEmpty ? e.name.trim().toLowerCase() : e.id));

      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = official != null
            ? e.copyWith(
                name: official.fullName,
                employeeCode: official.employeeId,
                photoUrl: official.photoAsset,
                designation: (e.designation.isNotEmpty && e.designation != 'Staff' && e.designation != 'Team Member')
                    ? e.designation
                    : official.designation,
                department: (e.department.isNotEmpty && e.department != 'Operations')
                    ? e.department
                    : official.department,
              )
            : e;
      } else {
        final existing = uniqueMap[key]!;
        uniqueMap[key] = EmployeeEntity(
          id: existing.id.length > e.id.length ? existing.id : e.id,
          employeeCode: official != null
              ? official.employeeId
              : (existing.employeeCode.startsWith('EMP-') && existing.employeeCode != 'EMP-000'
                  ? existing.employeeCode
                  : e.employeeCode),
          name: official != null
              ? official.fullName
              : (existing.name.isNotEmpty ? existing.name : e.name),
          mobileNumber: existing.mobileNumber.isNotEmpty ? existing.mobileNumber : e.mobileNumber,
          email: existing.email.isNotEmpty ? existing.email : e.email,
          designation: official != null
              ? official.designation
              : (existing.designation != 'Team Member' ? existing.designation : e.designation),
          department: official != null
              ? official.department
              : (existing.department != 'Operations' ? existing.department : e.department),
          useDefaultOffice: existing.useDefaultOffice,
          assignedOfficeId: existing.assignedOfficeId ?? e.assignedOfficeId,
          assignedOfficeName: existing.assignedOfficeName ?? e.assignedOfficeName,
          isActive: existing.isActive && e.isActive,
          photoUrl: official != null
              ? official.photoAsset
              : ((existing.photoUrl != null && existing.photoUrl!.trim().isNotEmpty)
                  ? existing.photoUrl
                  : e.photoUrl),
        );
      }
    }
    final list = uniqueMap.values.map((e) {
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: e.employeeCode,
        name: e.name,
        email: e.email,
        id: e.id,
      );
      if (official != null) {
        return e.copyWith(
          name: official.fullName,
          employeeCode: official.employeeId,
          photoUrl: (e.photoUrl != null && e.photoUrl!.trim().isNotEmpty)
              ? e.photoUrl
              : official.photoAsset,
          designation: (e.designation.isNotEmpty && e.designation != 'Staff' && e.designation != 'Team Member')
              ? e.designation
              : official.designation,
          department: (e.department.isNotEmpty && e.department != 'Operations')
              ? e.department
              : official.department,
        );
      }
      if (e.photoUrl == null || e.photoUrl!.trim().isEmpty) {
        final photo = EmployeeDirectoryHelper.resolvePhoto(
          employeeCode: e.employeeCode,
          fullName: e.name,
          email: e.email,
          id: e.id,
        );
        if (photo != null) {
          return e.copyWith(photoUrl: photo);
        }
      }
      return e;
    }).toList();
    list.sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
    return List.unmodifiable(list);
  }

  /// No-op: prevents injecting synthetic directory employees into local database
  void seedMasterEmployeeDirectory() {}

  void setEmployees(List<EmployeeEntity> employees) {
    _employees.clear();
    _employees.addAll(employees);
    _persistEmployees();
  }

  void saveEmployee(EmployeeEntity employee) {
    int index = _employees.indexWhere((e) =>
        e.id == employee.id ||
        (e.email.isNotEmpty &&
            employee.email.isNotEmpty &&
            e.email.trim().toLowerCase() == employee.email.trim().toLowerCase()) ||
        (e.name.trim().toLowerCase() == employee.name.trim().toLowerCase() && e.name.trim().isNotEmpty));
    if (index >= 0) {
      _employees[index] = employee;
    } else {
      _employees.add(employee);
    }
    _persistEmployees();
  }

  void deleteEmployee(String idOrEmail) {
    final clean = idOrEmail.trim().toLowerCase();
    _employees.removeWhere((e) =>
        e.id == idOrEmail ||
        e.id.toLowerCase() == clean ||
        e.employeeCode.toLowerCase() == clean ||
        (e.email.isNotEmpty && e.email.trim().toLowerCase() == clean) ||
        (clean.isNotEmpty && e.name.trim().toLowerCase() == clean));
    _persistEmployees();
  }

  void _persistEmployees() {
    try {
      final jsonList = _employees.map((e) => e.toJson()).toList();
      _settingsBox?.put('employees_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error persisting employees to Hive: $e');
    }
  }

  // Work Sites CRUD
  List<WorkSiteEntity> getWorkSites() => List.unmodifiable(_workSites);

  void setWorkSites(List<WorkSiteEntity> sites) {
    _workSites.clear();
    _workSites.addAll(sites);
    _persistWorkSites();
  }

  void saveWorkSite(WorkSiteEntity site) {
    int index = _workSites.indexWhere((s) => s.id == site.id);
    if (index >= 0) {
      _workSites[index] = site;
    } else {
      _workSites.add(site);
    }
    _persistWorkSites();
  }

  void deleteWorkSite(String id) {
    _workSites.removeWhere((s) => s.id == id);
    _persistWorkSites();
  }

  void _persistWorkSites() {
    try {
      final jsonList = _workSites.map((s) => s.toJson()).toList();
      _settingsBox?.put('worksites_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error persisting work sites to Hive: $e');
    }
  }

  // Attendance Records & Offline Sync
  List<AttendanceRecord> getAttendanceRecords() {
    return List.unmodifiable(_attendanceRecords);
  }

  void addAttendanceRecord(AttendanceRecord record) {
    _attendanceRecords.add(record);
    _persistAttendanceRecords();
  }

  void clearAttendanceCache() {
    _attendanceRecords.clear();
    _settingsBox?.delete('attendance_records_json');
  }

  void saveAttendanceRecord(AttendanceRecord record, {bool persist = true}) {
    int index = _attendanceRecords.indexWhere((r) => r.id == record.id);

    // Fallback matching by employeeId/name + workflowStep + eventTimestamp if IDs differ
    if (index < 0) {
      index = _attendanceRecords.indexWhere((r) {
        final empMatch = r.employeeId == record.employeeId ||
            (r.employeeName.trim().isNotEmpty &&
                record.employeeName.trim().isNotEmpty &&
                r.employeeName.trim().toLowerCase() ==
                    record.employeeName.trim().toLowerCase());
        final stepMatch = r.workflowStep == record.workflowStep;
        final timeMatch = r.eventTimestamp.isAtSameMomentAs(record.eventTimestamp) ||
            r.eventTimestamp.difference(record.eventTimestamp).inSeconds.abs() < 5;
        return empMatch && stepMatch && timeMatch;
      });
    }

    if (index >= 0) {
      final existing = _attendanceRecords[index];
      if (existing.isEdited && record.manualOvertimeHours == null && existing.manualOvertimeHours != null) {
        _attendanceRecords[index] = record.copyWith(
          manualOvertimeHours: existing.manualOvertimeHours,
          overrideManualOvertimeHours: true,
          remarks: (existing.remarks != null && existing.remarks!.isNotEmpty) ? existing.remarks : record.remarks,
          isEdited: true,
          editedBy: existing.editedBy,
        );
      } else {
        _attendanceRecords[index] = record;
      }
    } else {
      _attendanceRecords.add(record);
    }
    if (persist) {
      _persistAttendanceRecords();
    }
  }

  /// Batch saves or updates multiple attendance records, persisting to Hive only once.
  void saveAttendanceRecordsBatch(List<AttendanceRecord> records) {
    if (records.isEmpty) return;
    for (final record in records) {
      saveAttendanceRecord(record, persist: false);
    }
    _persistAttendanceRecords();
  }

  void updateAttendanceRecord(AttendanceRecord updatedRecord) {
    saveAttendanceRecord(updatedRecord);
  }

  void deleteAttendanceRecord(String id) {
    _attendanceRecords.removeWhere((r) => r.id == id);
    _persistAttendanceRecords();
  }

  /// Admin method to update or insert Check-In, Check-Out, and Overtime (OT) with Remarks for an employee on a given date.
  Future<bool> updateOrAddAdminAttendanceOverride({
    required String employeeId,
    required String employeeName,
    required DateTime date,
    required DateTime checkInTime,
    required DateTime checkOutTime,
    double? manualOvertimeHours,
    String? remarks,
    String? adminName,
    String? originalEmployeeId,
    String? originalEmployeeName,
  }) async {
    final localDate = date.toLocal();
    final dateStr =
        "${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}";

    final searchEmpId = (originalEmployeeId != null && originalEmployeeId.trim().isNotEmpty)
        ? originalEmployeeId.trim()
        : employeeId;
    final searchEmpName = (originalEmployeeName != null && originalEmployeeName.trim().isNotEmpty)
        ? originalEmployeeName.trim()
        : employeeName;

    // Filter existing records for this employee (or original employee) on this date
    final dayRecords = _attendanceRecords.where((r) {
      final isEmp = r.employeeId == searchEmpId ||
          r.employeeId == employeeId ||
          (r.employeeName.trim().isNotEmpty &&
              (r.employeeName.trim().toLowerCase() == searchEmpName.trim().toLowerCase() ||
               r.employeeName.trim().toLowerCase() == employeeName.trim().toLowerCase())) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: r.employeeId,
            recordEmployeeName: r.employeeName,
            employeeId: employeeId,
            employeeName: employeeName,
          );
      final localEv = r.eventTimestamp.toLocal();
      final rDateStr =
          "${localEv.year}-${localEv.month.toString().padLeft(2, '0')}-${localEv.day.toString().padLeft(2, '0')}";
      return isEmp && rDateStr == dateStr;
    }).toList();

    // If reassigning to another employee, update any other records on this date to the new employee identity
    final isReassigning = searchEmpId != employeeId ||
        (searchEmpName.isNotEmpty && searchEmpName.toLowerCase() != employeeName.toLowerCase());
    if (isReassigning) {
      for (final r in dayRecords) {
        if (r.employeeId != employeeId || r.employeeName != employeeName) {
          final reassigned = r.copyWith(
            employeeId: employeeId,
            employeeName: employeeName,
            isEdited: true,
            editedBy: adminName ?? 'Administrator',
            syncStatus: SyncStatus.pending,
          );
          updateAttendanceRecord(reassigned);
        }
      }
    }

    final List<AttendanceRecord> updatedOrCreated = [];

    // 1. Check-In Record
    int inIndex = dayRecords.indexWhere(
      (r) => r.workflowStep == WorkflowStep.officeCheckIn,
    );
    if (inIndex < 0) {
      inIndex = dayRecords.indexWhere(
        (r) => r.workflowStep == WorkflowStep.siteCheckIn,
      );
    }

    if (inIndex >= 0) {
      final orig = dayRecords[inIndex];
      final updated = orig.copyWith(
        employeeId: employeeId,
        employeeName: employeeName,
        eventTimestamp: checkInTime,
        manualOvertimeHours: manualOvertimeHours,
        overrideManualOvertimeHours: true,
        remarks: remarks,
        isEdited: true,
        editedBy: adminName,
        syncStatus: SyncStatus.pending,
      );
      updateAttendanceRecord(updated);
      updatedOrCreated.add(updated);
    } else {
      final newCheckIn = AttendanceRecord(
        id: _uuid.v4(),
        employeeId: employeeId,
        employeeName: employeeName,
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: checkInTime,
        latitude: 0.0,
        longitude: 0.0,
        gpsAccuracy: 5.0,
        address: 'Admin Manual Entry',
        deviceId: 'DEV-ADMIN-OVERRIDE',
        photoBase64: '',
        isGeofenceValid: true,
        siteName: 'Main Office',
        manualOvertimeHours: manualOvertimeHours,
        remarks: remarks,
        isEdited: true,
        editedBy: adminName,
        syncStatus: SyncStatus.pending,
      );
      addAttendanceRecord(newCheckIn);
      updatedOrCreated.add(newCheckIn);
    }

    // 2. Check-Out Record
    int outIndex = dayRecords.lastIndexWhere(
      (r) => r.workflowStep == WorkflowStep.officeCheckOut,
    );
    if (outIndex < 0) {
      outIndex = dayRecords.lastIndexWhere(
        (r) => r.workflowStep == WorkflowStep.siteCheckOut,
      );
    }

    if (outIndex >= 0) {
      final orig = dayRecords[outIndex];
      final updated = orig.copyWith(
        employeeId: employeeId,
        employeeName: employeeName,
        eventTimestamp: checkOutTime,
        manualOvertimeHours: manualOvertimeHours,
        overrideManualOvertimeHours: true,
        remarks: remarks,
        isEdited: true,
        editedBy: adminName,
        syncStatus: SyncStatus.pending,
      );
      updateAttendanceRecord(updated);
      updatedOrCreated.add(updated);
    } else {
      final newCheckOut = AttendanceRecord(
        id: _uuid.v4(),
        employeeId: employeeId,
        employeeName: employeeName,
        workflowStep: WorkflowStep.officeCheckOut,
        eventTimestamp: checkOutTime,
        latitude: 0.0,
        longitude: 0.0,
        gpsAccuracy: 5.0,
        address: 'Admin Manual Entry',
        deviceId: 'DEV-ADMIN-OVERRIDE',
        photoBase64: '',
        isGeofenceValid: true,
        siteName: 'Main Office',
        manualOvertimeHours: manualOvertimeHours,
        remarks: remarks,
        isEdited: true,
        editedBy: adminName,
        syncStatus: SyncStatus.pending,
      );
      addAttendanceRecord(newCheckOut);
      updatedOrCreated.add(newCheckOut);
    }

    // 3. Update all intermediate site/break logs for this date to maintain OT override & remarks consistency
    for (int i = 0; i < dayRecords.length; i++) {
      if (i != inIndex && i != outIndex) {
        final orig = dayRecords[i];
        final updated = orig.copyWith(
          employeeId: employeeId,
          employeeName: employeeName,
          manualOvertimeHours: manualOvertimeHours,
          overrideManualOvertimeHours: true,
          remarks: remarks,
          isEdited: true,
          editedBy: adminName,
          syncStatus: SyncStatus.pending,
        );
        updateAttendanceRecord(updated);
        updatedOrCreated.add(updated);
      }
    }

    _persistAttendanceRecords();

    // Trigger Cloud DB sync
    try {
      final cloudOk = await SupabaseService().saveAdminAttendanceOverride(records: updatedOrCreated);
      if (cloudOk) {
        for (final rec in updatedOrCreated) {
          updateAttendanceRecord(rec.copyWith(syncStatus: SyncStatus.synced));
        }
      }
      return cloudOk;
    } catch (e) {
      debugPrint('Cloud sync note during admin override: $e');
      return false;
    }
  }

  /// Reassigns attendance records from one employee to another (e.g. fixing logs captured on another account)
  Future<int> reassignEmployeeAttendanceRecords({
    required String fromEmployeeId,
    required String fromEmployeeName,
    required String toEmployeeId,
    required String toEmployeeName,
    DateTime? specificDate,
  }) async {
    final cleanFromId = fromEmployeeId.trim().toLowerCase();
    final cleanFromName = fromEmployeeName.trim().toLowerCase();
    int count = 0;
    final List<AttendanceRecord> updatedRecords = [];

    for (int i = 0; i < _attendanceRecords.length; i++) {
      final r = _attendanceRecords[i];
      final rId = r.employeeId.trim().toLowerCase();
      final rName = r.employeeName.trim().toLowerCase();

      final matchesFrom = (cleanFromId.isNotEmpty && rId == cleanFromId) ||
          (cleanFromName.isNotEmpty && rName == cleanFromName);

      if (!matchesFrom) continue;

      if (specificDate != null) {
        final rDate = r.eventTimestamp.toLocal();
        final sDate = specificDate.toLocal();
        if (rDate.year != sDate.year || rDate.month != sDate.month || rDate.day != sDate.day) {
          continue;
        }
      }

      final updated = r.copyWith(
        employeeId: toEmployeeId,
        employeeName: toEmployeeName,
        isEdited: true,
        editedBy: 'Admin (Reassigned)',
        syncStatus: SyncStatus.pending,
      );
      _attendanceRecords[i] = updated;
      updatedRecords.add(updated);
      count++;
    }

    if (count > 0) {
      _persistAttendanceRecords();
      try {
        await SupabaseService().saveAdminAttendanceOverride(records: updatedRecords);
      } catch (e) {
        debugPrint('Cloud sync note during reassign: $e');
      }
    }

    return count;
  }

  /// Merges previous short-name duplicate employee records into their official enterprise profile across all staff,
  /// and consolidates all historical attendance records under the employee's official full name and canonical ID.
  Future<int> sanitizeDuplicateEmployees() async {
    int migratedCount = 0;
    final List<AttendanceRecord> updatedRecords = [];

    // Map each OfficialEmployeeRecord to its target ID and target full name.
    final Map<String, ({String targetId, String targetName})> officialTargetMap = {};

    for (final official in EmployeeDirectoryHelper.masterDirectory) {
      // Find authentic user in _users
      final realUser = _users.where((u) {
        if (u.email.trim().isNotEmpty && u.email.trim().toLowerCase() == official.email.toLowerCase()) {
          return true;
        }
        if (u.employeeCode != null && u.employeeCode!.trim().isNotEmpty &&
            u.employeeCode!.trim().toUpperCase() == official.employeeId.toUpperCase()) {
          return true;
        }
        if (u.fullName.trim().toLowerCase() == official.fullName.toLowerCase()) {
          return true;
        }
        for (final alias in official.aliases) {
          final a = alias.toLowerCase();
          if (u.fullName.trim().toLowerCase() == a ||
              (u.employeeCode != null && u.employeeCode!.trim().toLowerCase() == a) ||
              u.id.toLowerCase() == a) {
            return true;
          }
        }
        return false;
      }).firstOrNull;

      // Find existing canonical employee in _employees
      final canonicalEmp = _employees.where((e) {
        if (e.email.trim().isNotEmpty && e.email.trim().toLowerCase() == official.email.toLowerCase()) {
          return true;
        }
        if (e.employeeCode.trim().toUpperCase() == official.employeeId.toUpperCase()) {
          return true;
        }
        if (e.name.trim().toLowerCase() == official.fullName.toLowerCase()) {
          return true;
        }
        for (final alias in official.aliases) {
          final a = alias.toLowerCase();
          if (e.name.trim().toLowerCase() == a ||
              e.employeeCode.trim().toLowerCase() == a ||
              e.id.toLowerCase() == a) {
            return true;
          }
        }
        return false;
      }).firstOrNull;

      final String targetId = (realUser != null && realUser.id.isNotEmpty && !realUser.id.startsWith('emp-'))
          ? realUser.id
          : (canonicalEmp != null && canonicalEmp.id.isNotEmpty && !canonicalEmp.id.startsWith('emp-')
              ? canonicalEmp.id
              : (realUser != null && realUser.id.isNotEmpty
                  ? realUser.id
                  : (canonicalEmp != null && canonicalEmp.id.isNotEmpty ? canonicalEmp.id : 'emp-${official.employeeId}')));
      final String targetName = official.fullName;

      officialTargetMap[official.employeeId] = (targetId: targetId, targetName: targetName);

      // Update realUser in _users if found (preserving authentic profile fullName)
      if (realUser != null) {
        final uIndex = _users.indexOf(realUser);
        if (uIndex >= 0) {
          _users[uIndex] = realUser.copyWith(
            employeeCode: official.employeeId,
            designation: (realUser.designation != null && realUser.designation!.isNotEmpty && realUser.designation != 'Staff')
                ? realUser.designation
                : official.designation,
            department: (realUser.department != null && realUser.department!.isNotEmpty && realUser.department != 'Operations')
                ? realUser.department
                : official.department,
            photoUrl: official.photoAsset,
          );
        }
      }
    }

    // Consolidate attendance records for all employees
    for (int i = 0; i < _attendanceRecords.length; i++) {
      final r = _attendanceRecords[i];
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: r.employeeId,
        name: r.employeeName,
        id: r.employeeId,
      );

      if (official != null) {
        // NOTE: We do not overwrite attendance records' employeeName with official.fullName.
        // Employees in the field run older APK versions whose local profile stores
        // short names (e.g. 'Saleem', 'Shabi'). Overwriting employeeName in the cloud/local DB
        // breaks their datewise timeline and timesheet calculation on existing APKs.
        // Consolidation for administrative views and PDF reports is handled dynamically
        // via EmployeeDirectoryHelper without mutating raw record names.
      } else {
        // Revert any records of OTHER employees that were mistakenly tagged with synthetic 'emp-' IDs
        if (r.employeeId.startsWith('emp-')) {
          final codePart = r.employeeId.replaceFirst('emp-', '').toUpperCase();
          final realUser = _users.where((u) =>
              u.id.isNotEmpty && !u.id.startsWith('emp-') &&
              (u.employeeCode?.toUpperCase() == codePart ||
               u.fullName.trim().toLowerCase() == r.employeeName.trim().toLowerCase())).firstOrNull;
          if (realUser != null && r.employeeId != realUser.id) {
            final updated = r.copyWith(
              employeeId: realUser.id,
              employeeName: realUser.fullName,
              isEdited: false,
              editedBy: null,
              syncStatus: SyncStatus.pending,
            );
            _attendanceRecords[i] = updated;
            updatedRecords.add(updated);
            migratedCount++;
          }
        }
      }
    }

    if (updatedRecords.isNotEmpty) {
      _persistAttendanceRecords();
      try {
        await SupabaseService().saveAdminAttendanceOverride(records: updatedRecords);
      } catch (e) {
        debugPrint('Cloud sync note during sanitizeDuplicateEmployees: $e');
      }
    }

    // Purge phantom and short-name duplicate employees from _employees
    final originalLen = _employees.length;
    _employees.removeWhere((e) {
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: e.employeeCode,
        name: e.name,
        email: e.email,
        id: e.id,
      );

      if (official != null) {
        final target = officialTargetMap[official.employeeId];
        if (target != null) {
          final isShortName = e.name.trim().toLowerCase() != target.targetName.toLowerCase();
          final isWrongId = e.id != target.targetId;
          final canonicalExistsInEmployees = _employees.any((other) =>
              other != e && (other.id == target.targetId || other.name.trim().toLowerCase() == target.targetName.toLowerCase()));
          final canonicalExistsInUsers = _users.any((u) =>
              u.id == target.targetId || u.fullName.trim().toLowerCase() == target.targetName.toLowerCase());

          if ((isShortName || isWrongId) && (canonicalExistsInEmployees || canonicalExistsInUsers)) {
            return true;
          }
        }
      }

      // Remove synthetic seeded employees with id 'emp-' that duplicate existing users or have no attendance records
      if (e.id.startsWith('emp-')) {
        final official = EmployeeDirectoryHelper.resolveOfficialRecord(
          code: e.employeeCode,
          name: e.name,
          id: e.id,
        );
        final isCanonicalTarget = official != null && officialTargetMap[official.employeeId]?.targetId == e.id;
        if (!isCanonicalTarget) {
          final duplicateUser = _users.any((u) =>
              u.id != e.id && (u.employeeCode?.toUpperCase() == e.employeeCode.toUpperCase() ||
                               u.fullName.trim().toLowerCase() == e.name.trim().toLowerCase()));
          final hasNoAttendance = !_attendanceRecords.any((rec) => rec.employeeId == e.id);
          if (duplicateUser || hasNoAttendance) {
            return true;
          }
        }
      }

      return false;
    });

    // Update remaining employees with official details
    for (int i = 0; i < _employees.length; i++) {
      final e = _employees[i];
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: e.employeeCode,
        name: e.name,
        email: e.email,
        id: e.id,
      );
      if (official != null) {
        _employees[i] = e.copyWith(
          name: official.fullName,
          employeeCode: official.employeeId,
          photoUrl: official.photoAsset,
          designation: (e.designation.isNotEmpty && e.designation != 'Staff' && e.designation != 'Team Member')
              ? e.designation
              : official.designation,
          department: (e.department.isNotEmpty && e.department != 'Operations')
              ? e.department
              : official.department,
        );
      }
    }

    if (_employees.length != originalLen) {
      _persistEmployees();
    }
    _persistUsers();

    return migratedCount;
  }

  /// Scans all attendance records for unclosed sessions (officeCheckIn with no subsequent officeCheckOut).
  /// If elapsed time crosses 24 hours from the check-in time:
  /// - Automatically creates and captures an officeCheckOut record after exactly 8 hours from check-in.
  /// - Completes only the 8.0 regular hours shift and checks out.
  /// - Saves locally in Hive and flags for cloud synchronization.
  int autoResolveExpiredCheckIns() {
    final now = DateTime.now();
    int resolvedCount = 0;

    // Group records by employeeId
    final Map<String, List<AttendanceRecord>> employeeRecordsMap = {};
    for (final record in _attendanceRecords) {
      employeeRecordsMap.putIfAbsent(record.employeeId, () => []).add(record);
    }

    final List<AttendanceRecord> newAutoCheckOuts = [];

    employeeRecordsMap.forEach((empId, records) {
      // Sort ascending by event timestamp
      records.sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

      for (int i = 0; i < records.length; i++) {
        final rec = records[i];
        if (rec.workflowStep == WorkflowStep.officeCheckIn) {
          final checkInTime = rec.eventTimestamp;
          final elapsed = now.difference(checkInTime);

          if (elapsed >= const Duration(hours: 24)) {
            // Check if there is an officeCheckOut occurring after this checkIn and before any subsequent officeCheckIn
            bool hasMatchingCheckOut = false;
            for (int j = i + 1; j < records.length; j++) {
              final nextRec = records[j];
              if (nextRec.workflowStep == WorkflowStep.officeCheckOut) {
                hasMatchingCheckOut = true;
                break;
              } else if (nextRec.workflowStep == WorkflowStep.officeCheckIn) {
                // Next checkIn session started
                break;
              }
            }

            if (!hasMatchingCheckOut) {
              // Auto-generate officeCheckOut after 8 hours from check-in time
              final autoCheckOutTime = checkInTime.add(const Duration(hours: 8));

              // Avoid duplicate if already exists with same timestamp
              final duplicateExists = records.any((r) =>
                  r.workflowStep == WorkflowStep.officeCheckOut &&
                  r.eventTimestamp.isAtSameMomentAs(autoCheckOutTime));

              if (!duplicateExists) {
                final autoRecord = AttendanceRecord(
                  id: _uuid.v4(),
                  employeeId: rec.employeeId,
                  employeeName: rec.employeeName,
                  workflowStep: WorkflowStep.officeCheckOut,
                  eventTimestamp: autoCheckOutTime,
                  latitude: rec.latitude,
                  longitude: rec.longitude,
                  gpsAccuracy: rec.gpsAccuracy,
                  address: 'Auto Check-Out (24h Exceeded - 8h Regular Shift Capped)',
                  deviceId: rec.deviceId.isNotEmpty ? rec.deviceId : 'device-auto-system',
                  photoBase64: '',
                  isGeofenceValid: true,
                  officeId: rec.officeId,
                  siteName: rec.siteName ?? 'Main Office',
                  syncStatus: SyncStatus.pending,
                );

                newAutoCheckOuts.add(autoRecord);
                resolvedCount++;
              }
            }
          }
        }
      }
    });

    if (newAutoCheckOuts.isNotEmpty) {
      _attendanceRecords.addAll(newAutoCheckOuts);
      _persistAttendanceRecords();
    }

    return resolvedCount;
  }

  /// Fetches attendance records for the active shift or current workday session for an employee.
  /// If the employee is currently in an unclosed shift (e.g., started at 2:00 PM yesterday and ongoing past midnight),
  /// all records belonging to this active shift session are returned so the workflow and timeline remain continuous.
  List<AttendanceRecord> getTodayAttendanceRecords([String? employeeId]) {
    autoResolveExpiredCheckIns();

    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);

    final targetId = employeeId?.trim() ?? _currentUser?.id ?? _currentUser?.firebaseUid;
    if (targetId == null || targetId.isEmpty) return [];

    final cleanTarget = targetId.toLowerCase();
    final empRecords = _attendanceRecords.where((r) {
      final matchesId = r.employeeId.trim().toLowerCase() == cleanTarget;
      final matchesName = r.employeeName.trim().toLowerCase() == cleanTarget;
      final matchesUser = _currentUser != null &&
          (r.employeeId == _currentUser!.id ||
              r.employeeId == _currentUser!.firebaseUid ||
              r.employeeName.trim().toLowerCase() ==
                  _currentUser!.fullName.trim().toLowerCase());
      final matchesIdentity = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: r.employeeId,
        recordEmployeeName: r.employeeName,
        employeeId: cleanTarget,
        employeeCode: _currentUser?.employeeCode,
        employeeName: _currentUser?.fullName,
        employeeEmail: _currentUser?.email,
      );
      return matchesId || matchesName || matchesUser || matchesIdentity;
    }).toList()
      ..sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    if (empRecords.isEmpty) return [];

    // 1. Check if there is an active unclosed regular shift (checkIn within last 24h with no subsequent officeCheckOut)
    AttendanceRecord? activeCheckIn;
    for (int i = empRecords.length - 1; i >= 0; i--) {
      final rec = empRecords[i];
      if (rec.workflowStep == WorkflowStep.officeCheckOut ||
          rec.workflowStep == WorkflowStep.emergencyCheckOut) {
        break;
      }
      if (rec.workflowStep == WorkflowStep.officeCheckIn ||
          rec.workflowStep == WorkflowStep.siteCheckIn ||
          rec.workflowStep == WorkflowStep.emergencyCheckIn) {
        final elapsed = now.difference(rec.eventTimestamp);
        if (elapsed < const Duration(hours: 24)) {
          activeCheckIn = rec;
        }
      }
    }

    if (activeCheckIn != null) {
      // Find the earliest start of this continuous open shift
      final startIndex = empRecords.indexOf(activeCheckIn);
      AttendanceRecord startRecord = activeCheckIn;
      for (int i = startIndex - 1; i >= 0; i--) {
        final prev = empRecords[i];
        if (prev.workflowStep == WorkflowStep.officeCheckOut ||
            prev.workflowStep == WorkflowStep.emergencyCheckOut) {
          break;
        }
        if (prev.workflowStep == WorkflowStep.officeCheckIn ||
            prev.workflowStep == WorkflowStep.siteCheckIn ||
            prev.workflowStep == WorkflowStep.emergencyCheckIn) {
          final elapsed = now.difference(prev.eventTimestamp);
          if (elapsed < const Duration(hours: 24)) {
            startRecord = prev;
          }
        }
      }
      return empRecords
          .where((r) => !r.eventTimestamp.isBefore(startRecord.eventTimestamp))
          .toList();
    }

    // 2. Check if an officeCheckIn occurred on today's calendar date
    final todayCheckIns = empRecords.where((r) {
      if (r.workflowStep != WorkflowStep.officeCheckIn &&
          r.workflowStep != WorkflowStep.siteCheckIn &&
          r.workflowStep != WorkflowStep.emergencyCheckIn) {
        return false;
      }
      final localEv = r.eventTimestamp.toLocal();
      final rDate = DateTime(localEv.year, localEv.month, localEv.day);
      return rDate.isAtSameMomentAs(today);
    }).toList();

    if (todayCheckIns.isNotEmpty) {
      final firstCheckIn = todayCheckIns.first;
      return empRecords
          .where((r) => !r.eventTimestamp.isBefore(firstCheckIn.eventTimestamp))
          .toList();
    }

    // 3. Check if an overnight shift concluded recently today (officeCheckOut on today's calendar date)
    final recentCheckOutToday = empRecords.where((r) {
      if (r.workflowStep != WorkflowStep.officeCheckOut &&
          r.workflowStep != WorkflowStep.emergencyCheckOut) {
        return false;
      }
      final localEv = r.eventTimestamp.toLocal();
      final rDate = DateTime(localEv.year, localEv.month, localEv.day);
      return rDate.isAtSameMomentAs(today);
    }).toList();

    if (recentCheckOutToday.isNotEmpty) {
      final lastOut = recentCheckOutToday.last;
      final matchingIn = empRecords.lastWhere(
        (r) =>
            (r.workflowStep == WorkflowStep.officeCheckIn ||
                r.workflowStep == WorkflowStep.siteCheckIn ||
                r.workflowStep == WorkflowStep.emergencyCheckIn) &&
            r.eventTimestamp.isBefore(lastOut.eventTimestamp),
        orElse: () => recentCheckOutToday.first,
      );

      final matchingInLocal = matchingIn.eventTimestamp.toLocal();
      final matchingInDate =
          DateTime(matchingInLocal.year, matchingInLocal.month, matchingInLocal.day);
      final isOvernightFromPrevDay = matchingInDate.isBefore(today);

      final elapsedSinceCheckout = now.difference(lastOut.eventTimestamp);
      if (!isOvernightFromPrevDay || elapsedSinceCheckout < const Duration(hours: 4)) {
        return empRecords
            .where((r) =>
                !r.eventTimestamp.isBefore(matchingIn.eventTimestamp) &&
                !r.eventTimestamp.isAfter(lastOut.eventTimestamp))
            .toList();
      }
    }

    // 4. Default: any records on today's calendar date
    return empRecords.where((r) {
      final localEv = r.eventTimestamp.toLocal();
      final rDate = DateTime(localEv.year, localEv.month, localEv.day);
      return rDate.isAtSameMomentAs(today);
    }).toList();
  }

  /// Checks if employee is currently checked into a site without having checked out
  bool isCurrentlyAtSite([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    if (todayRecords.isEmpty) return false;
    for (int i = todayRecords.length - 1; i >= 0; i--) {
      final step = todayRecords[i].workflowStep;
      if (step == WorkflowStep.siteCheckIn) return true;
      if (step == WorkflowStep.siteCheckOut || step == WorkflowStep.officeCheckOut) return false;
    }
    return false;
  }

  /// Dynamically computes current workflow step for a specific employee for today
  WorkflowStep getWorkflowStepForEmployee([String? employeeId]) {
    autoResolveExpiredCheckIns();

    if (isEmergencyDutyActiveToday(employeeId)) {
      return WorkflowStep.emergencyCheckOut;
    }

    final todayUserRecords = getTodayAttendanceRecords(employeeId);

    if (todayUserRecords.isEmpty) {
      return WorkflowStep.officeCheckIn;
    }

    if (todayUserRecords.any((r) => r.workflowStep == WorkflowStep.officeCheckOut)) {
      return WorkflowStep.completed;
    } else if (todayUserRecords.last.workflowStep == WorkflowStep.breakStart) {
      return WorkflowStep.breakEnd;
    } else if (isCurrentlyAtSite(employeeId)) {
      return WorkflowStep.siteCheckOut;
    } else {
      // Last record was officeCheckIn, siteCheckOut, or breakEnd: user can do siteCheckIn or officeCheckOut
      return WorkflowStep.siteCheckIn;
    }
  }

  /// Checks if the employee is currently on break
  bool isEmployeeOnBreakToday([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    if (todayRecords.isEmpty) return false;
    return todayRecords.last.workflowStep == WorkflowStep.breakStart;
  }

  /// Checks if employee currently has an active Emergency Duty check-in without check-out today
  bool isEmergencyDutyActiveToday([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    if (todayRecords.isEmpty) return false;
    for (int i = todayRecords.length - 1; i >= 0; i--) {
      final step = todayRecords[i].workflowStep;
      if (step == WorkflowStep.emergencyCheckIn) return true;
      if (step == WorkflowStep.emergencyCheckOut) return false;
    }
    return false;
  }

  /// Gets the active emergency duty check-in record for today (if on emergency duty)
  AttendanceRecord? getActiveEmergencyDutyRecordToday([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    if (todayRecords.isEmpty) return null;
    for (int i = todayRecords.length - 1; i >= 0; i--) {
      final step = todayRecords[i].workflowStep;
      if (step == WorkflowStep.emergencyCheckIn) return todayRecords[i];
      if (step == WorkflowStep.emergencyCheckOut) return null;
    }
    return null;
  }

  /// Gets the active break record for today (if on break)
  AttendanceRecord? getActiveBreakToday([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    if (todayRecords.isNotEmpty && todayRecords.last.workflowStep == WorkflowStep.breakStart) {
      return todayRecords.last;
    }
    return null;
  }

  /// Calculates total break duration taken today
  Duration getTodayBreakDuration([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    Duration totalBreak = Duration.zero;
    for (int i = 0; i < todayRecords.length; i++) {
      if (todayRecords[i].workflowStep == WorkflowStep.breakStart) {
        DateTime bStart = todayRecords[i].eventTimestamp;
        DateTime? bEnd;
        for (int j = i + 1; j < todayRecords.length; j++) {
          final nextStep = todayRecords[j].workflowStep;
          if (nextStep == WorkflowStep.breakEnd ||
              nextStep == WorkflowStep.officeCheckOut) {
            bEnd = todayRecords[j].eventTimestamp;
            break;
          }
        }
        bEnd ??= DateTime.now();
        if (bEnd.isAfter(bStart)) {
          totalBreak += bEnd.difference(bStart);
        }
      }
    }
    return totalBreak;
  }

  /// Checks if the employee has already completed at least one site check-in today
  bool isFirstSiteCheckInToday([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    return !todayRecords.any((r) => r.workflowStep == WorkflowStep.siteCheckIn);
  }

  /// Gets the site name of the currently active site check-in (if checked in)
  String? getActiveSiteNameToday([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    if (todayRecords.isEmpty) return null;
    for (int i = todayRecords.length - 1; i >= 0; i--) {
      final step = todayRecords[i].workflowStep;
      if (step == WorkflowStep.siteCheckIn) {
        return todayRecords[i].siteName ?? 'Current Site';
      }
      if (step == WorkflowStep.siteCheckOut || step == WorkflowStep.officeCheckOut) {
        return null;
      }
    }
    return null;
  }

  WorkflowStep get currentWorkflowStep => getWorkflowStepForEmployee();

  List<AttendanceRecord> getPendingSyncRecords([String? employeeId]) {
    autoResolveExpiredCheckIns();

    final targetId = employeeId ?? _currentUser?.id ?? _currentUser?.firebaseUid;
    return _attendanceRecords.where((r) {
      if (r.syncStatus != SyncStatus.pending) return false;
      if (targetId == null || targetId.isEmpty) return true;
      return r.employeeId == targetId ||
          (_currentUser != null &&
              (r.employeeId == _currentUser!.id ||
               r.employeeId == _currentUser!.firebaseUid ||
               r.employeeName.trim().toLowerCase() == _currentUser!.fullName.trim().toLowerCase()));
    }).toList();
  }

  List<AttendanceRecord> getAllPendingSyncRecords() {
    autoResolveExpiredCheckIns();

    return _attendanceRecords
        .where((r) => r.syncStatus == SyncStatus.pending)
        .toList();
  }

  void markRecordsSynced(List<String> recordIds) {
    for (int i = 0; i < _attendanceRecords.length; i++) {
      if (recordIds.contains(_attendanceRecords[i].id)) {
        _attendanceRecords[i] = _attendanceRecords[i].copyWith(
          syncStatus: SyncStatus.synced,
          syncTimestamp: DateTime.now(),
        );
      }
    }
    _persistAttendanceRecords();
  }

  void _persistAttendanceRecords() {
    try {
      final jsonList = _attendanceRecords.map((r) => r.toJson()).toList();
      _settingsBox?.put('attendance_records_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error persisting attendance records to Hive: $e');
    }
  }

  // Theme Persistence
  String getSavedThemePresetName() {
    return _settingsBox?.get('theme_preset', defaultValue: 'slateIndigo') ??
        'slateIndigo';
  }

  Future<void> saveThemePresetName(String presetName) async {
    try {
      await _settingsBox?.put('theme_preset', presetName);
    } catch (e) {
      debugPrint('Error saving theme preset to Hive: $e');
    }
  }

  String getSavedThemeModeName() {
    return _settingsBox?.get('theme_mode', defaultValue: 'system') ?? 'system';
  }

  Future<void> saveThemeModeName(String modeName) async {
    try {
      await _settingsBox?.put('theme_mode', modeName);
    } catch (e) {
      debugPrint('Error saving theme mode to Hive: $e');
    }
  }

  void clearLocalAttendanceRecords() {
    _attendanceRecords.clear();
    _persistAttendanceRecords();
  }

  // ==========================================================
  // OFFLINE SERVICE REPORTS MANAGEMENT & PREFIX SEQUENCING
  // ==========================================================

  /// Get employee prefix code (e.g. E01, E02...) for current logged-in employee
  String get currentEmployeePrefix {
    final user = _currentUser;
    if (user == null) return 'E01';
    final empNameOrId = user.fullName.isNotEmpty
        ? user.fullName
        : (user.name.isNotEmpty ? user.name : user.id);

    final idx = _employees.indexWhere((e) =>
        e.id == user.id ||
        (e.email.isNotEmpty &&
            user.email.isNotEmpty &&
            e.email.toLowerCase() == user.email.toLowerCase()) ||
        e.name.toLowerCase() == empNameOrId.toLowerCase());

    if (idx >= 0) {
      final numStr = (idx + 1).toString().padLeft(2, '0');
      return 'E$numStr';
    }

    final clean =
        empNameOrId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.length >= 2) {
      return 'E${clean.substring(0, 2)}';
    }
    return 'E01';
  }

  /// Fetch next sequence number starting at 2001 for given employee prefix,
  /// automatically scanning existing saved reports so sequence is strictly sequential (+1)!
  int getNextLocalServiceReportSeq(String prefix) {
    int maxSeq = 2000;

    // Scan all saved reports to find highest existing sequence for this prefix
    final reports = getAllSavedServiceReports(forceRefresh: true);
    final prefixPattern = 'SR-$prefix-';
    for (final item in reports) {
      final ref =
          (item['reportRefNumber'] ?? item['ref_number'] ?? '').toString();
      if (ref.startsWith(prefixPattern)) {
        final numPart = ref.substring(prefixPattern.length);
        final parsed = int.tryParse(numPart);
        if (parsed != null && parsed > maxSeq) {
          maxSeq = parsed;
        }
      }
    }

    return maxSeq + 1;
  }

  /// Increment and save local sequence number for given employee prefix
  Future<void> incrementLocalServiceReportSeq(String prefix) async {
    final current = getNextLocalServiceReportSeq(prefix);
    final key = 'sr_seq_$prefix';
    await _settingsBox?.put(key, current + 1);
  }

  /// Format full reference number (e.g. SR-E01-2001)
  String generateNextFullRefNumber() {
    final prefix = currentEmployeePrefix;
    final seq = getNextLocalServiceReportSeq(prefix);
    return 'SR-$prefix-$seq';
  }

  List<Map<String, dynamic>>? _cachedServiceReports;

  /// Save service report to local offline Hive storage
  Future<void> saveServiceReportLocally(Map<String, dynamic> reportData) async {
    try {
      final String jsonStr =
          _settingsBox?.get('pending_service_reports_json', defaultValue: '[]');
      final List decoded = jsonDecode(jsonStr);

      final String refNumber = reportData['reportRefNumber'] ?? '';

      final existingIdx =
          decoded.indexWhere((item) => item['reportRefNumber'] == refNumber);
      final payload = {
        'reportRefNumber': refNumber,
        'reportData': reportData,
        'syncStatus': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };

      if (existingIdx >= 0) {
        decoded[existingIdx] = payload;
      } else {
        decoded.add(payload);
        final prefix = currentEmployeePrefix;
        await incrementLocalServiceReportSeq(prefix);
      }

      await _settingsBox?.put(
          'pending_service_reports_json', jsonEncode(decoded));
      _cachedServiceReports = null; // Invalidate memory cache
      debugPrint(
          'Service report $refNumber saved locally to offline storage queue.');
    } catch (e) {
      debugPrint('Error saving service report locally: $e');
    }
  }

  /// Retrieve all pending offline service reports awaiting sync
  List<Map<String, dynamic>> getPendingLocalServiceReports() {
    try {
      final all = getAllSavedServiceReports();
      return all.where((item) => item['syncStatus'] == 'pending').toList();
    } catch (e) {
      return [];
    }
  }

  /// Mark local offline service report as synced to cloud Supabase
  Future<void> markServiceReportSynced(String refNumber) async {
    try {
      final String jsonStr =
          _settingsBox?.get('pending_service_reports_json', defaultValue: '[]');
      final List decoded = jsonDecode(jsonStr);

      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i]['reportRefNumber'] == refNumber) {
          decoded[i]['syncStatus'] = 'synced';
          decoded[i]['syncedAt'] = DateTime.now().toIso8601String();
        }
      }

      await _settingsBox?.put(
          'pending_service_reports_json', jsonEncode(decoded));
      _cachedServiceReports = null; // Invalidate memory cache
    } catch (e) {
      debugPrint('Error marking service report synced: $e');
    }
  }

  /// Retrieve all locally saved service reports (both synced and pending) with in-memory caching
  List<Map<String, dynamic>> getAllSavedServiceReports(
      {bool forceRefresh = false}) {
    if (!forceRefresh && _cachedServiceReports != null) {
      return List<Map<String, dynamic>>.from(_cachedServiceReports!);
    }

    try {
      final String jsonStr =
          _settingsBox?.get('pending_service_reports_json', defaultValue: '[]');
      final List decoded = jsonDecode(jsonStr);
      _cachedServiceReports =
          decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      return List<Map<String, dynamic>>.from(_cachedServiceReports!);
    } catch (e) {
      return [];
    }
  }

  /// Clear all locally cached service reports from local storage
  Future<void> clearServiceReportsCache() async {
    try {
      await _settingsBox?.delete('pending_service_reports_json');
      _cachedServiceReports = null; // Invalidate memory cache
      debugPrint('Service reports local cache cleared successfully.');
    } catch (e) {
      debugPrint('Error clearing service reports cache: $e');
    }
  }

  /// Merge cloud-synced service reports from Supabase into local storage
  Future<void> mergeCloudServiceReports(
      List<Map<String, dynamic>> cloudReports) async {
    try {
      final String jsonStr =
          _settingsBox?.get('pending_service_reports_json', defaultValue: '[]');
      final List decoded = jsonDecode(jsonStr);

      final Set<String> cloudRefNumbers = cloudReports
          .map(
              (c) => (c['reportRefNumber'] ?? c['ref_number'] ?? '').toString())
          .where((ref) => ref.isNotEmpty)
          .toSet();

      for (final cloud in cloudReports) {
        final String refNumber =
            (cloud['reportRefNumber'] ?? cloud['ref_number'] ?? '').toString();
        if (refNumber.isEmpty) continue;

        final idx =
            decoded.indexWhere((item) => item['reportRefNumber'] == refNumber);
        if (idx >= 0) {
          final localSync = decoded[idx]['syncStatus'];
          if (localSync != 'pending') {
            decoded[idx] = cloud;
          }
        } else {
          decoded.add(cloud);
        }
      }

      // Purge local reports that were marked as synced but are no longer in the cloud DB (e.g. deleted from cloud DB)
      decoded.removeWhere((item) {
        final String ref = (item['reportRefNumber'] ?? '').toString();
        final String status = (item['syncStatus'] ?? '').toString();
        if (status == 'synced' &&
            ref.isNotEmpty &&
            !cloudRefNumbers.contains(ref)) {
          return true;
        }
        return false;
      });

      await _settingsBox?.put(
          'pending_service_reports_json', jsonEncode(decoded));
      _cachedServiceReports = null; // Invalidate memory cache
    } catch (e) {
      debugPrint('Error merging cloud service reports: $e');
    }
  }

  /// Save generated attendance/analytics report metadata to local offline storage
  Future<void> saveGeneratedReportLocally(
      Map<String, dynamic> reportMeta) async {
    try {
      final String jsonStr = _settingsBox?.get('generated_reports_history_json',
          defaultValue: '[]');
      final List decoded = jsonDecode(jsonStr);

      final payload = {
        'id': reportMeta['id'] ?? _uuid.v4(),
        'title': reportMeta['title'] ?? 'Attendance Report',
        'type': reportMeta['type'] ?? 'PDF',
        'createdAt': DateTime.now().toIso8601String(),
        'recordCount': reportMeta['recordCount'] ?? 0,
        'filterDetails': reportMeta['filterDetails'] ?? '',
        'syncStatus': 'synced',
      };

      decoded.insert(0, payload);
      if (decoded.length > 50) decoded.removeLast();

      await _settingsBox?.put(
          'generated_reports_history_json', jsonEncode(decoded));
    } catch (e) {
      debugPrint('Error saving generated report locally: $e');
    }
  }

  List<Map<String, dynamic>>? _cachedWorkPhotoSubmissions;

  /// Save work site photos submission to local offline Hive storage
  Future<void> saveWorkPhotoSubmissionLocally(
      Map<String, dynamic> submissionData) async {
    try {
      final String jsonStr =
          _settingsBox?.get('work_photo_submissions_json', defaultValue: '[]');
      final List decoded = jsonDecode(jsonStr);

      final payload = {
        'id': submissionData['id'] ?? _uuid.v4(),
        'reportDate':
            submissionData['reportDate'] ?? DateTime.now().toIso8601String(),
        'workTitle': submissionData['workTitle'] ?? '',
        'location': submissionData['location'] ?? '',
        'employeeName': submissionData['employeeName'] ?? '',
        'remarks': submissionData['remarks'] ?? '',
        'photos': submissionData['photos'] ?? [],
        'syncStatus': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };

      decoded.insert(0, payload);
      await _settingsBox?.put(
          'work_photo_submissions_json', jsonEncode(decoded));
      _cachedWorkPhotoSubmissions = null; // Invalidate cache
      debugPrint(
          'Work photo submission saved locally with ${(payload['photos'] as List).length} image(s).');
    } catch (e) {
      debugPrint('Error saving work photo submission locally: $e');
    }
  }

  /// Get all saved work photo submissions (with in-memory caching for peak UI performance)
  List<Map<String, dynamic>> getSavedWorkPhotoSubmissions(
      {bool forceRefresh = false}) {
    if (!forceRefresh && _cachedWorkPhotoSubmissions != null) {
      return List<Map<String, dynamic>>.from(_cachedWorkPhotoSubmissions!);
    }

    try {
      final String jsonStr =
          _settingsBox?.get('work_photo_submissions_json', defaultValue: '[]');
      final List decoded = jsonDecode(jsonStr);
      _cachedWorkPhotoSubmissions =
          decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      return List<Map<String, dynamic>>.from(_cachedWorkPhotoSubmissions!);
    } catch (e) {
      return [];
    }
  }

  /// Get all pending work photo submissions that need cloud sync
  List<Map<String, dynamic>> getPendingWorkPhotoSubmissions() {
    try {
      final all = getSavedWorkPhotoSubmissions();
      return all
          .where((item) => (item['syncStatus'] ?? 'pending') == 'pending')
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Mark a work photo submission as synced to the cloud database
  Future<void> markWorkPhotoSubmissionSynced(String id,
      {List<String>? updatedPhotos}) async {
    try {
      final String jsonStr =
          _settingsBox?.get('work_photo_submissions_json', defaultValue: '[]');
      final List decoded = jsonDecode(jsonStr);

      bool updated = false;
      for (int i = 0; i < decoded.length; i++) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(decoded[i]);
        if (item['id'].toString() == id) {
          item['syncStatus'] = 'synced';
          item['syncedAt'] = DateTime.now().toIso8601String();
          if (updatedPhotos != null) {
            item['photos'] = updatedPhotos;
          }
          decoded[i] = item;
          updated = true;
          break;
        }
      }

      if (updated) {
        await _settingsBox?.put(
            'work_photo_submissions_json', jsonEncode(decoded));
        _cachedWorkPhotoSubmissions = null; // Invalidate cache
        debugPrint('Work photo submission #$id marked as synced.');
      }
    } catch (e) {
      debugPrint('Error marking work photo submission as synced: $e');
    }
  }

  /// Delete a saved work photo submission
  Future<void> deleteWorkPhotoSubmission(String id) async {
    try {
      final String jsonStr =
          _settingsBox?.get('work_photo_submissions_json', defaultValue: '[]');
      final List decoded = jsonDecode(jsonStr);

      decoded.removeWhere((item) => item['id']?.toString() == id);
      await _settingsBox?.put(
          'work_photo_submissions_json', jsonEncode(decoded));
      _cachedWorkPhotoSubmissions = null; // Invalidate cache
      debugPrint('Deleted work photo submission #$id.');
    } catch (e) {
      debugPrint('Error deleting work photo submission: $e');
    }
  }

  // ==========================================
  // RECONCILIATION & BILL MANAGEMENT
  // ==========================================

  List<ExpenseBillEntity> getExpenseBills() {
    return List.unmodifiable(_expenseBills);
  }

  Future<void> saveExpenseBill(ExpenseBillEntity bill) async {
    final idx = _expenseBills.indexWhere((b) => b.id == bill.id);
    if (idx >= 0) {
      _expenseBills[idx] = bill;
    } else {
      _expenseBills.add(bill);
    }
    await _persistExpenseBills();
  }

  Future<void> deleteExpenseBill(String id) async {
    final billIdx = _expenseBills.indexWhere((b) => b.id == id);
    if (billIdx >= 0) {
      final bill = _expenseBills[billIdx];
      // If it was matched with a statement transaction, unmatch the statement line
      if (bill.isMatched) {
        final txIdx = _statementTransactions.indexWhere((t) => t.id == bill.matchedStatementId);
        if (txIdx >= 0) {
          _statementTransactions[txIdx] = _statementTransactions[txIdx].copyWith(clearMatch: true);
          await _persistStatementTransactions();
        }
      }
      _expenseBills.removeAt(billIdx);
      await _persistExpenseBills();
    }
  }

  List<StatementTransactionEntity> getStatementTransactions({String? cycleMonth}) {
    if (cycleMonth != null && cycleMonth.isNotEmpty) {
      return _statementTransactions.where((t) => t.cycleMonth == cycleMonth).toList();
    }
    return List.unmodifiable(_statementTransactions);
  }

  Future<void> saveStatementTransactions(List<StatementTransactionEntity> items) async {
    for (final item in items) {
      final idx = _statementTransactions.indexWhere((t) => t.id == item.id);
      if (idx >= 0) {
        _statementTransactions[idx] = item;
      } else {
        _statementTransactions.add(item);
      }
    }
    await _persistStatementTransactions();
  }

  Future<void> deleteStatementTransaction(String id) async {
    final txIdx = _statementTransactions.indexWhere((t) => t.id == id);
    if (txIdx >= 0) {
      final tx = _statementTransactions[txIdx];
      // If it was matched with a bill, unmatch the bill
      if (tx.isMatched) {
        final billIdx = _expenseBills.indexWhere((b) => b.id == tx.matchedBillId);
        if (billIdx >= 0) {
          _expenseBills[billIdx] = _expenseBills[billIdx].copyWith(clearMatch: true);
          await _persistExpenseBills();
        }
      }
      _statementTransactions.removeAt(txIdx);
      await _persistStatementTransactions();
    }
  }

  Future<void> pairMatch(String statementId, String billId) async {
    final txIdx = _statementTransactions.indexWhere((t) => t.id == statementId);
    final billIdx = _expenseBills.indexWhere((b) => b.id == billId);

    if (txIdx >= 0 && billIdx >= 0) {
      _statementTransactions[txIdx] = _statementTransactions[txIdx].copyWith(
        matchedBillId: billId,
        matchConfidence: 1.0,
        matchNotes: 'Manually verified & matched by Admin',
      );
      _expenseBills[billIdx] = _expenseBills[billIdx].copyWith(
        matchedStatementId: statementId,
      );

      await _persistStatementTransactions();
      await _persistExpenseBills();
    }
  }

  Future<void> unpairMatch(String statementId) async {
    final txIdx = _statementTransactions.indexWhere((t) => t.id == statementId);
    if (txIdx >= 0) {
      final matchedBillId = _statementTransactions[txIdx].matchedBillId;
      _statementTransactions[txIdx] = _statementTransactions[txIdx].copyWith(clearMatch: true);

      if (matchedBillId != null) {
        final billIdx = _expenseBills.indexWhere((b) => b.id == matchedBillId);
        if (billIdx >= 0) {
          _expenseBills[billIdx] = _expenseBills[billIdx].copyWith(clearMatch: true);
        }
      }

      await _persistStatementTransactions();
      await _persistExpenseBills();
    }
  }

  Future<int> autoMatchCycle(String cycleMonth) async {
    final result = ReconciliationMatchingService.autoMatch(
      cycleMonth: cycleMonth,
      transactions: _statementTransactions,
      bills: _expenseBills,
    );

    _statementTransactions.clear();
    _statementTransactions.addAll(result.updatedTransactions);

    _expenseBills.clear();
    _expenseBills.addAll(result.updatedBills);

    await _persistStatementTransactions();
    await _persistExpenseBills();

    return result.newlyMatchedCount;
  }

  Future<void> clearCycleData(String cycleMonth) async {
    _statementTransactions.removeWhere((t) => t.cycleMonth == cycleMonth);
    _expenseBills.removeWhere((b) {
      final bMonth = '${b.billDate.year}-${b.billDate.month.toString().padLeft(2, '0')}';
      return bMonth == cycleMonth;
    });
    await _persistStatementTransactions();
    await _persistExpenseBills();
  }

  Future<void> seedReconciliationDemoData(String cycleMonth) async {
    final parts = cycleMonth.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;

    final empList = getEmployees();
    final emp1 = empList.isNotEmpty ? empList[0] : null;
    final emp2 = empList.length > 1 ? empList[1] : emp1;
    final emp3 = empList.length > 2 ? empList[2] : emp1;

    final emp1Id = emp1?.id ?? 'emp-101';
    final emp1Name = emp1?.name ?? 'Anandh Kumar';
    final emp2Id = emp2?.id ?? 'emp-102';
    final emp2Name = emp2?.name ?? 'Mohammed Rafi';
    final emp3Id = emp3?.id ?? 'emp-103';
    final emp3Name = emp3?.name ?? 'Azharudeen';

    final tx1Id = _uuid.v4();
    final tx2Id = _uuid.v4();
    final tx3Id = _uuid.v4();
    final tx4Id = _uuid.v4();

    final bill1Id = _uuid.v4();
    final bill2Id = _uuid.v4();
    final bill3Id = _uuid.v4();
    final bill4Id = _uuid.v4();

    // 4 realistic statement transactions
    final demoTransactions = [
      StatementTransactionEntity(
        id: tx1Id,
        cycleMonth: cycleMonth,
        transactionDate: DateTime(year, month, 4),
        description: 'AL FUTTAIM HARDWARE DUBAI',
        amount: 320.00,
        cardLast4: '4129',
        matchedBillId: bill1Id,
        matchConfidence: 1.0,
        matchNotes: 'Auto-matched: Exact amount and merchant',
        createdAt: DateTime.now(),
      ),
      StatementTransactionEntity(
        id: tx2Id,
        cycleMonth: cycleMonth,
        transactionDate: DateTime(year, month, 8),
        description: 'ACE HARDWARE ELECTRICAL CABLES',
        amount: 145.50,
        cardLast4: '4129',
        matchedBillId: bill2Id,
        matchConfidence: 1.0,
        matchNotes: 'Auto-matched: Exact amount and date',
        createdAt: DateTime.now(),
      ),
      StatementTransactionEntity(
        id: tx3Id,
        cycleMonth: cycleMonth,
        transactionDate: DateTime(year, month, 15),
        description: 'DANUBE BUILDING MATERIALS',
        amount: 580.00,
        cardLast4: '4129',
        matchedBillId: bill3Id,
        matchConfidence: 1.0,
        matchNotes: 'Auto-matched: Exact amount and vendor',
        createdAt: DateTime.now(),
      ),
      StatementTransactionEntity(
        id: tx4Id,
        cycleMonth: cycleMonth,
        transactionDate: DateTime(year, month, 22),
        description: 'DEWALT TOOLS & DRILL BITS',
        amount: 210.00,
        cardLast4: '4129',
        matchedBillId: null, // Discrepancy: Missing receipt!
        createdAt: DateTime.now(),
      ),
    ];

    // 4 employee bills
    final demoBills = [
      ExpenseBillEntity(
        id: bill1Id,
        employeeId: emp1Id,
        employeeName: emp1Name,
        vendorName: 'Al Futtaim Hardware',
        invoiceNumber: 'INV-4821',
        amount: 320.00,
        billDate: DateTime(year, month, 3),
        cardLast4: '4129',
        category: 'Material Purchase',
        materialDescription: 'PVC Pipes, Elbows & Fittings',
        matchedStatementId: tx1Id,
        createdAt: DateTime.now(),
      ),
      ExpenseBillEntity(
        id: bill2Id,
        employeeId: emp2Id,
        employeeName: emp2Name,
        vendorName: 'Ace Hardware',
        invoiceNumber: 'ACE-9011',
        amount: 145.50,
        billDate: DateTime(year, month, 7),
        cardLast4: '4129',
        category: 'Electricals',
        materialDescription: 'Industrial Cable rolls & terminal blocks',
        matchedStatementId: tx2Id,
        createdAt: DateTime.now(),
      ),
      ExpenseBillEntity(
        id: bill3Id,
        employeeId: emp3Id,
        employeeName: emp3Name,
        vendorName: 'Danube Building Materials',
        invoiceNumber: 'DAN-3142',
        amount: 580.00,
        billDate: DateTime(year, month, 14),
        cardLast4: '4129',
        category: 'Material Purchase',
        materialDescription: 'Drywall Sheets, Screws & Joint Compound',
        matchedStatementId: tx3Id,
        createdAt: DateTime.now(),
      ),
      // A pending bill that matches tx4 once verified or a separate one
      ExpenseBillEntity(
        id: bill4Id,
        employeeId: emp1Id,
        employeeName: emp1Name,
        vendorName: 'Speedy Hardware & Tools',
        invoiceNumber: 'SH-1029',
        amount: 210.00,
        billDate: DateTime(year, month, 21),
        cardLast4: '4129',
        category: 'Tools & Hardware',
        materialDescription: 'Masonry Drill bit set & angle grinder discs',
        matchedStatementId: null, // Unmatched so user can test 1-tap Auto Match or Manual Link to achieve ZERO BALANCE!
        createdAt: DateTime.now(),
      ),
    ];

    await clearCycleData(cycleMonth);
    await saveStatementTransactions(demoTransactions);
    for (final b in demoBills) {
      await saveExpenseBill(b);
    }
  }

  Future<void> _persistExpenseBills() async {
    try {
      final jsonList = _expenseBills.map((b) => b.toJson()).toList();
      await _settingsBox?.put('expense_bills_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving expense bills: $e');
    }
  }

  Future<void> _persistStatementTransactions() async {
    try {
      final jsonList = _statementTransactions.map((t) => t.toJson()).toList();
      await _settingsBox?.put('statement_transactions_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving statement transactions: $e');
    }
  }
}
