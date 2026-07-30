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

  WorkflowStep _currentWorkflowStep = WorkflowStep.officeCheckIn;

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
      if (savedEmployeesJson != null && savedEmployeesJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedEmployeesJson);
          _employees.clear();
          for (final item in decoded) {
            _employees.add(EmployeeEntity.fromJson(item));
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
      if (savedWorkSitesJson != null && savedWorkSitesJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedWorkSitesJson);
          _workSites.clear();
          for (final item in decoded) {
            _workSites.add(WorkSiteEntity.fromJson(item));
          }
        } catch (_) {}
      }

      final savedAttendanceJson = _settingsBox?.get('attendance_records_json');
      if (savedAttendanceJson != null && savedAttendanceJson.toString().isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(savedAttendanceJson);
          _attendanceRecords.clear();
          for (final item in decoded) {
            _attendanceRecords.add(AttendanceRecord.fromJson(item));
          }
          if (_attendanceRecords.isNotEmpty) {
            final lastRecord = _attendanceRecords.last;
            if (lastRecord.workflowStep.nextStep != null) {
              _currentWorkflowStep = lastRecord.workflowStep.nextStep!;
            } else {
              _currentWorkflowStep = WorkflowStep.completed;
            }
          }
        } catch (_) {}
      }

      // Check live setup status against Supabase table 'organizations'
      await checkSetupStatusFromSupabase();
    } catch (e) {
      debugPrint('Hive database initialization warning: $e');
    }

    // Set Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi as main default office
    _offices.removeWhere((o) => o.id == 'office-main-001' || o.name == 'Main Office');
    final existingDefaultIndex = _offices.indexWhere((o) => o.id == 'office-musaffah-m12-001');
    if (existingDefaultIndex >= 0) {
      _offices[existingDefaultIndex] = OfficeEntity(
        id: 'office-musaffah-m12-001',
        name: 'Store - 12',
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        latitude: 24.3644,
        longitude: 54.5029,
        geofenceRadiusMeters: 200.0,
        isDefault: true,
      );
    } else {
      _offices.insert(
        0,
        OfficeEntity(
          id: 'office-musaffah-m12-001',
          name: 'Store - 12',
          address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
          latitude: 24.3644,
          longitude: 54.5029,
          geofenceRadiusMeters: 200.0,
          isDefault: true,
        ),
      );
    }

    // Ensure no other office is marked default
    for (int i = 0; i < _offices.length; i++) {
      if (_offices[i].id != 'office-musaffah-m12-001') {
        _offices[i] = OfficeEntity(
          id: _offices[i].id,
          name: _offices[i].name,
          address: _offices[i].address,
          latitude: _offices[i].latitude,
          longitude: _offices[i].longitude,
          geofenceRadiusMeters: _offices[i].geofenceRadiusMeters,
          isDefault: false,
        );
      }
    }
    _persistOffices();

    // Seed default client site if empty
    if (_workSites.isEmpty) {
      _workSites.add(WorkSiteEntity(
        id: 'site-musaffah-001',
        siteName: 'Musaffah Industrial Site',
        clientName: 'Abu Dhabi Municipality',
        address: 'M12 Industrial Area, Musaffah, Abu Dhabi',
        latitude: 24.3644,
        longitude: 54.5029,
        radiusMeters: 300.0,
        assignedEmployeeIds: ['emp-001', 'emp-002'],
      ));
      _persistWorkSites();
    }

    // Seed default employees unconditionally if empty
    if (_employees.isEmpty) {
      _employees.add(EmployeeEntity(
        id: 'emp-001',
        employeeCode: 'EMP-1001',
        name: 'Irshath Ahamed',
        mobileNumber: '+971521354859',
        email: 'sr.irshath@gmail.com',
        designation: 'Super Administrator',
        department: 'Management',
        useDefaultOffice: true,
        assignedOfficeId: 'office-musaffah-m12-001',
        assignedOfficeName: 'Store - 12',
        isActive: true,
      ));

      _employees.add(EmployeeEntity(
        id: 'emp-002',
        employeeCode: 'EMP-1002',
        name: 'Sophia Martinez',
        mobileNumber: '+971509876543',
        email: 'sophia@enterprise.com',
        designation: 'Project Consultant',
        department: 'Client Services',
        useDefaultOffice: true,
        assignedOfficeId: 'office-musaffah-m12-001',
        assignedOfficeName: 'Store - 12',
        isActive: true,
      ));

      _persistEmployees();
    }

    // Seed sample attendance records unconditionally if empty
    if (_attendanceRecords.isEmpty) {
      const String sampleBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      // Irshath Ahamed (emp-001) Today
      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-checkin',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: today.add(const Duration(hours: 8, minutes: 30)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 4.8,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-sitein',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.siteCheckIn,
        eventTimestamp: today.add(const Duration(hours: 10, minutes: 15)),
        latitude: 24.3648,
        longitude: 54.5032,
        gpsAccuracy: 5.5,
        address: 'M12 Industrial Area, Musaffah, Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        workSiteId: 'site-musaffah-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-sitedepart',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.siteCheckOut,
        eventTimestamp: today.add(const Duration(hours: 15, minutes: 45)),
        latitude: 24.3648,
        longitude: 54.5032,
        gpsAccuracy: 6.0,
        address: 'M12 Industrial Area, Musaffah, Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        workSiteId: 'site-musaffah-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-checkout',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.officeCheckOut,
        eventTimestamp: today.add(const Duration(hours: 17, minutes: 30)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 5.0,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      // Irshath Ahamed (emp-001) Yesterday
      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-yest-checkin',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: yesterday.add(const Duration(hours: 8, minutes: 25)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 5.0,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-yest-checkout',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.officeCheckOut,
        eventTimestamp: yesterday.add(const Duration(hours: 17, minutes: 35)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 5.0,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      // Sophia Martinez (emp-002) Today
      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-002-checkin',
        employeeId: 'emp-002',
        employeeName: 'Sophia Martinez',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: today.add(const Duration(hours: 9, minutes: 0)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 6.2,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-IPHONE-14PRO',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      _persistAttendanceRecords();
    }
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
    if (_employees.isEmpty) {
      _employees.add(EmployeeEntity(
        id: 'emp-001',
        employeeCode: 'EMP-1001',
        name: 'Irshath Ahamed',
        mobileNumber: '+971521354859',
        email: 'sr.irshath@gmail.com',
        designation: 'Super Administrator',
        department: 'Management',
        useDefaultOffice: true,
        assignedOfficeId: 'office-musaffah-m12-001',
        assignedOfficeName: 'Store - 12',
        isActive: true,
      ));
      _employees.add(EmployeeEntity(
        id: 'emp-002',
        employeeCode: 'EMP-1002',
        name: 'Sophia Martinez',
        mobileNumber: '+971509876543',
        email: 'sophia@enterprise.com',
        designation: 'Project Consultant',
        department: 'Client Services',
        useDefaultOffice: true,
        assignedOfficeId: 'office-musaffah-m12-001',
        assignedOfficeName: 'Store - 12',
        isActive: true,
      ));
      _persistEmployees();
    }
    return List.unmodifiable(_employees);
  }

  void saveEmployee(EmployeeEntity employee) {
    int index = _employees.indexWhere((e) => e.id == employee.id);
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
    if (_attendanceRecords.isEmpty) {
      const String sampleBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-checkin',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: today.add(const Duration(hours: 8, minutes: 30)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 4.8,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-sitein',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.siteCheckIn,
        eventTimestamp: today.add(const Duration(hours: 10, minutes: 15)),
        latitude: 24.3648,
        longitude: 54.5032,
        gpsAccuracy: 5.5,
        address: 'M12 Industrial Area, Musaffah, Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        workSiteId: 'site-musaffah-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-sitedepart',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.siteCheckOut,
        eventTimestamp: today.add(const Duration(hours: 15, minutes: 45)),
        latitude: 24.3648,
        longitude: 54.5032,
        gpsAccuracy: 6.0,
        address: 'M12 Industrial Area, Musaffah, Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        workSiteId: 'site-musaffah-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-checkout',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.officeCheckOut,
        eventTimestamp: today.add(const Duration(hours: 17, minutes: 30)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 5.0,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-yest-checkin',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: yesterday.add(const Duration(hours: 8, minutes: 25)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 5.0,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-001-yest-checkout',
        employeeId: 'emp-001',
        employeeName: 'Irshath Ahamed',
        workflowStep: WorkflowStep.officeCheckOut,
        eventTimestamp: yesterday.add(const Duration(hours: 17, minutes: 35)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 5.0,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-ANDROID-9921',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      _attendanceRecords.add(AttendanceRecord(
        id: 'rec-002-checkin',
        employeeId: 'emp-002',
        employeeName: 'Sophia Martinez',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: today.add(const Duration(hours: 9, minutes: 0)),
        latitude: 24.3644,
        longitude: 54.5029,
        gpsAccuracy: 6.2,
        address: 'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi',
        deviceId: 'DEV-IPHONE-14PRO',
        photoBase64: sampleBase64,
        isGeofenceValid: true,
        officeId: 'office-musaffah-m12-001',
        syncStatus: SyncStatus.synced,
      ));

      _persistAttendanceRecords();
    }
    return List.unmodifiable(_attendanceRecords);
  }

  void addAttendanceRecord(AttendanceRecord record) {
    _attendanceRecords.add(record);
    if (record.workflowStep.nextStep != null) {
      _currentWorkflowStep = record.workflowStep.nextStep!;
    } else {
      _currentWorkflowStep = WorkflowStep.completed;
    }
    _persistAttendanceRecords();
  }

  WorkflowStep get currentWorkflowStep => _currentWorkflowStep;

  void resetWorkflowForNewDay() {
    _currentWorkflowStep = WorkflowStep.officeCheckIn;
  }

  List<AttendanceRecord> getPendingSyncRecords() {
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
}
