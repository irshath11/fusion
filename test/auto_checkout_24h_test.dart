import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/timesheet_calculator.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';
import 'package:attendance_app/database/local_database_service.dart';

void main() {
  group('Auto Check-Out & 8-Hour Regular Time Capping Tests (TimesheetCalculator)', () {
    test('Active shift under 24 hours without checkout remains in progress', () {
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

    test('Unclosed shift crossing 24 hours is automatically capped at 8.0 regular hours and 0.0 OT', () {
      final now = DateTime.now();
      // Checked in 26 hours ago
      final checkInTime = now.subtract(const Duration(hours: 26));

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
      expect(entry.checkOutTime!.difference(checkInTime), const Duration(hours: 8));
      expect(entry.checkOutTime, expectedCheckOut);

      // Total duration must be exactly 8 hours
      expect(entry.totalDuration, const Duration(hours: 8));
      expect(entry.regularHours, 8.0);
      expect(entry.overtimeHours, 0.0);
    });

    test('Unclosed shift crossing 48 hours is also capped at exactly 8.0 hours with 0 OT', () {
      final now = DateTime.now();
      final checkInTime = now.subtract(const Duration(hours: 48));

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

    test('Normal completed shift with 10 hours work calculates 8.0 regular and 2.0 overtime', () {
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
      expect(entry.overtimeHours, 2.0);
      expect(entry.totalDuration, const Duration(hours: 10));
    });
  });

  group('LocalDatabaseService autoResolveExpiredCheckIns Tests', () {
    test('autoResolveExpiredCheckIns synthesizes officeCheckOut record at checkIn + 8 hours', () {
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

      final resolvedCount = db.autoResolveExpiredCheckIns();
      expect(resolvedCount, greaterThanOrEqualTo(1));

      final allRecords = db.getAttendanceRecords();
      final autoCheckOutMatches = allRecords.where((r) =>
          r.employeeId == 'emp-test-999' &&
          r.workflowStep == WorkflowStep.officeCheckOut);

      expect(autoCheckOutMatches.isNotEmpty, isTrue);
      final autoRec = autoCheckOutMatches.first;
      expect(autoRec.eventTimestamp, oldCheckInTime.add(const Duration(hours: 8)));
      expect(autoRec.address, contains('Auto Check-Out'));
      expect(autoRec.syncStatus, SyncStatus.pending);

      // Subsequent call is idempotent (no duplicate created)
      final secondRunCount = db.autoResolveExpiredCheckIns();
      expect(secondRunCount, 0);
    });
  });
}
