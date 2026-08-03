import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/app_enums.dart';
import '../core/services/supabase_service.dart';
import '../features/setup/domain/organization_setup.dart';
import '../features/auth/domain/user_entity.dart';
import '../features/admin/domain/employee_entity.dart';
import '../features/admin/domain/office_entity.dart';
import '../features/admin/domain/work_site_entity.dart';
import '../features/admin/domain/work_shift_entity.dart';
import '../features/admin/domain/employee_shift_assignment_entity.dart';
import '../features/attendance/domain/attendance_record.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  bool _isSetupCompleted = false;
  OrganizationSetup? _organization;
  UserEntity? _currentUser;
  Box? _settingsBox;

  final List<EmployeeEntity> _employees = [];
  final List<OfficeEntity> _offices = [];
  final List<WorkSiteEntity> _workSites = [];
  final List<AttendanceRecord> _attendanceRecords = [];
  final List<WorkShiftEntity> _shifts = [];
  final List<EmployeeShiftAssignmentEntity> _shiftAssignments = [];

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

      final savedShiftsJson = _settingsBox?.get('shifts_json');
      if (savedShiftsJson != null && savedShiftsJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedShiftsJson);
          _shifts.clear();
          for (final item in decoded) {
            _shifts.add(WorkShiftEntity.fromJson(item));
          }
        } catch (_) {}
      }

      if (_shifts.isEmpty) {
        _shifts.addAll([
          WorkShiftEntity(id: 'shift-morning', name: 'Morning Shift', startTime: '08:00', endTime: '18:00'),
          WorkShiftEntity(id: 'shift-general', name: 'General Shift', startTime: '09:00', endTime: '18:00'),
          WorkShiftEntity(id: 'shift-evening', name: 'Evening Shift', startTime: '14:00', endTime: '22:00'),
          WorkShiftEntity(id: 'shift-night', name: 'Night Shift', startTime: '22:00', endTime: '06:00'),
        ]);
        _persistShifts();
      }

      final savedAssignmentsJson = _settingsBox?.get('shift_assignments_json');
      if (savedAssignmentsJson != null && savedAssignmentsJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedAssignmentsJson);
          _shiftAssignments.clear();
          for (final item in decoded) {
            _shiftAssignments.add(EmployeeShiftAssignmentEntity.fromJson(item));
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

  // Offices CRUD
  List<OfficeEntity> getOffices() => List.unmodifiable(_offices);

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
    return List.unmodifiable(uniqueMap.values.toList());
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

  void deleteEmployee(String id) {
    _employees.removeWhere((e) => e.id == id);
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

  /// Fetches today's attendance records for a specific employee based on active shift duty 24-hr cycle
  List<AttendanceRecord> getTodayAttendanceRecords([String? employeeId]) {
    final targetId = employeeId ?? _currentUser?.id ?? _currentUser?.firebaseUid;
    if (targetId == null || targetId.isEmpty) return [];

    final now = DateTime.now();
    final activeShift = getShiftForEmployee(targetId, now);
    final todayDutyDateStr = activeShift.getDutyDateStr(now);

    return _attendanceRecords.where((r) {
      final matchesUser = (r.employeeId == targetId ||
          (_currentUser != null &&
              (r.employeeId == _currentUser!.id ||
               r.employeeId == _currentUser!.firebaseUid ||
               r.employeeName.trim().toLowerCase() == _currentUser!.fullName.trim().toLowerCase())));
      final recordShift = getShiftForEmployee(targetId, r.eventTimestamp);
      final rDutyDateStr = recordShift.getDutyDateStr(r.eventTimestamp);
      return matchesUser && rDutyDateStr == todayDutyDateStr;
    }).toList();
  }

  /// Dynamically computes current workflow step for a specific employee for today
  WorkflowStep getWorkflowStepForEmployee([String? employeeId]) {
    final todayUserRecords = getTodayAttendanceRecords(employeeId);

    if (todayUserRecords.isEmpty) {
      return WorkflowStep.officeCheckIn;
    }

    final lastRecord = todayUserRecords.last;
    if (lastRecord.workflowStep == WorkflowStep.officeCheckOut) {
      return WorkflowStep.completed;
    } else if (lastRecord.workflowStep == WorkflowStep.siteCheckIn) {
      return WorkflowStep.siteCheckOut;
    } else {
      // Last record was officeCheckIn or siteCheckOut: user is on duty & ready for officeCheckOut (Final Day Check-Out)
      return WorkflowStep.officeCheckOut;
    }
  }

  /// Checks if the employee has already completed at least one site check-in today
  bool isFirstSiteCheckInToday([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    return !todayRecords.any((r) => r.workflowStep == WorkflowStep.siteCheckIn);
  }

  /// Gets the site name of the currently active site check-in (if checked in)
  String? getActiveSiteNameToday([String? employeeId]) {
    final todayRecords = getTodayAttendanceRecords(employeeId);
    if (todayRecords.isNotEmpty && todayRecords.last.workflowStep == WorkflowStep.siteCheckIn) {
      return todayRecords.last.siteName ?? 'Current Site';
    }
    return null;
  }

  WorkflowStep get currentWorkflowStep => getWorkflowStepForEmployee();

  List<AttendanceRecord> getPendingSyncRecords([String? employeeId]) {
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

  // Work Shifts CRUD & Scheduling
  List<WorkShiftEntity> getShifts() => List.unmodifiable(_shifts);

  void saveShift(WorkShiftEntity shift) {
    int index = _shifts.indexWhere((s) => s.id == shift.id);
    if (index >= 0) {
      _shifts[index] = shift;
    } else {
      _shifts.add(shift);
    }
    _persistShifts();
  }

  void deleteShift(String id) {
    _shifts.removeWhere((s) => s.id == id);
    _persistShifts();
  }

  void _persistShifts() {
    try {
      final jsonList = _shifts.map((s) => s.toJson()).toList();
      _settingsBox?.put('shifts_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error persisting shifts to Hive: $e');
    }
  }

  // Employee Shift Daily Assignments
  List<EmployeeShiftAssignmentEntity> getShiftAssignments() =>
      List.unmodifiable(_shiftAssignments);

  void saveShiftAssignment(EmployeeShiftAssignmentEntity assignment) {
    int index = _shiftAssignments.indexWhere((a) =>
        a.id == assignment.id ||
        (a.employeeId == assignment.employeeId && a.dateStr == assignment.dateStr));
    if (index >= 0) {
      _shiftAssignments[index] = assignment;
    } else {
      _shiftAssignments.add(assignment);
    }
    _persistShiftAssignments();
  }

  void deleteShiftAssignment(String id) {
    _shiftAssignments.removeWhere((a) => a.id == id);
    _persistShiftAssignments();
  }

  void _persistShiftAssignments() {
    try {
      final jsonList = _shiftAssignments.map((a) => a.toJson()).toList();
      _settingsBox?.put('shift_assignments_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error persisting shift assignments to Hive: $e');
    }
  }

  /// Gets the active shift for a specific employee on a specific date.
  /// Falls back to General Shift if no specific daily roster assignment exists.
  WorkShiftEntity getShiftForEmployee(String? employeeId, DateTime date) {
    final targetId = employeeId ?? _currentUser?.id ?? _currentUser?.firebaseUid;
    final dateStr = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    if (targetId != null && targetId.isNotEmpty) {
      final assignment = _shiftAssignments.firstWhere(
        (a) => a.employeeId == targetId && a.dateStr == dateStr,
        orElse: () => EmployeeShiftAssignmentEntity(
          id: '',
          employeeId: '',
          dateStr: '',
          shiftName: '',
          startTime: '',
          endTime: '',
        ),
      );

      if (assignment.id.isNotEmpty) {
        return assignment.toWorkShift();
      }
    }

    // Default fallback shift
    return _shifts.firstWhere(
      (s) => s.id == 'shift-general',
      orElse: () => _shifts.isNotEmpty
          ? _shifts.first
          : WorkShiftEntity(
              id: 'shift-general',
              name: 'General Shift',
              startTime: '09:00',
              endTime: '18:00',
            ),
    );
  }
}
