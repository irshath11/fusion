import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/database/local_database_service.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/features/auth/domain/user_entity.dart';
import 'package:attendance_app/features/admin/domain/employee_entity.dart';
import 'package:attendance_app/features/admin/domain/office_entity.dart';
import 'package:attendance_app/core/utils/geofence_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Geofence Enable/Disable & Bypass Validation Tests', () {
    late LocalDatabaseService db;

    final testOffice = OfficeEntity(
      id: 'off-hq-1',
      name: 'Main HQ Office',
      address: 'Abu Dhabi HQ',
      latitude: 24.365500,
      longitude: 54.500531,
      geofenceRadiusMeters: 200.0,
      isDefault: true,
    );

    final userWithGeofenceEnforced = UserEntity(
      id: 'usr-emp-101',
      firebaseUid: 'usr-emp-101',
      organizationId: 'org-test-1',
      email: 'employee101@company.com',
      fullName: 'Field Worker One',
      role: UserRole.employee,
      employeeCode: 'EMP-101',
      useDefaultOffice: true,
      bypassGeofence: false, // Geofence is ENFORCED
    );

    final empWithGeofenceEnforced = EmployeeEntity(
      id: 'usr-emp-101',
      employeeCode: 'EMP-101',
      name: 'Field Worker One',
      mobileNumber: '0501234567',
      email: 'employee101@company.com',
      designation: 'Field Engineer',
      department: 'Operations',
      useDefaultOffice: true,
      bypassGeofence: false,
    );

    setUp(() {
      db = LocalDatabaseService();
      db.clearAttendanceCache();
      db.setOffices([testOffice]);
      db.setUsers([userWithGeofenceEnforced]);
      db.setEmployees([empWithGeofenceEnforced]);
      db.setCurrentUser(userWithGeofenceEnforced);
    });

    test('Distance calculation correctly detects location outside 200m office radius', () {
      // 5km away from HQ
      const double farLatitude = 24.410000;
      const double farLongitude = 54.550000;

      final distance = GeofenceCalculator.calculateDistanceInMeters(
        farLatitude,
        farLongitude,
        testOffice.latitude,
        testOffice.longitude,
      );

      expect(distance, greaterThan(testOffice.geofenceRadiusMeters));
      expect(distance <= testOffice.geofenceRadiusMeters, isFalse);
    });

    test('When Geofence is ENFORCED (bypass: false), override returns false and check-in is restricted', () {
      db.toggleEmployeeGeofenceBypass(
        userWithGeofenceEnforced.id,
        false, // Enforce
        email: userWithGeofenceEnforced.email,
        employeeCode: userWithGeofenceEnforced.employeeCode,
        employeeName: userWithGeofenceEnforced.fullName,
      );

      final override = db.getGeofenceOverride(
        userId: userWithGeofenceEnforced.id,
        email: userWithGeofenceEnforced.email,
        employeeCode: userWithGeofenceEnforced.employeeCode,
        name: userWithGeofenceEnforced.fullName,
      );

      expect(override, isFalse);

      final effectiveUser = db.currentUser;
      expect(effectiveUser?.bypassGeofence, isFalse);

      // Verify the formula: override ?? (emp.bypassGeofence || user.bypassGeofence)
      final bool isGeofenceBypassed = override ?? (empWithGeofenceEnforced.bypassGeofence || userWithGeofenceEnforced.bypassGeofence);
      expect(isGeofenceBypassed, isFalse);
    });

    test('When Geofence is DISABLED (bypass: true), override returns true and anywhere check-in is allowed', () {
      db.toggleEmployeeGeofenceBypass(
        userWithGeofenceEnforced.id,
        true, // Disable geofence / Allow anywhere
        email: userWithGeofenceEnforced.email,
        employeeCode: userWithGeofenceEnforced.employeeCode,
        employeeName: userWithGeofenceEnforced.fullName,
      );

      final override = db.getGeofenceOverride(
        userId: userWithGeofenceEnforced.id,
        email: userWithGeofenceEnforced.email,
        employeeCode: userWithGeofenceEnforced.employeeCode,
        name: userWithGeofenceEnforced.fullName,
      );

      expect(override, isTrue);

      final effectiveUser = db.currentUser;
      expect(effectiveUser?.bypassGeofence, isTrue);

      final bool isGeofenceBypassed = override ?? (empWithGeofenceEnforced.bypassGeofence || userWithGeofenceEnforced.bypassGeofence);
      expect(isGeofenceBypassed, isTrue);
    });

    test('Toggling from Disabled back to Enforced immediately enforces geofence without getting stuck on true', () {
      // 1. First disable geofence (allow anywhere)
      db.toggleEmployeeGeofenceBypass(
        userWithGeofenceEnforced.id,
        true,
        email: userWithGeofenceEnforced.email,
        employeeCode: userWithGeofenceEnforced.employeeCode,
        employeeName: userWithGeofenceEnforced.fullName,
      );
      expect(db.currentUser?.bypassGeofence, isTrue);

      // 2. Now re-enable / enforce geofence
      db.toggleEmployeeGeofenceBypass(
        userWithGeofenceEnforced.id,
        false,
        email: userWithGeofenceEnforced.email,
        employeeCode: userWithGeofenceEnforced.employeeCode,
        employeeName: userWithGeofenceEnforced.fullName,
      );

      final override = db.getGeofenceOverride(
        userId: userWithGeofenceEnforced.id,
        email: userWithGeofenceEnforced.email,
        employeeCode: userWithGeofenceEnforced.employeeCode,
        name: userWithGeofenceEnforced.fullName,
      );
      expect(override, isFalse);
      expect(db.currentUser?.bypassGeofence, isFalse);

      final bool isGeofenceBypassed = override ?? (empWithGeofenceEnforced.bypassGeofence || userWithGeofenceEnforced.bypassGeofence);
      expect(isGeofenceBypassed, isFalse);
    });

    test('Cloud sync preserves bypassGeofence when setEmployees and setUsers are populated', () {
      final remoteEmp = EmployeeEntity(
        id: 'usr-emp-remote',
        employeeCode: 'EMP-REMOTE',
        name: 'Remote Staff',
        mobileNumber: '0559998877',
        email: 'remote@company.com',
        designation: 'Specialist',
        department: 'Operations',
        useDefaultOffice: true,
        bypassGeofence: true, // Remote employee has bypass
      );

      db.setEmployees([remoteEmp]);

      final employees = db.getEmployees();
      final emp = employees.firstWhere((e) => e.id == 'usr-emp-remote');
      expect(emp.bypassGeofence, isTrue);

      final override = db.getGeofenceOverride(
        userId: 'usr-emp-remote',
        email: 'remote@company.com',
        employeeCode: 'EMP-REMOTE',
        name: 'Remote Staff',
      );
      expect(override, isTrue);
    });
  });
}
