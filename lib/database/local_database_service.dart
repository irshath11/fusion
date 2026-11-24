import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_enums.dart';
import '../core/services/supabase_service.dart';
import '../features/setup/domain/organization_setup.dart';
import '../features/auth/domain/user_entity.dart';
import '../features/admin/domain/employee_entity.dart';
import '../features/admin/domain/office_entity.dart';
import '../features/admin/domain/work_site_entity.dart';
import '../features/attendance/domain/attendance_record.dart';
import '../features/salary/domain/employee_salary_config.dart';
import '../features/salary/data/default_salary_data.dart';
import '../core/utils/employee_directory_helper.dart';

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

  final Map<String, bool> _geofenceBypassOverrides = {};
  final List<UserEntity> _users = [];
  final List<EmployeeEntity> _employees = [];
  final List<OfficeEntity> _offices = [];
  final List<WorkSiteEntity> _workSites = [];
  final List<AttendanceRecord> _attendanceRecords = [];
  final List<EmployeeSalaryConfig> _employeeSalaries = [];

  // Initialize with Hive persistence & seed enterprise defaults
  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _settingsBox = await Hive.openBox('app_settings');

      _isSetupCompleted =
          _settingsBox?.get('is_setup_completed', defaultValue: false) ?? false;

      final savedGeofenceJson = _settingsBox?.get('geofence_bypass_overrides');
      if (savedGeofenceJson != null && savedGeofenceJson.toString().isNotEmpty) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(savedGeofenceJson);
          _geofenceBypassOverrides.clear();
          decoded.forEach((key, val) {
            if (val is bool) _geofenceBypassOverrides[key.toLowerCase()] = val;
          });
        } catch (_) {}
      }

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

      final savedSalariesJson = _settingsBox?.get('salaries_json');
      if (savedSalariesJson != null && savedSalariesJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedSalariesJson);
          _employeeSalaries.clear();
          for (final item in decoded) {
            final cfg = EmployeeSalaryConfig.fromJson(item);
            if (!_isExcludedSalaryOwner(cfg.employeeName, cfg.employeeCode)) {
              _employeeSalaries.add(cfg);
            }
          }
        } catch (_) {}
      }
      if (_employeeSalaries.isEmpty) {
        _employeeSalaries.addAll(DefaultSalaryData.defaultConfigs);
        _persistEmployeeSalaries();
      } else {
        _employeeSalaries.removeWhere((s) => _isExcludedSalaryOwner(s.employeeName, s.employeeCode));
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

    // Purge relieved personnel (e.g. Asik Saheel) completely from local database
    _employees.removeWhere((e) => EmployeeDirectoryHelper.isRelievedEmployee(
      id: e.id, name: e.name, email: e.email, code: e.employeeCode,
    ));
    _users.removeWhere((u) => EmployeeDirectoryHelper.isRelievedEmployee(
      id: u.id, name: u.fullName, email: u.email, code: u.employeeCode,
    ));
    _employeeSalaries.removeWhere((s) => EmployeeDirectoryHelper.isRelievedEmployee(
      name: s.employeeName, code: s.employeeCode,
    ));
    _attendanceRecords.removeWhere((r) => EmployeeDirectoryHelper.isRelievedEmployee(
      id: r.employeeId, name: r.employeeName,
    ));

    // Automatically resolve any dangling check-ins older than 24 hours
    autoResolveExpiredCheckIns();

    // Sanitize phantom/duplicate employee records strictly for Anandh, Rafi, and Azharudeen
    sanitizeDuplicateEmployees();

    _persistOffices();
    _persistEmployees();
    _persistUsers();
    _persistWorkSites();
    _persistAttendanceRecords();
    _persistEmployeeSalaries();
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
  UserEntity? get currentUser {
    if (_currentUser == null) return null;
    final u = _currentUser!;

    // 1. Check for any explicit local geofence bypass override
    final override = getGeofenceOverride(
      userId: u.id,
      email: u.email,
      employeeCode: u.employeeCode,
      name: u.fullName,
    );

    // 2. Look up matching user in _users
    UserEntity? matchedUser;
    final uId = u.id.trim().toLowerCase();
    final uFb = u.firebaseUid.trim().toLowerCase();
    final uEmail = u.email.trim().toLowerCase();
    final uCode = (u.employeeCode ?? '').trim().toLowerCase();
    for (final usr in _users) {
      final usrId = usr.id.trim().toLowerCase();
      final usrFb = usr.firebaseUid.trim().toLowerCase();
      final usrEmail = usr.email.trim().toLowerCase();
      final usrCode = (usr.employeeCode ?? '').trim().toLowerCase();
      if (usrId == uId ||
          (usrFb.isNotEmpty && (usrFb == uFb || usrFb == uId)) ||
          (usrEmail.isNotEmpty && uEmail.isNotEmpty && usrEmail == uEmail) ||
          (usrCode.isNotEmpty && uCode.isNotEmpty && usrCode == uCode)) {
        matchedUser = usr;
        break;
      }
    }

    // 3. Look up matching employee in _employees
    EmployeeEntity? matchedEmp;
    for (final emp in _employees) {
      final empId = emp.id.trim().toLowerCase();
      final empEmail = emp.email.trim().toLowerCase();
      final empCode = emp.employeeCode.trim().toLowerCase();
      if (empId == uId ||
          (empEmail.isNotEmpty && uEmail.isNotEmpty && empEmail == uEmail) ||
          (empCode.isNotEmpty && uCode.isNotEmpty && empCode == uCode) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: emp.id,
            recordEmployeeName: emp.name,
            employeeId: u.id,
            employeeCode: u.employeeCode,
            employeeName: u.fullName,
            employeeEmail: u.email,
          )) {
        matchedEmp = emp;
        break;
      }
    }

    final effectiveBypass = override ??
        (matchedEmp != null
            ? matchedEmp.bypassGeofence
            : (matchedUser?.bypassGeofence ?? u.bypassGeofence));

    return u.copyWith(
      fullName: (matchedUser != null && matchedUser.fullName.trim().isNotEmpty)
          ? matchedUser.fullName.trim()
          : (matchedEmp != null && matchedEmp.name.trim().isNotEmpty ? matchedEmp.name.trim() : u.fullName),
      email: (matchedUser != null && matchedUser.email.trim().isNotEmpty)
          ? matchedUser.email.trim()
          : (matchedEmp != null && matchedEmp.email.trim().isNotEmpty ? matchedEmp.email.trim() : u.email),
      phoneNumber: matchedUser?.phoneNumber ?? matchedEmp?.mobileNumber ?? u.phoneNumber,
      employeeCode: (matchedEmp != null && matchedEmp.employeeCode.trim().isNotEmpty && matchedEmp.employeeCode != 'EMP-000')
          ? matchedEmp.employeeCode.trim()
          : (matchedUser?.employeeCode ?? u.employeeCode),
      designation: (matchedEmp != null && matchedEmp.designation.trim().isNotEmpty && matchedEmp.designation != 'Staff')
          ? matchedEmp.designation.trim()
          : (matchedUser?.designation ?? u.designation),
      department: (matchedEmp != null && matchedEmp.department.trim().isNotEmpty && matchedEmp.department != 'General')
          ? matchedEmp.department.trim()
          : (matchedUser?.department ?? u.department),
      role: matchedUser?.role ?? u.role,
      useDefaultOffice: matchedEmp?.useDefaultOffice ?? matchedUser?.useDefaultOffice ?? u.useDefaultOffice,
      assignedOfficeId: matchedEmp?.assignedOfficeId ?? matchedUser?.assignedOfficeId ?? u.assignedOfficeId,
      assignedOfficeName: matchedEmp?.assignedOfficeName ?? matchedUser?.assignedOfficeName ?? u.assignedOfficeName,
      isActive: matchedEmp?.isActive ?? matchedUser?.isActive ?? u.isActive,
      bypassGeofence: effectiveBypass,
    );
  }

  void refreshCurrentUser() {
    final resolved = currentUser;
    if (resolved != null) {
      _currentUser = resolved;
      try {
        _settingsBox?.put('current_user_json', jsonEncode(resolved.toJson()));
      } catch (_) {}
    }
  }

  void setCurrentUser(UserEntity user) {
    _currentUser = user;
    try {
      _settingsBox?.put('current_user_json', jsonEncode(user.toJson()));
    } catch (_) {}
  }

  void saveCurrentUser(UserEntity user) => setCurrentUser(user);

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
          bypassGeofence: getGeofenceOverride(userId: e.id, email: e.email, employeeCode: e.employeeCode, name: e.name) ?? e.bypassGeofence,
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
          bypassGeofence: getGeofenceOverride(userId: e.id, email: e.email, employeeCode: e.employeeCode, name: e.name) ?? (existing.bypassGeofence || e.bypassGeofence),
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

    final filtered = result.where((u) => !EmployeeDirectoryHelper.isRelievedEmployee(
      id: u.id, name: u.fullName, email: u.email, code: u.employeeCode,
    )).toList();
    filtered.sort((a, b) => a.fullName.trim().toLowerCase().compareTo(b.fullName.trim().toLowerCase()));
    return List.unmodifiable(filtered);
  }

  void saveUser(UserEntity user) {
    if (EmployeeDirectoryHelper.isRelievedEmployee(
      id: user.id, name: user.fullName, email: user.email, code: user.employeeCode,
    )) {
      deleteUser(user.id);
      return;
    }
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

    if (_currentUser != null) {
      final cur = _currentUser!;
      if (cur.id == user.id ||
          (cur.firebaseUid.isNotEmpty && cur.firebaseUid == user.firebaseUid) ||
          (cur.email.isNotEmpty && user.email.isNotEmpty && cur.email.trim().toLowerCase() == user.email.trim().toLowerCase()) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: user.id,
            recordEmployeeName: user.fullName,
            employeeId: cur.id,
            employeeCode: cur.employeeCode,
            employeeName: cur.fullName,
            employeeEmail: cur.email,
          )) {
        refreshCurrentUser();
      }
    }
  }

  void setUsers(List<UserEntity> users) {
    _users.clear();
    for (final u in users) {
      if (EmployeeDirectoryHelper.isRelievedEmployee(
        id: u.id, name: u.fullName, email: u.email, code: u.employeeCode,
      )) {
        continue;
      }
      final override = getGeofenceOverride(
        userId: u.id,
        email: u.email,
        employeeCode: u.employeeCode,
        name: u.fullName,
      );
      if (override != null) {
        _users.add(u.copyWith(bypassGeofence: override));
      } else {
        _users.add(u);
      }
    }
    _persistUsers();
    refreshCurrentUser();
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
          bypassGeofence: getGeofenceOverride(userId: e.id, email: e.email, employeeCode: e.employeeCode, name: e.name) ?? (existing.bypassGeofence || e.bypassGeofence),
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
    final filtered = list.where((e) => !EmployeeDirectoryHelper.isRelievedEmployee(
      id: e.id, name: e.name, email: e.email, code: e.employeeCode,
    )).toList();
    filtered.sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
    return List.unmodifiable(filtered);
  }

  /// No-op: prevents injecting synthetic directory employees into local database
  void seedMasterEmployeeDirectory() {}

  void setEmployees(List<EmployeeEntity> employees) {
    _employees.clear();
    for (final e in employees) {
      if (EmployeeDirectoryHelper.isRelievedEmployee(
        id: e.id, name: e.name, email: e.email, code: e.employeeCode,
      )) {
        continue;
      }
      final override = getGeofenceOverride(
        userId: e.id,
        email: e.email,
        employeeCode: e.employeeCode,
        name: e.name,
      );
      if (override != null) {
        _employees.add(e.copyWith(bypassGeofence: override));
      } else {
        _employees.add(e);
      }
    }
    _persistEmployees();
    refreshCurrentUser();
  }

  void saveEmployee(EmployeeEntity employee) {
    if (EmployeeDirectoryHelper.isRelievedEmployee(
      id: employee.id, name: employee.name, email: employee.email, code: employee.employeeCode,
    )) {
      deleteEmployee(employee.id);
      return;
    }
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

    // Also sync matching user in _users so employee location and details immediately update
    for (int i = 0; i < _users.length; i++) {
      final u = _users[i];
      if (u.id == employee.id ||
          (u.email.isNotEmpty && employee.email.isNotEmpty && u.email.trim().toLowerCase() == employee.email.trim().toLowerCase()) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: employee.id,
            recordEmployeeName: employee.name,
            employeeId: u.id,
            employeeCode: u.employeeCode,
            employeeName: u.fullName,
            employeeEmail: u.email,
          )) {
        _users[i] = u.copyWith(
          employeeCode: employee.employeeCode,
          designation: employee.designation,
          department: employee.department,
          phoneNumber: employee.mobileNumber,
          useDefaultOffice: employee.useDefaultOffice,
          clearAssignedOffice:
              employee.useDefaultOffice || employee.assignedOfficeId == null,
          assignedOfficeId: employee.assignedOfficeId,
          assignedOfficeName: employee.assignedOfficeName,
          bypassGeofence: employee.bypassGeofence,
        );
      }
    }
    _persistUsers();

    if (_currentUser != null) {
      final cur = _currentUser!;
      if (cur.id == employee.id ||
          (cur.email.isNotEmpty && employee.email.isNotEmpty && cur.email.trim().toLowerCase() == employee.email.trim().toLowerCase()) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: employee.id,
            recordEmployeeName: employee.name,
            employeeId: cur.id,
            employeeCode: cur.employeeCode,
            employeeName: cur.fullName,
            employeeEmail: cur.email,
          )) {
        refreshCurrentUser();
      }
    }
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

  void _persistEmployeeSalaries() {
    _settingsBox?.put(
      'salaries_json',
      jsonEncode(_employeeSalaries.map((s) => s.toJson()).toList()),
    );
  }

  bool _isExcludedSalaryOwner(String name, String code) {
    if (EmployeeDirectoryHelper.isRelievedEmployee(name: name, code: code)) return true;
    final n = name.trim().toLowerCase();
    final c = code.trim().toLowerCase();
    if (c == '1058' || c == 'emp-1058') return false;
    if (n.contains('alnaser') || n.contains('al naser') || n.contains('al-naser') || n == 'naser') return false;
    if (n.contains('nasurudeen') ||
        n.contains('nasrudeen') ||
        n.contains('nasruddin') ||
        n.contains('nasirudeen')) {
      return true;
    }
    if (n.contains('siraj') || n.contains('sirajudeen') || n.contains('sirajuddin')) {
      return true;
    }
    return false;
  }

  /// Returns all stored salary configurations, guaranteed to include master defaults
  List<EmployeeSalaryConfig> getEmployeeSalaries() {
    if (_employeeSalaries.isEmpty) {
      _employeeSalaries.addAll(DefaultSalaryData.defaultConfigs);
      _persistEmployeeSalaries();
    }
    // Ensure all master default configs (including Alnaser Samsudeen 1058) are present
    bool addedAny = false;
    for (final def in DefaultSalaryData.defaultConfigs) {
      final exists = _employeeSalaries.any((s) =>
          (s.employeeCode.isNotEmpty && s.employeeCode.toUpperCase() == def.employeeCode.toUpperCase()) ||
          s.employeeName.trim().toLowerCase() == def.employeeName.trim().toLowerCase());
      if (!exists && !_isExcludedSalaryOwner(def.employeeName, def.employeeCode)) {
        _employeeSalaries.add(def);
        addedAny = true;
      }
    }
    _employeeSalaries.removeWhere((s) => _isExcludedSalaryOwner(s.employeeName, s.employeeCode));
    if (addedAny) {
      _persistEmployeeSalaries();
    }
    return List.unmodifiable(_employeeSalaries);
  }

  /// Returns a map for rapid O(1) salary configuration resolution
  Map<String, EmployeeSalaryConfig> getEmployeeSalaryMap() {
    final list = getEmployeeSalaries();
    final Map<String, EmployeeSalaryConfig> map = {};
    for (final s in list) {
      if (s.employeeCode.isNotEmpty) {
        map[s.employeeCode.toUpperCase()] = s;
        map[s.employeeCode] = s;
      }
      if (s.employeeId != null && s.employeeId!.isNotEmpty) {
        map[s.employeeId!] = s;
      }
      if (s.employeeName.isNotEmpty) {
        map[s.employeeName.toLowerCase().trim()] = s;
      }
    }
    return map;
  }

  /// Resolves the exact salary configuration for an employee by code, id, or name
  EmployeeSalaryConfig? getEmployeeSalary({
    String? employeeCode,
    String? employeeId,
    String? employeeName,
  }) {
    final list = getEmployeeSalaries();
    final cleanCode = (employeeCode ?? '').trim().toUpperCase();
    final cleanId = (employeeId ?? '').trim();
    final cleanName = (employeeName ?? '').trim().toLowerCase();

    for (final s in list) {
      if (cleanCode.isNotEmpty && s.employeeCode.toUpperCase() == cleanCode) {
        return s;
      }
      if (cleanId.isNotEmpty && s.employeeId == cleanId) {
        return s;
      }
      if (cleanName.isNotEmpty && s.employeeName.toLowerCase().trim() == cleanName) {
        return s;
      }
      if (EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: cleanId,
        recordEmployeeName: cleanName,
        employeeCode: s.employeeCode,
        employeeName: s.employeeName,
      )) {
        return s;
      }
    }
    return null;
  }

  /// Saves or updates an employee's fixed and variable salary configuration
  void saveEmployeeSalary(EmployeeSalaryConfig config, {bool persist = true}) {
    if (_isExcludedSalaryOwner(config.employeeName, config.employeeCode)) {
      return;
    }
    final index = _employeeSalaries.indexWhere((s) =>
        (s.employeeCode.isNotEmpty && s.employeeCode.toUpperCase() == config.employeeCode.toUpperCase()) ||
        (s.employeeId != null && config.employeeId != null && s.employeeId == config.employeeId) ||
        (s.employeeName.trim().toLowerCase() == config.employeeName.trim().toLowerCase()));

    if (index >= 0) {
      _employeeSalaries[index] = config;
    } else {
      _employeeSalaries.add(config);
    }
    if (persist) {
      _persistEmployeeSalaries();
    }
  }

  /// Bulk saves or updates salary configurations
  void saveEmployeeSalariesBatch(List<EmployeeSalaryConfig> configs, {bool persist = true}) {
    for (final c in configs) {
      saveEmployeeSalary(c, persist: false);
    }
    if (persist) {
      _persistEmployeeSalaries();
    }
  }

  // ====================================================================
  bool? getGeofenceOverride({
    String? userId,
    String? email,
    String? employeeCode,
    String? name,
  }) {
    if (userId != null && userId.trim().isNotEmpty) {
      final key = userId.trim().toLowerCase();
      if (_geofenceBypassOverrides.containsKey(key)) {
        return _geofenceBypassOverrides[key];
      }
    }
    if (email != null && email.trim().isNotEmpty) {
      final key = email.trim().toLowerCase();
      if (_geofenceBypassOverrides.containsKey(key)) {
        return _geofenceBypassOverrides[key];
      }
    }
    if (employeeCode != null && employeeCode.trim().isNotEmpty) {
      final key = employeeCode.trim().toLowerCase();
      if (_geofenceBypassOverrides.containsKey(key)) {
        return _geofenceBypassOverrides[key];
      }
    }
    if (name != null && name.trim().isNotEmpty) {
      final key = name.trim().toLowerCase();
      if (_geofenceBypassOverrides.containsKey(key)) {
        return _geofenceBypassOverrides[key];
      }
    }

    // Resolve via official master directory
    final official = EmployeeDirectoryHelper.resolveOfficialRecord(
      id: userId,
      code: employeeCode,
      email: email,
      name: name,
    );
    if (official != null) {
      final offId = official.employeeId.trim().toLowerCase();
      if (_geofenceBypassOverrides.containsKey(offId)) {
        return _geofenceBypassOverrides[offId];
      }
      final offEmail = official.email.trim().toLowerCase();
      if (_geofenceBypassOverrides.containsKey(offEmail)) {
        return _geofenceBypassOverrides[offEmail];
      }
      final offName = official.fullName.trim().toLowerCase();
      if (_geofenceBypassOverrides.containsKey(offName)) {
        return _geofenceBypassOverrides[offName];
      }
      for (final alias in official.aliases) {
        final aKey = alias.trim().toLowerCase();
        if (_geofenceBypassOverrides.containsKey(aKey)) {
          return _geofenceBypassOverrides[aKey];
        }
      }
    }

    // Check if any matching employee in _employees has bypassGeofence
    for (final e in _employees) {
      if ((userId != null && userId.trim().isNotEmpty && e.id.toLowerCase() == userId.trim().toLowerCase()) ||
          (employeeCode != null && employeeCode.trim().isNotEmpty && e.employeeCode.toLowerCase() == employeeCode.trim().toLowerCase()) ||
          (email != null && email.trim().isNotEmpty && e.email.trim().toLowerCase() == email.trim().toLowerCase()) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: e.id,
            recordEmployeeName: e.name,
            employeeId: userId,
            employeeCode: employeeCode,
            employeeName: name,
            employeeEmail: email,
          )) {
        return e.bypassGeofence;
      }
    }

    // Check if any matching user in _users has bypassGeofence
    for (final u in _users) {
      if ((userId != null && userId.trim().isNotEmpty && u.id.toLowerCase() == userId.trim().toLowerCase()) ||
          (employeeCode != null && employeeCode.trim().isNotEmpty && (u.employeeCode ?? '').toLowerCase() == employeeCode.trim().toLowerCase()) ||
          (email != null && email.trim().isNotEmpty && u.email.trim().toLowerCase() == email.trim().toLowerCase()) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: u.id,
            recordEmployeeName: u.fullName,
            employeeId: userId,
            employeeCode: employeeCode,
            employeeName: name,
            employeeEmail: email,
          )) {
        return u.bypassGeofence;
      }
    }

    return null;
  }

  Map<String, bool> get geofenceBypassOverrides => Map.unmodifiable(_geofenceBypassOverrides);

  void toggleEmployeeGeofenceBypass(
    String idOrEmail,
    bool bypass, {
    String? email,
    String? employeeCode,
    String? employeeName,
  }) {
    // 1. Record override into persistent Hive map
    final cleanId = idOrEmail.trim().toLowerCase();
    final cleanEmail = (email ?? '').trim().toLowerCase();
    final cleanCode = (employeeCode ?? '').trim().toLowerCase();
    final cleanName = (employeeName ?? '').trim().toLowerCase();

    if (cleanId.isNotEmpty) _geofenceBypassOverrides[cleanId] = bypass;
    if (cleanEmail.isNotEmpty) _geofenceBypassOverrides[cleanEmail] = bypass;
    if (cleanCode.isNotEmpty) _geofenceBypassOverrides[cleanCode] = bypass;
    if (cleanName.isNotEmpty) _geofenceBypassOverrides[cleanName] = bypass;

    // Resolve via official master directory to store all aliases & official keys
    final official = EmployeeDirectoryHelper.resolveOfficialRecord(
      id: cleanId,
      code: cleanCode.isNotEmpty ? cleanCode : null,
      email: cleanEmail.isNotEmpty ? cleanEmail : null,
      name: cleanName.isNotEmpty ? cleanName : null,
    );
    if (official != null) {
      _geofenceBypassOverrides[official.employeeId.trim().toLowerCase()] = bypass;
      _geofenceBypassOverrides[official.email.trim().toLowerCase()] = bypass;
      _geofenceBypassOverrides[official.fullName.trim().toLowerCase()] = bypass;
      for (final alias in official.aliases) {
        _geofenceBypassOverrides[alias.trim().toLowerCase()] = bypass;
      }
    }

    try {
      _settingsBox?.put('geofence_bypass_overrides', jsonEncode(_geofenceBypassOverrides));
    } catch (_) {}

    // 2. Update in _employees
    for (int i = 0; i < _employees.length; i++) {
      final e = _employees[i];
      final eId = e.id.toLowerCase();
      final eCode = e.employeeCode.toLowerCase();
      final eEmail = e.email.trim().toLowerCase();
      final eName = e.name.trim().toLowerCase();

      if (eId == cleanId ||
          eCode == cleanId ||
          eEmail == cleanId ||
          (cleanId.isNotEmpty && eName == cleanId) ||
          (cleanEmail.isNotEmpty && eEmail == cleanEmail) ||
          (cleanCode.isNotEmpty && eCode == cleanCode) ||
          (cleanName.isNotEmpty && eName == cleanName) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: e.id,
            recordEmployeeName: e.name,
            employeeId: idOrEmail,
            employeeCode: employeeCode,
            employeeName: employeeName,
            employeeEmail: email,
          )) {
        _employees[i] = e.copyWith(bypassGeofence: bypass);
      }
    }
    _persistEmployees();

    // 3. Update in _users
    for (int i = 0; i < _users.length; i++) {
      final u = _users[i];
      final uId = u.id.toLowerCase();
      final uFb = u.firebaseUid.toLowerCase();
      final uCode = (u.employeeCode ?? '').toLowerCase();
      final uEmail = u.email.trim().toLowerCase();
      final uName = u.fullName.trim().toLowerCase();

      if (uId == cleanId ||
          uFb == cleanId ||
          uCode == cleanId ||
          uEmail == cleanId ||
          (cleanId.isNotEmpty && uName == cleanId) ||
          (cleanEmail.isNotEmpty && uEmail == cleanEmail) ||
          (cleanCode.isNotEmpty && uCode == cleanCode) ||
          (cleanName.isNotEmpty && uName == cleanName) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: u.id,
            recordEmployeeName: u.fullName,
            employeeId: idOrEmail,
            employeeCode: employeeCode,
            employeeName: employeeName,
            employeeEmail: email,
          )) {
        _users[i] = u.copyWith(bypassGeofence: bypass);
      }
    }
    _persistUsers();

    // 4. Update current user if matches
    if (_currentUser != null) {
      final u = _currentUser!;
      final uId = u.id.toLowerCase();
      final uFb = u.firebaseUid.toLowerCase();
      final uEmail = u.email.trim().toLowerCase();
      final uCode = (u.employeeCode ?? '').trim().toLowerCase();
      final uName = u.fullName.trim().toLowerCase();
      if (uId == cleanId ||
          uFb == cleanId ||
          (cleanCode.isNotEmpty && (uCode == cleanCode || uId == cleanCode)) ||
          (cleanEmail.isNotEmpty && uEmail == cleanEmail) ||
          (cleanName.isNotEmpty && uName == cleanName) ||
          EmployeeDirectoryHelper.matchesEmployeeIdentity(
            recordEmployeeId: cleanId,
            recordEmployeeName: cleanName,
            employeeId: u.id,
            employeeCode: u.employeeCode,
            employeeName: u.fullName,
            employeeEmail: u.email,
          )) {
        setCurrentUser(u.copyWith(bypassGeofence: bypass));
      }
    }
    refreshCurrentUser();
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
    final filtered = _attendanceRecords.where((r) => !EmployeeDirectoryHelper.isRelievedEmployee(
      id: r.employeeId,
      name: r.employeeName,
    )).toList();
    return List.unmodifiable(filtered);
  }

  void addAttendanceRecord(AttendanceRecord record) {
    if (EmployeeDirectoryHelper.isRelievedEmployee(
      id: record.employeeId,
      name: record.employeeName,
    )) {
      return;
    }
    _attendanceRecords.add(record);
    _persistAttendanceRecords();
  }

  void clearAttendanceCache() {
    _attendanceRecords.clear();
    _settingsBox?.delete('attendance_records_json');
  }

  void saveAttendanceRecord(AttendanceRecord record, {bool persist = true}) {
    if (EmployeeDirectoryHelper.isRelievedEmployee(
      id: record.employeeId,
      name: record.employeeName,
    )) {
      _attendanceRecords.removeWhere((r) => r.id == record.id ||
        (r.employeeId == record.employeeId && record.employeeId.isNotEmpty));
      return;
    }
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
      final photoToKeep = record.photoBase64.trim().isNotEmpty
          ? record.photoBase64
          : existing.photoBase64;
      if (existing.isEdited && record.manualOvertimeHours == null && existing.manualOvertimeHours != null) {
        _attendanceRecords[index] = record.copyWith(
          photoBase64: photoToKeep,
          manualOvertimeHours: existing.manualOvertimeHours,
          overrideManualOvertimeHours: true,
          remarks: (existing.remarks != null && existing.remarks!.isNotEmpty) ? existing.remarks : record.remarks,
          isEdited: true,
          editedBy: existing.editedBy,
        );
      } else {
        _attendanceRecords[index] = record.copyWith(
          photoBase64: photoToKeep,
        );
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

  /// Persists office attendance calendar records locally and syncs them to Supabase cloud DB.
  Future<bool> saveOfficeAttendanceBatch({
    required List<AttendanceRecord> newRecords,
    List<String> deletedRecordIds = const [],
  }) async {
    // 1. Remove deleted records locally
    if (deletedRecordIds.isNotEmpty) {
      final deleteSet = deletedRecordIds.toSet();
      _attendanceRecords.removeWhere((r) => deleteSet.contains(r.id));
    }

    // 2. Add or update new records locally
    for (final record in newRecords) {
      saveAttendanceRecord(record, persist: false);
    }
    _persistAttendanceRecords();

    // 3. Fast non-blocking cloud sync in background so UI completes instantly without delay
    unawaited(_syncOfficeAttendanceBatchToCloud(
      newRecords: List.unmodifiable(newRecords),
      deletedRecordIds: List.unmodifiable(deletedRecordIds),
    ));

    return true;
  }

  Future<void> _syncOfficeAttendanceBatchToCloud({
    required List<AttendanceRecord> newRecords,
    required List<String> deletedRecordIds,
  }) async {
    if (deletedRecordIds.isNotEmpty) {
      try {
        await SupabaseService().deleteAttendanceRecords(deletedRecordIds);
      } catch (e) {
        debugPrint('Supabase delete office attendance error: $e');
      }
    }

    if (newRecords.isNotEmpty) {
      try {
        await SupabaseService().saveAdminAttendanceOverride(records: newRecords);
      } catch (e) {
        debugPrint('Supabase save office attendance error: $e');
      }
    }
  }

  void updateAttendanceRecord(AttendanceRecord updatedRecord) {
    saveAttendanceRecord(updatedRecord);
  }

  void deleteAttendanceRecord(String id) {
    _attendanceRecords.removeWhere((r) => r.id == id);
    _persistAttendanceRecords();
    SupabaseService().deleteAttendanceRecords([id]);
  }

  /// Delete all attendance records for an employee on a given date (both locally and in Supabase)
  Future<bool> deleteAttendanceRecordsForDate({
    required String employeeId,
    required String employeeName,
    required DateTime date,
    required List<String> recordIds,
  }) async {
    final idSet = recordIds.toSet();
    _attendanceRecords.removeWhere((r) => idSet.contains(r.id));
    _persistAttendanceRecords();

    // Trigger Cloud DB deletion
    try {
      final cloudOk = await SupabaseService().deleteAttendanceRecords(recordIds);
      return cloudOk;
    } catch (e) {
      debugPrint('Cloud sync note during attendance deletion: $e');
      return false;
    }
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

  DateTime? _lastSanitizeTime;

  /// Merges previous short-name duplicate employee records into their official enterprise profile across all staff,
  /// and consolidates all historical attendance records under the employee's official full name and canonical ID.
  Future<int> sanitizeDuplicateEmployees({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastSanitizeTime != null &&
        now.difference(_lastSanitizeTime!).inMinutes < 15) {
      return 0;
    }
    _lastSanitizeTime = now;

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

  DateTime? _lastAutoResolveTime;

  /// Scans all attendance records for unclosed sessions (officeCheckIn with no subsequent officeCheckOut).
  /// If elapsed time crosses 24 hours from the check-in time:
  /// - Automatically creates and captures an officeCheckOut record after exactly 8 hours from check-in.
  /// - Completes only the 8.0 regular hours shift and checks out.
  /// - Saves locally in Hive and flags for cloud synchronization.
  /// Throttled to execute at most once per 60 seconds to eliminate main-thread UI jank and lag.
  int autoResolveExpiredCheckIns({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastAutoResolveTime != null &&
        now.difference(_lastAutoResolveTime!).inSeconds < 60) {
      return 0;
    }
    _lastAutoResolveTime = now;

    int resolvedCount = 0;

    // Purge any premature synthetic Auto Check-Out records if the office check-in has not crossed 24 hours
    final initialRecordsLength = _attendanceRecords.length;
    _attendanceRecords.removeWhere((r) {
      if (r.workflowStep != WorkflowStep.officeCheckOut) return false;
      if (!r.address.contains('Auto Check-Out')) return false;

      final matchingCheckIns = _attendanceRecords.where((ci) =>
          ci.workflowStep == WorkflowStep.officeCheckIn &&
          ci.employeeId == r.employeeId &&
          ci.eventTimestamp.isBefore(r.eventTimestamp)).toList()
        ..sort((a, b) => b.eventTimestamp.compareTo(a.eventTimestamp));

      if (matchingCheckIns.isNotEmpty) {
        final lastCheckIn = matchingCheckIns.first;
        final elapsed = now.difference(lastCheckIn.eventTimestamp);
        if (elapsed < const Duration(hours: 24)) {
          return true; // Purge premature synthetic checkout
        }
      }
      return false;
    });
    if (_attendanceRecords.length != initialRecordsLength) {
      _persistAttendanceRecords();
    }

    // Group records by canonical employeeId
    final Map<String, List<AttendanceRecord>> employeeRecordsMap = {};
    for (final record in _attendanceRecords) {
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: record.employeeId,
        name: record.employeeName,
        id: record.employeeId,
      );
      final key = official != null ? official.employeeId.toUpperCase() : record.employeeId;
      employeeRecordsMap.putIfAbsent(key, () => []).add(record);
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
            // Check if there is an officeCheckOut (or final day end) occurring after this checkIn and before any subsequent officeCheckIn
            bool hasMatchingCheckOut = false;
            for (int j = i + 1; j < records.length; j++) {
              final nextRec = records[j];
              if (nextRec.workflowStep == WorkflowStep.officeCheckOut) {
                hasMatchingCheckOut = true;
                break;
              } else if (nextRec.workflowStep == WorkflowStep.officeCheckIn) {
                // Next office checkIn session started without checking out the previous one
                break;
              }
            }

            if (!hasMatchingCheckOut) {
              // Auto-generate officeCheckOut after 8 hours from check-in time
              final autoCheckOutTime = checkInTime.add(const Duration(hours: 8));

              // Avoid duplicate if already exists with same timestamp or auto checkout address
              final duplicateExists = records.any((r) =>
                  r.workflowStep == WorkflowStep.officeCheckOut &&
                  (r.eventTimestamp.isAtSameMomentAs(autoCheckOutTime) ||
                   (r.address.contains('Auto Check-Out') &&
                    r.eventTimestamp.isAfter(checkInTime))));

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

  /// Prunes records belonging to other employees from local memory and Hive storage on employee devices.
  /// Preserves all records matching the employee identity plus any pending offline sync records.
  void pruneAttendanceRecordsForEmployee(String employeeId, {String? employeeName}) {
    if (employeeId.trim().isEmpty) return;
    final cleanId = employeeId.trim().toLowerCase();
    final cleanName = employeeName?.trim().toLowerCase() ?? '';

    // Resolve target identity from master directory, current user, or stored users
    UserEntity? targetUser;
    if (_currentUser != null &&
        (_currentUser!.id.toLowerCase() == cleanId ||
         _currentUser!.firebaseUid.toLowerCase() == cleanId ||
         _currentUser!.fullName.trim().toLowerCase() == cleanName)) {
      targetUser = _currentUser;
    } else {
      targetUser = _users.where((u) =>
          u.id.toLowerCase() == cleanId ||
          u.firebaseUid.toLowerCase() == cleanId ||
          (cleanName.isNotEmpty && u.fullName.trim().toLowerCase() == cleanName)).firstOrNull;
    }

    final targetOfficial = EmployeeDirectoryHelper.resolveOfficialRecord(
      id: employeeId,
      code: targetUser?.employeeCode,
      name: employeeName ?? targetUser?.fullName,
      email: targetUser?.email,
    );

    final initialCount = _attendanceRecords.length;
    _attendanceRecords.retainWhere((r) {
      // Always retain pending unsynced records regardless
      if (r.syncStatus == SyncStatus.pending) return true;

      final rId = r.employeeId.trim().toLowerCase();
      final rName = r.employeeName.trim().toLowerCase();

      if (rId == cleanId || (cleanName.isNotEmpty && rName == cleanName)) return true;

      if (targetOfficial != null) {
        final recOfficial = EmployeeDirectoryHelper.resolveOfficialRecord(
          code: r.employeeId,
          name: r.employeeName,
          id: r.employeeId,
        );
        if (recOfficial != null) {
          return recOfficial.employeeId.toUpperCase() == targetOfficial.employeeId.toUpperCase();
        }
        final oCode = targetOfficial.employeeId.toLowerCase();
        if (rId == oCode || rId == 'emp-$oCode') return true;
        if (rName == targetOfficial.fullName.toLowerCase()) return true;
        if (targetOfficial.aliases.any((a) => a.toLowerCase() == rName)) return true;
      }

      return EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: r.employeeId,
        recordEmployeeName: r.employeeName,
        employeeId: targetOfficial?.employeeId ?? employeeId,
        employeeCode: targetOfficial?.employeeId ?? targetUser?.employeeCode,
        employeeName: targetOfficial?.fullName ?? employeeName ?? targetUser?.fullName,
        employeeEmail: targetOfficial?.email ?? targetUser?.email,
      );
    });

    if (_attendanceRecords.length != initialCount) {
      debugPrint('[LocalDatabaseService] Pruned ${initialCount - _attendanceRecords.length} non-employee records from device cache.');
      _persistAttendanceRecords();
    }
  }

  /// Fetches attendance records for the active shift or current workday session for an employee.
  /// If the employee is currently in an unclosed shift (e.g., started at 2:00 PM yesterday and ongoing past midnight),
  /// all records belonging to this active shift session are returned so the workflow and timeline remain continuous.
  List<AttendanceRecord> getTodayAttendanceRecords([String? employeeId]) {
    autoResolveExpiredCheckIns();

    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);

    final cleanTarget = employeeId?.trim();

    // Resolve target identity metadata from current user, users list, or employees list
    UserEntity? targetUser;
    EmployeeEntity? targetEmp;
    if (cleanTarget != null && cleanTarget.isNotEmpty) {
      if (_currentUser != null &&
          (_currentUser!.id == cleanTarget ||
           _currentUser!.firebaseUid == cleanTarget ||
           _currentUser!.employeeCode == cleanTarget ||
           _currentUser!.fullName.trim().toLowerCase() == cleanTarget.toLowerCase())) {
        targetUser = _currentUser;
      } else {
        targetUser = _users.where((u) =>
            u.id == cleanTarget ||
            u.firebaseUid == cleanTarget ||
            (u.employeeCode != null && u.employeeCode!.trim().toLowerCase() == cleanTarget.toLowerCase()) ||
            u.fullName.trim().toLowerCase() == cleanTarget.toLowerCase()).firstOrNull;
      }

      if (targetUser == null) {
        targetEmp = _employees.where((e) =>
            e.id == cleanTarget ||
            e.employeeCode.trim().toLowerCase() == cleanTarget.toLowerCase() ||
            e.name.trim().toLowerCase() == cleanTarget.toLowerCase()).firstOrNull;
      }
    } else {
      targetUser = _currentUser;
    }

    final targetOfficial = EmployeeDirectoryHelper.resolveOfficialRecord(
      id: cleanTarget ?? targetUser?.id,
      code: targetUser?.employeeCode ?? targetEmp?.employeeCode ?? cleanTarget,
      name: targetUser?.fullName ?? targetEmp?.name ?? cleanTarget,
      email: targetUser?.email ?? targetEmp?.email,
    );

    final String? tId = targetOfficial?.employeeId ?? cleanTarget ?? targetUser?.id;
    final String? tCode = targetOfficial?.employeeId ?? targetUser?.employeeCode ?? targetEmp?.employeeCode ?? cleanTarget;
    final String? tName = targetOfficial?.fullName ?? targetUser?.fullName ?? targetEmp?.name ?? cleanTarget;
    final String? tEmail = targetOfficial?.email ?? targetUser?.email ?? targetEmp?.email;

    final empRecords = _attendanceRecords.where((r) {
      if (EmployeeDirectoryHelper.isRelievedEmployee(id: r.employeeId, name: r.employeeName)) {
        return false;
      }

      // 1. If target resolves to official master directory, strictly compare official records
      if (targetOfficial != null) {
        final recOfficial = EmployeeDirectoryHelper.resolveOfficialRecord(
          code: r.employeeId,
          name: r.employeeName,
          id: r.employeeId,
        );
        if (recOfficial != null) {
          return recOfficial.employeeId.toUpperCase() == targetOfficial.employeeId.toUpperCase();
        }
      }

      // 2. Direct exact ID match
      if (cleanTarget != null && cleanTarget.isNotEmpty) {
        if (r.employeeId == cleanTarget) return true;
      }

      // 3. Current user attributes & device binding match
      if (targetUser != null) {
        if (targetUser.id.trim().isNotEmpty && r.employeeId == targetUser.id) return true;
        if (targetUser.firebaseUid.trim().isNotEmpty && r.employeeId == targetUser.firebaseUid) return true;
        if (r.deviceId.isNotEmpty && r.deviceId == 'device-hw-${targetUser.id}') return true;
      }

      // 4. Exhaustive identity match via helper
      return EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: r.employeeId,
        recordEmployeeName: r.employeeName,
        employeeId: tId,
        employeeCode: tCode,
        employeeName: tName,
        employeeEmail: tEmail,
      );
    }).toList()
      ..sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    if (empRecords.isEmpty) return [];

    // 1. Check if there is an active unclosed regular shift (officeCheckIn within last 24h with no subsequent officeCheckOut)
    AttendanceRecord? activeCheckIn;
    for (int i = empRecords.length - 1; i >= 0; i--) {
      final rec = empRecords[i];
      if (rec.workflowStep == WorkflowStep.officeCheckOut) {
        if (!rec.address.contains('Auto Check-Out')) {
          break;
        }
      }
      if (rec.workflowStep == WorkflowStep.officeCheckIn) {
        final elapsed = now.difference(rec.eventTimestamp);
        if (elapsed < const Duration(hours: 24)) {
          activeCheckIn = rec;
        }
        break;
      }
    }

    if (activeCheckIn != null) {
      // Shift is actively in progress! Return all records from activeCheckIn onwards
      return empRecords
          .where((r) => !r.eventTimestamp.isBefore(activeCheckIn!.eventTimestamp))
          .toList();
    }

    // 1b. Check if there is an active unclosed emergency duty (emergencyCheckIn within last 24h with no subsequent emergencyCheckOut)
    AttendanceRecord? activeEmergencyCheckIn;
    for (int i = empRecords.length - 1; i >= 0; i--) {
      final rec = empRecords[i];
      if (rec.workflowStep == WorkflowStep.emergencyCheckOut) {
        break;
      }
      if (rec.workflowStep == WorkflowStep.emergencyCheckIn) {
        final elapsed = now.difference(rec.eventTimestamp);
        if (elapsed < const Duration(hours: 24)) {
          activeEmergencyCheckIn = rec;
        }
        break;
      }
    }

    if (activeEmergencyCheckIn != null) {
      return empRecords
          .where((r) => !r.eventTimestamp.isBefore(activeEmergencyCheckIn!.eventTimestamp))
          .toList();
    }

    // 2. Check if an officeCheckIn occurred on today's calendar date
    final todayCheckIns = empRecords.where((r) {
      if (r.workflowStep != WorkflowStep.officeCheckIn) return false;
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
      if (r.workflowStep != WorkflowStep.officeCheckOut) return false;
      final localEv = r.eventTimestamp.toLocal();
      final rDate = DateTime(localEv.year, localEv.month, localEv.day);
      return rDate.isAtSameMomentAs(today);
    }).toList();

    if (recentCheckOutToday.isNotEmpty) {
      final lastOut = recentCheckOutToday.last;
      final matchingIn = empRecords.lastWhere(
        (r) =>
            r.workflowStep == WorkflowStep.officeCheckIn &&
            r.eventTimestamp.isBefore(lastOut.eventTimestamp),
        orElse: () => recentCheckOutToday.first,
      );

      final matchingInLocal = matchingIn.eventTimestamp.toLocal();
      final matchingInDate =
          DateTime(matchingInLocal.year, matchingInLocal.month, matchingInLocal.day);
      final isOvernightFromPrevDay = matchingInDate.isBefore(today);

      // If the checkout closed an overnight shift from a previous day:
      // - Show completed shift summary within a 4-hour window (e.g. 2:05 AM right after shift end).
      // - After 4+ hours (e.g. 2:00 PM next afternoon), the employee has rested and is ready to start Day 2 duty fresh!
      final elapsedSinceCheckout = now.difference(lastOut.eventTimestamp);
      if (!isOvernightFromPrevDay || elapsedSinceCheckout < const Duration(hours: 4)) {
        return empRecords
            .where((r) =>
                !r.eventTimestamp.isBefore(matchingIn.eventTimestamp) &&
                !r.eventTimestamp.isAfter(lastOut.eventTimestamp))
            .toList();
      } else {
        // The overnight shift from previous day concluded > 4 hours ago.
        // That shift is finished and archived to yesterday's timesheet.
        // For today's session, only records that occurred strictly AFTER that checkout belong to today.
        return empRecords.where((r) {
          if (!r.eventTimestamp.isAfter(lastOut.eventTimestamp)) return false;
          final localEv = r.eventTimestamp.toLocal();
          final rDate = DateTime(localEv.year, localEv.month, localEv.day);
          return rDate.isAtSameMomentAs(today);
        }).toList();
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

    final todayUserRecords = getTodayAttendanceRecords(employeeId);

    if (todayUserRecords.isEmpty) {
      return WorkflowStep.officeCheckIn;
    }

    for (int i = todayUserRecords.length - 1; i >= 0; i--) {
      final step = todayUserRecords[i].workflowStep;
      if (step == WorkflowStep.emergencyCheckIn) return WorkflowStep.emergencyCheckOut;
      if (step == WorkflowStep.emergencyCheckOut) break;
    }

    if (todayUserRecords.any((r) => r.workflowStep == WorkflowStep.officeCheckOut)) {
      return WorkflowStep.completed;
    } else if (todayUserRecords.last.workflowStep == WorkflowStep.breakStart) {
      return WorkflowStep.breakEnd;
    } else {
      bool atSite = false;
      for (int i = todayUserRecords.length - 1; i >= 0; i--) {
        final step = todayUserRecords[i].workflowStep;
        if (step == WorkflowStep.siteCheckIn) {
          atSite = true;
          break;
        }
        if (step == WorkflowStep.siteCheckOut || step == WorkflowStep.officeCheckOut) {
          atSite = false;
          break;
        }
      }
      if (atSite) {
        return WorkflowStep.siteCheckOut;
      } else {
        return WorkflowStep.siteCheckIn;
      }
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

    final pending = _attendanceRecords
        .where((r) => r.syncStatus == SyncStatus.pending)
        .toList();
    if (employeeId == null || employeeId.trim().isEmpty) {
      return pending;
    }

    final cleanTarget = employeeId.trim().toLowerCase();
    final user = _currentUser;
    final officialUser = EmployeeDirectoryHelper.resolveOfficialRecord(
      code: user?.employeeCode,
      name: user?.fullName,
      email: user?.email,
      id: user?.id,
    );

    return pending.where((r) {
      final rEmpId = r.employeeId.trim().toLowerCase();
      final rEmpName = r.employeeName.trim().toLowerCase();

      // 1. Direct match on target ID or name
      if (rEmpId == cleanTarget || rEmpName == cleanTarget) return true;

      // 2. Current user attributes & device binding
      if (user != null) {
        if (user.id.trim().toLowerCase() == rEmpId) return true;
        if (user.firebaseUid.trim().toLowerCase() == rEmpId) return true;
        if (user.employeeCode != null &&
            user.employeeCode!.trim().isNotEmpty &&
            user.employeeCode!.trim().toLowerCase() == rEmpId) {
          return true;
        }
        if (user.fullName.trim().toLowerCase() == rEmpName) return true;
        if (r.deviceId.isNotEmpty && r.deviceId == 'device-hw-${user.id}') {
          return true;
        }
      }

      // 3. Match against employee identity rules
      if (EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: r.employeeId,
        recordEmployeeName: r.employeeName,
        employeeId: cleanTarget,
        employeeCode: user?.employeeCode,
        employeeName: user?.fullName,
        employeeEmail: user?.email,
      )) {
        return true;
      }

      // 4. Match against official master directory resolution
      final officialRecord = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: r.employeeId,
        name: r.employeeName,
        id: r.employeeId,
      );
      if (officialRecord != null) {
        if (officialUser != null &&
            officialRecord.employeeId.toUpperCase() == officialUser.employeeId.toUpperCase()) {
          return true;
        }
        if (officialRecord.employeeId.toLowerCase() == cleanTarget ||
            officialRecord.aliases.any((a) => a.toLowerCase() == cleanTarget)) {
          return true;
        }
      }

      return false;
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

  // Employee Cards Persistence (Dual-layer: Hive + SharedPreferences for 100% fail-safe restart)
  List<Map<String, dynamic>> getSavedEmployeeCards() {
    try {
      final str = _settingsBox?.get('employee_cards_json');
      if (str != null && str.toString().isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> persistEmployeeCards(List<Map<String, dynamic>> cardsJson) async {
    final encoded = jsonEncode(cardsJson);
    try {
      await _settingsBox?.put('employee_cards_json', encoded);
    } catch (e) {
      debugPrint('Error saving employee cards to Hive: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_cards_json', encoded);
    } catch (e) {
      debugPrint('Error saving employee cards to SharedPreferences: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadSavedEmployeeCardsAsync() async {
    final fromHive = getSavedEmployeeCards();
    if (fromHive.isNotEmpty) return fromHive;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('employee_cards_json');
      if (str != null && str.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
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

  // Auto-Sync Persistence
  bool isAutoSyncEnabled() {
    return _settingsBox?.get('is_auto_sync_enabled', defaultValue: true) ?? true;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    try {
      await _settingsBox?.put('is_auto_sync_enabled', enabled);
    } catch (e) {
      debugPrint('Error saving auto sync setting to Hive: $e');
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

  // Gemini AI Vision API Key
  String? getGeminiApiKey() {
    return _settingsBox?.get('gemini_api_key') as String?;
  }

  Future<void> saveGeminiApiKey(String? key) async {
    try {
      if (key == null || key.trim().isEmpty) {
        await _settingsBox?.delete('gemini_api_key');
      } else {
        await _settingsBox?.put('gemini_api_key', key.trim());
      }
    } catch (e) {
      debugPrint('Error saving Gemini API key to Hive: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Automated Compliance Robot Settings (Resend + CallMeBot WhatsApp)
  // --------------------------------------------------------------------------
  String? getResendApiKey() {
    return _settingsBox?.get('compliance_resend_api_key') as String?;
  }

  Future<void> saveResendApiKey(String? key) async {
    try {
      if (key == null || key.trim().isEmpty) {
        await _settingsBox?.delete('compliance_resend_api_key');
      } else {
        await _settingsBox?.put('compliance_resend_api_key', key.trim());
      }
    } catch (e) {
      debugPrint('Error saving Resend API key to Hive: $e');
    }
  }

  String? getCallMeBotApiKey() {
    return _settingsBox?.get('compliance_callmebot_api_key') as String?;
  }

  Future<void> saveCallMeBotApiKey(String? key) async {
    try {
      if (key == null || key.trim().isEmpty) {
        await _settingsBox?.delete('compliance_callmebot_api_key');
      } else {
        await _settingsBox?.put('compliance_callmebot_api_key', key.trim());
      }
    } catch (e) {
      debugPrint('Error saving CallMeBot API key to Hive: $e');
    }
  }

  bool isAutoNotificationRobotEnabled() {
    return _settingsBox?.get('compliance_robot_enabled', defaultValue: true) ?? true;
  }

  Future<void> setAutoNotificationRobotEnabled(bool enabled) async {
    await _settingsBox?.put('compliance_robot_enabled', enabled);
  }

  String? getLastRobotDispatchDate() {
    return _settingsBox?.get('compliance_robot_last_date') as String?;
  }

  Future<void> setLastRobotDispatchDate(String dateStr) async {
    await _settingsBox?.put('compliance_robot_last_date', dateStr);
  }

  String getNotificationTargetEmail() {
    return _settingsBox?.get('compliance_target_email', defaultValue: 'sr.irshath@gmail.com, nasuru@fusionmaint.com') ?? 'sr.irshath@gmail.com, nasuru@fusionmaint.com';
  }

  Future<void> saveNotificationTargetEmail(String? email) async {
    try {
      if (email == null || email.trim().isEmpty) {
        await _settingsBox?.delete('compliance_target_email');
      } else {
        await _settingsBox?.put('compliance_target_email', email.trim());
      }
    } catch (e) {
      debugPrint('Error saving compliance target email to Hive: $e');
    }
  }
}

