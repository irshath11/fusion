import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/timesheet_calculator.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';
import 'package:attendance_app/database/local_database_service.dart';

void main() {
  group(
      'Auto Check-Out & 8-Hour Regular Time Capping Tests (TimesheetCalculator)',
      () {
    test('Active shift under 24 hours without checkout remains in progress',
        () {
      final now = DateTime.now();
      final checkInTime = now.subtract(const Duration(hours: 5));

      final records = [
        AttendanceRecord(
          id: 'rec-1',
          employeeId: 'emp-101',
          employeeName: 'Ahmed Ali',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: checkInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final entries = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(entries.length, 1);
      final entry = entries.first;

      expect(entry.isCompleted, isFalse);
      expect(entry.isAutoCompleted, isFalse);
      expect(entry.checkInTime, checkInTime);
      expect(entry.totalHours, greaterThanOrEqualTo(4.9));
      expect(entry.totalHours, lessThanOrEqualTo(5.1));
    });

    test(
        'Unclosed shift crossing 24 hours is automatically capped at 8.0 regular hours and 0.0 OT',
        () {
      final now = DateTime.now();
      // Ensure checkInTime does not fall on Sunday (which converts all hours to 100% OT)
      DateTime checkInTime = now.subtract(const Duration(hours: 26));
      if (checkInTime.weekday == DateTime.sunday) {
        checkInTime = now.subtract(const Duration(hours: 50));
      }

      final records = [
        AttendanceRecord(
          id: 'rec-2',
          employeeId: 'emp-102',
          employeeName: 'Fatima Khan',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: checkInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final entries = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(entries.length, 1);
      final entry = entries.first;

      // Must be marked completed and auto-completed
      expect(entry.isCompleted, isTrue);
      expect(entry.isAutoCompleted, isTrue);

      // Check-out time must be exactly 8 hours after check-in
      final expectedCheckOut = checkInTime.add(const Duration(hours: 8));
      expect(entry.checkOutTime, isNotNull);
      expect(entry.checkOutTime!.difference(checkInTime),
          const Duration(hours: 8));
      expect(entry.checkOutTime, expectedCheckOut);

      // Total duration must be exactly 8 hours
      expect(entry.totalDuration, const Duration(hours: 8));
      expect(entry.regularHours, 8.0);
      expect(entry.overtimeHours, 0.0);
    });

    test(
        'Unclosed shift crossing 48 hours is also capped at exactly 8.0 hours with 0 OT',
        () {
      final now = DateTime.now();
      DateTime checkInTime = now.subtract(const Duration(hours: 48));
      if (checkInTime.weekday == DateTime.sunday) {
        checkInTime = checkInTime.subtract(const Duration(hours: 24));
      }

      final records = [
        AttendanceRecord(
          id: 'rec-3',
          employeeId: 'emp-103',
          employeeName: 'Zaid Omar',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: checkInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final entries = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(entries.length, 1);
      final entry = entries.first;

      expect(entry.isCompleted, isTrue);
      expect(entry.isAutoCompleted, isTrue);
      expect(entry.regularHours, 8.0);
      expect(entry.overtimeHours, 0.0);
      expect(entry.totalDuration, const Duration(hours: 8));
    });

    test(
        'Normal completed shift with 10 hours work calculates 8.0 regular, 1.0 food break, 1.0 travel tolerance and 0.0 overtime',
        () {
      final checkInTime = DateTime(2026, 8, 10, 8, 0);
      final checkOutTime = DateTime(2026, 8, 10, 18, 0); // 10 hours

      final records = [
        AttendanceRecord(
          id: 'rec-4a',
          employeeId: 'emp-104',
          employeeName: 'John Doe',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: checkInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-4b',
          employeeId: 'emp-104',
          employeeName: 'John Doe',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: checkOutTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final entries = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(entries.length, 1);
      final entry = entries.first;

      expect(entry.isCompleted, isTrue);
      expect(entry.isAutoCompleted, isFalse);
      expect(entry.regularHours, 8.0);
      expect(entry.breakHours, 1.0);
      expect(entry.travelToleranceHours, 1.0);
      expect(entry.overtimeHours, 0.0);
      expect(entry.grossDuration, const Duration(hours: 10));
    });

    test(
        '11-hour shift (07:30 AM to 06:30 PM) calculates 8.0 regular, 1.0 food break, 1.0 travel tolerance and 1.0 overtime (OT starts after 10h)',
        () {
      final checkInTime = DateTime(2026, 8, 10, 7, 30); // 07:30 AM
      final checkOutTime =
          DateTime(2026, 8, 10, 18, 30); // 06:30 PM (11 hours gross)

      final records = [
        AttendanceRecord(
          id: 'rec-5a',
          employeeId: 'emp-105',
          employeeName: 'Sarah Smith',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: checkInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-5b',
          employeeId: 'emp-105',
          employeeName: 'Sarah Smith',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: checkOutTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final entries = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(entries.length, 1);
      final entry = entries.first;

      expect(entry.isCompleted, isTrue);
      expect(entry.isAutoCompleted, isFalse);
      expect(entry.regularHours, 8.0);
      expect(entry.breakHours, 1.0);
      expect(entry.travelToleranceHours, 1.0);
      expect(entry.overtimeHours, 1.0);
      expect(entry.grossDuration, const Duration(hours: 11));
    });

    test(
        '12-hour shift (06:45 AM to 06:45 PM) calculates 8.0 regular, 1.0 food break, 1.0 travel tolerance and 2.0 overtime hours',
        () {
      final checkInTime = DateTime(2026, 8, 10, 6, 45); // 06:45 AM
      final checkOutTime =
          DateTime(2026, 8, 10, 18, 45); // 06:45 PM (12 hours gross)

      final records = [
        AttendanceRecord(
          id: 'rec-6a',
          employeeId: 'emp-106',
          employeeName: 'John Doe',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: checkInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-6b',
          employeeId: 'emp-106',
          employeeName: 'John Doe',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: checkOutTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final entries = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(entries.length, 1);
      final entry = entries.first;

      expect(entry.isCompleted, isTrue);
      expect(entry.isAutoCompleted, isFalse);
      expect(entry.regularHours, 8.0);
      expect(entry.breakHours, 1.0);
      expect(entry.travelToleranceHours, 1.0);
      expect(entry.overtimeHours, 2.0);
      expect(entry.grossDuration, const Duration(hours: 12));
    });

    test(
        'Active shift with officeCheckIn and intermediate site visits under 24h remains in progress without auto check-out',
        () {
      final now = DateTime.now();
      final checkInTime = now.subtract(const Duration(hours: 6));
      final siteInTime = now.subtract(const Duration(hours: 4));
      final siteOutTime = now.subtract(const Duration(hours: 2));

      final records = [
        AttendanceRecord(
          id: 'rec-site-active-in',
          employeeId: 'emp-site-active',
          employeeName: 'Site Active Worker',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: checkInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-site-active-site-in',
          employeeId: 'emp-site-active',
          employeeName: 'Site Active Worker',
          workflowStep: WorkflowStep.siteCheckIn,
          eventTimestamp: siteInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Al Dhafra Site',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          siteName: 'Al Dhafra Site',
        ),
        AttendanceRecord(
          id: 'rec-site-active-site-out',
          employeeId: 'emp-site-active',
          employeeName: 'Site Active Worker',
          workflowStep: WorkflowStep.siteCheckOut,
          eventTimestamp: siteOutTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Al Dhafra Site',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          siteName: 'Al Dhafra Site',
        ),
      ];

      final entries = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(entries.length, 1);
      final entry = entries.first;

      // Under 24h, employee has not completed final officeCheckOut so shift is in progress
      expect(entry.isCompleted, isFalse);
      expect(entry.isAutoCompleted, isFalse);
      expect(entry.checkInTime, checkInTime);
      expect(entry.totalHours, greaterThanOrEqualTo(5.9));
      expect(entry.totalHours, lessThanOrEqualTo(6.1));
    });

    test(
        'Shift with officeCheckIn and intermediate site visits crossing 24h without officeCheckOut triggers auto check-out',
        () {
      final now = DateTime.now();
      DateTime checkInTime = now.subtract(const Duration(hours: 30));
      if (checkInTime.weekday == DateTime.sunday) {
        checkInTime = now.subtract(const Duration(hours: 54));
      }
      final siteInTime = checkInTime.add(const Duration(hours: 2));
      final siteOutTime = checkInTime.add(const Duration(hours: 5));

      final records = [
        AttendanceRecord(
          id: 'rec-site-expired-in',
          employeeId: 'emp-site-exp',
          employeeName: 'Site Expired Worker',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: checkInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-site-expired-site-in',
          employeeId: 'emp-site-exp',
          employeeName: 'Site Expired Worker',
          workflowStep: WorkflowStep.siteCheckIn,
          eventTimestamp: siteInTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Field Site',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          siteName: 'Field Site',
        ),
        AttendanceRecord(
          id: 'rec-site-expired-site-out',
          employeeId: 'emp-site-exp',
          employeeName: 'Site Expired Worker',
          workflowStep: WorkflowStep.siteCheckOut,
          eventTimestamp: siteOutTime,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Field Site',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          siteName: 'Field Site',
        ),
      ];

      final entries = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(entries.length, 1);
      final entry = entries.first;

      // Crossing 24 hours without final officeCheckOut: auto check-out capped at 8h
      expect(entry.isCompleted, isTrue);
      expect(entry.isAutoCompleted, isTrue);
      expect(entry.regularHours, 8.0);
      expect(entry.overtimeHours, 0.0);
      expect(entry.totalDuration, const Duration(hours: 8));
      expect(entry.checkOutTime, checkInTime.add(const Duration(hours: 8)));
    });
  });

  group('LocalDatabaseService autoResolveExpiredCheckIns Tests', () {
    test(
        'autoResolveExpiredCheckIns synthesizes officeCheckOut record at checkIn + 8 hours',
        () {
      final db = LocalDatabaseService();
      final now = DateTime.now();
      final oldCheckInTime = now.subtract(const Duration(hours: 30));

      final testRecord = AttendanceRecord(
        id: 'test-rec-auto-1',
        employeeId: 'emp-test-999',
        employeeName: 'Test Auto User',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: oldCheckInTime,
        latitude: 24.36,
        longitude: 54.50,
        gpsAccuracy: 5.0,
        address: 'Main Office HQ',
        deviceId: 'dev-test',
        photoBase64: '',
        isGeofenceValid: true,
      );

      db.addAttendanceRecord(testRecord);

      final resolvedCount = db.autoResolveExpiredCheckIns(force: true);
      expect(resolvedCount, greaterThanOrEqualTo(1));

      final allRecords = db.getAttendanceRecords();
      final autoCheckOutMatches = allRecords.where((r) =>
          r.employeeId == 'emp-test-999' &&
          r.workflowStep == WorkflowStep.officeCheckOut);

      expect(autoCheckOutMatches.isNotEmpty, isTrue);
      final autoRec = autoCheckOutMatches.first;
      expect(
          autoRec.eventTimestamp, oldCheckInTime.add(const Duration(hours: 8)));
      expect(autoRec.address, contains('Auto Check-Out'));
      expect(autoRec.syncStatus, SyncStatus.pending);

      // Subsequent call is idempotent (no duplicate created)
      final secondRunCount = db.autoResolveExpiredCheckIns(force: true);
      expect(secondRunCount, 0);
    });

    test(
        'autoResolveExpiredCheckIns does NOT synthesize checkout if under 24 hours from officeCheckIn',
        () {
      final db = LocalDatabaseService();
      final now = DateTime.now();
      final recentCheckInTime = now.subtract(const Duration(hours: 10));

      final testRecord = AttendanceRecord(
        id: 'test-rec-recent-1',
        employeeId: 'emp-test-recent-10h',
        employeeName: 'Recent User',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: recentCheckInTime,
        latitude: 24.36,
        longitude: 54.50,
        gpsAccuracy: 5.0,
        address: 'Main Office HQ',
        deviceId: 'dev-test',
        photoBase64: '',
        isGeofenceValid: true,
      );

      db.addAttendanceRecord(testRecord);

      final resolvedCount = db.autoResolveExpiredCheckIns(force: true);
      final allRecords = db.getAttendanceRecords();
      final autoCheckOutMatches = allRecords.where((r) =>
          r.employeeId == 'emp-test-recent-10h' &&
          r.workflowStep == WorkflowStep.officeCheckOut);

      // Under 24h: must NOT auto check-out
      expect(autoCheckOutMatches.isEmpty, isTrue);
    });

    test(
        'autoResolveExpiredCheckIns synthesizes checkout when officeCheckIn crossed 24h even if siteCheckOut occurred',
        () {
      final db = LocalDatabaseService();
      final now = DateTime.now();
      final oldCheckInTime = now.subtract(const Duration(hours: 28));

      final recIn = AttendanceRecord(
        id: 'test-rec-site-end-in',
        employeeId: 'emp-test-site-end',
        employeeName: 'Site End User',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: oldCheckInTime,
        latitude: 24.36,
        longitude: 54.50,
        gpsAccuracy: 5.0,
        address: 'Main Office HQ',
        deviceId: 'dev-test',
        photoBase64: '',
        isGeofenceValid: true,
      );
      final recSiteOut = AttendanceRecord(
        id: 'test-rec-site-end-out',
        employeeId: 'emp-test-site-end',
        employeeName: 'Site End User',
        workflowStep: WorkflowStep.siteCheckOut,
        eventTimestamp: oldCheckInTime.add(const Duration(hours: 4)),
        latitude: 24.36,
        longitude: 54.50,
        gpsAccuracy: 5.0,
        address: 'Field Site',
        deviceId: 'dev-test',
        photoBase64: '',
        isGeofenceValid: true,
        siteName: 'Field Site',
      );

      db.addAttendanceRecord(recIn);
      db.addAttendanceRecord(recSiteOut);

      final resolvedCount = db.autoResolveExpiredCheckIns(force: true);
      expect(resolvedCount, greaterThanOrEqualTo(1));

      final allRecords = db.getAttendanceRecords();
      final autoCheckOutMatches = allRecords.where((r) =>
          r.employeeId == 'emp-test-site-end' &&
          r.workflowStep == WorkflowStep.officeCheckOut);

      // Crossing 24h after office check-in with no final officeCheckOut: must synthesize auto checkout
      expect(autoCheckOutMatches.isNotEmpty, isTrue);
      expect(autoCheckOutMatches.first.eventTimestamp,
          oldCheckInTime.add(const Duration(hours: 8)));
    });
  });
}
