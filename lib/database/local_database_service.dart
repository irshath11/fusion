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
      final key = u.email.trim().isNotEmpty
          ? u.email.trim().toLowerCase()
          : (u.fullName.trim().isNotEmpty ? u.fullName.trim().toLowerCase() : u.id);
      uniqueMap[key] = u;
    }
    for (final e in _employees) {
      final key = e.email.trim().isNotEmpty
          ? e.email.trim().toLowerCase()
          : (e.name.trim().isNotEmpty ? e.name.trim().toLowerCase() : e.id);
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = UserEntity(
          id: e.id,
          firebaseUid: e.id,
          email: e.email,
          fullName: e.name,
          phoneNumber: e.mobileNumber,
          role: UserRole.employee,
          organizationId: _organization?.id ?? '00000000-0000-0000-0000-000000000001',
          isActive: e.isActive,
        );
      }
    }
    if (_currentUser != null) {
      final key = _currentUser!.email.trim().isNotEmpty
          ? _currentUser!.email.trim().toLowerCase()
          : (_currentUser!.fullName.trim().isNotEmpty ? _currentUser!.fullName.trim().toLowerCase() : _currentUser!.id);
      if (!uniqueMap.containsKey(key) || _currentUser!.role == UserRole.superAdmin || _currentUser!.role == UserRole.admin) {
        uniqueMap[key] = _currentUser!;
      }
    }
    return List.unmodifiable(uniqueMap.values.toList());
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
      final String key = e.email.trim().isNotEmpty
          ? e.email.trim().toLowerCase()
          : (e.name.trim().isNotEmpty ? e.name.trim().toLowerCase() : e.id);

      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = e;
      } else {
        final existing = uniqueMap[key]!;
        uniqueMap[key] = EmployeeEntity(
          id: existing.id.length > e.id.length ? existing.id : e.id,
          employeeCode: existing.employeeCode.startsWith('EMP-') && existing.employeeCode != 'EMP-000'
              ? existing.employeeCode
              : e.employeeCode,
          name: existing.name.isNotEmpty ? existing.name : e.name,
          mobileNumber: existing.mobileNumber.isNotEmpty ? existing.mobileNumber : e.mobileNumber,
          email: existing.email.isNotEmpty ? existing.email : e.email,
          designation: existing.designation != 'Team Member' ? existing.designation : e.designation,
          department: existing.department != 'Operations' ? existing.department : e.department,
          useDefaultOffice: existing.useDefaultOffice,
          assignedOfficeId: existing.assignedOfficeId ?? e.assignedOfficeId,
          assignedOfficeName: existing.assignedOfficeName ?? e.assignedOfficeName,
          isActive: existing.isActive && e.isActive,
        );
      }
    }
    final list = uniqueMap.values.toList();
    list.sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
    return List.unmodifiable(list);
  }

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

  void saveAttendanceRecord(AttendanceRecord record) {
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
    _persistAttendanceRecords();
  }

  void updateAttendanceRecord(AttendanceRecord updatedRecord) {
    saveAttendanceRecord(updatedRecord);
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
  }) async {
    final localDate = date.toLocal();
    final dateStr =
        "${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}";

    // Filter existing records for this employee on this date
    final dayRecords = _attendanceRecords.where((r) {
      final isEmp = r.employeeId == employeeId ||
          (r.employeeName.trim().isNotEmpty &&
              employeeName.trim().isNotEmpty &&
              r.employeeName.trim().toLowerCase() ==
                  employeeName.trim().toLowerCase());
      final localEv = r.eventTimestamp.toLocal();
      final rDateStr =
          "${localEv.year}-${localEv.month.toString().padLeft(2, '0')}-${localEv.day.toString().padLeft(2, '0')}";
      return isEmp && rDateStr == dateStr;
    }).toList();

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

  /// Fetches today's attendance records for a specific employee
  List<AttendanceRecord> getTodayAttendanceRecords([String? employeeId]) {
    autoResolveExpiredCheckIns();

    final targetId = employeeId ?? _currentUser?.id ?? _currentUser?.firebaseUid;
    if (targetId == null || targetId.isEmpty) return [];

    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);

    return _attendanceRecords.where((r) {
      final matchesUser = (r.employeeId == targetId ||
          (_currentUser != null &&
              (r.employeeId == _currentUser!.id ||
               r.employeeId == _currentUser!.firebaseUid ||
               r.employeeName.trim().toLowerCase() == _currentUser!.fullName.trim().toLowerCase())));
      final localEv = r.eventTimestamp.toLocal();
      final rDate = DateTime(localEv.year, localEv.month, localEv.day);
      return matchesUser && rDate.isAtSameMomentAs(today);
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

    final todayUserRecords = getTodayAttendanceRecords(employeeId);

    if (todayUserRecords.isEmpty) {
      return WorkflowStep.officeCheckIn;
    }

    final lastRecord = todayUserRecords.last;
    if (lastRecord.workflowStep == WorkflowStep.officeCheckOut) {
      return WorkflowStep.completed;
    } else if (lastRecord.workflowStep == WorkflowStep.breakStart) {
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
}
