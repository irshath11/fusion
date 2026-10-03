import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/timesheet_calculator.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';
import 'package:attendance_app/database/local_database_service.dart';

void main() {
  group('Overnight Shift & Midnight Rollover Tests (TimesheetCalculator)', () {
    test('Overnight shift (2:00 PM to 1:00 AM next day) is unified under Day 1 anchor date without auto-checkout', () {
      final day1CheckIn = DateTime(2026, 10, 1, 14, 0); // Oct 1, 2:00 PM
      final day1SiteIn = DateTime(2026, 10, 1, 16, 0);  // Oct 1, 4:00 PM
      final day1SiteOut = DateTime(2026, 10, 1, 23, 0); // Oct 1, 11:00 PM
      final day2BreakStart = DateTime(2026, 10, 2, 0, 30); // Oct 2, 00:30 AM
      final day2BreakEnd = DateTime(2026, 10, 2, 0, 45);   // Oct 2, 00:45 AM
      final day2CheckOut = DateTime(2026, 10, 2, 1, 0);  // Oct 2, 1:00 AM (11h gross)

      final records = [
        AttendanceRecord(
          id: 'rec-in-1',
          employeeId: 'emp-night-1',
          employeeName: 'Night Worker',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: day1CheckIn,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-site-in-1',
          employeeId: 'emp-night-1',
          employeeName: 'Night Worker',
          workflowStep: WorkflowStep.siteCheckIn,
          eventTimestamp: day1SiteIn,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Al Dhafra Field Site',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          siteName: 'Al Dhafra Field Site',
        ),
        AttendanceRecord(
          id: 'rec-site-out-1',
          employeeId: 'emp-night-1',
          employeeName: 'Night Worker',
          workflowStep: WorkflowStep.siteCheckOut,
          eventTimestamp: day1SiteOut,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Al Dhafra Field Site',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          siteName: 'Al Dhafra Field Site',
        ),
        AttendanceRecord(
          id: 'rec-break-start-1',
          employeeId: 'emp-night-1',
          employeeName: 'Night Worker',
          workflowStep: WorkflowStep.breakStart,
          eventTimestamp: day2BreakStart,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Coffee Shop',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          siteName: 'Coffee Break',
        ),
        AttendanceRecord(
          id: 'rec-break-end-1',
          employeeId: 'emp-night-1',
          employeeName: 'Night Worker',
          workflowStep: WorkflowStep.breakEnd,
          eventTimestamp: day2BreakEnd,
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'Coffee Shop',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          siteName: 'Coffee Break',
        ),
        AttendanceRecord(
          id: 'rec-out-1',
          employeeId: 'emp-night-1',
          employeeName: 'Night Worker',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: day2CheckOut,
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

      // Exactly 1 entry anchored on 2026-10-01 (Day 1)
      expect(entries.length, 1);
      final entry = entries.first;

      expect(entry.date.year, 2026);
      expect(entry.date.month, 10);
      expect(entry.date.day, 1);

      // Shift is properly completed by the 1:00 AM check-out
      expect(entry.isCompleted, isTrue);
      expect(entry.isAutoCompleted, isFalse);

      // Times match check-in and check-out
      expect(entry.checkInTime, day1CheckIn);
      expect(entry.checkOutTime, day2CheckOut);

      // 11.0 hours gross (14:00 to 01:00)
      expect(entry.grossDuration, const Duration(hours: 11));
      // Standard UAE breakdown: 8.0 regular, 1.0 food break, 1.0 travel tolerance, 1.0 overtime
      expect(entry.regularHours, 8.0);
      expect(entry.breakHours, 1.0);
      expect(entry.travelToleranceHours, 1.0);
      expect(entry.overtimeHours, 1.0);
      expect(entry.totalHours, 9.0); // 8 regular + 1 OT
    });

    test('Two consecutive overnight shifts generate 2 distinct daily entries with no cross-contamination', () {
      // Shift 1: Oct 1, 14:00 to Oct 2, 01:00 (11h)
      // Shift 2: Oct 2, 14:00 to Oct 3, 01:00 (11h)
      final records = [
        // Shift 1
        AttendanceRecord(
          id: 's1-in',
          employeeId: 'emp-night-2',
          employeeName: 'Shift Worker',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 10, 1, 14, 0),
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 's1-out',
          employeeId: 'emp-night-2',
          employeeName: 'Shift Worker',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: DateTime(2026, 10, 2, 1, 0),
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Shift 2
        AttendanceRecord(
          id: 's2-in',
          employeeId: 'emp-night-2',
          employeeName: 'Shift Worker',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 10, 2, 14, 0),
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 's2-out',
          employeeId: 'emp-night-2',
          employeeName: 'Shift Worker',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: DateTime(2026, 10, 3, 1, 0),
          latitude: 24.36,
          longitude: 54.50,
          gpsAccuracy: 5.0,
          address: 'HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final entries = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(entries.length, 2);

      // Sorted descending or ascending
      final dates = entries.map((e) => '${e.date.month}-${e.date.day}').toList();
      expect(dates, containsAll(['10-1', '10-2']));

      for (final entry in entries) {
        expect(entry.isCompleted, isTrue);
        expect(entry.isAutoCompleted, isFalse);
        expect(entry.regularHours, 8.0);
        expect(entry.overtimeHours, 1.0);
      }
    });
  });

  group('Active Overnight Shift Continuity Tests (LocalDatabaseService)', () {
    test('Active shift started 10 hours ago crossing midnight remains in progress in getTodayAttendanceRecords', () {
      final db = LocalDatabaseService();
      final now = DateTime.now();
      // Checked in 10 hours ago (e.g. yesterday afternoon if now is early morning)
      final checkInTime = now.subtract(const Duration(hours: 10));
      final siteInTime = now.subtract(const Duration(hours: 6));

      final testUserEmpId = 'emp-overnight-test-active';

      final inRecord = AttendanceRecord(
        id: 'rec-test-night-in',
        employeeId: testUserEmpId,
        employeeName: 'Active Night Tester',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: checkInTime,
        latitude: 24.36,
        longitude: 54.50,
        gpsAccuracy: 5.0,
        address: 'HQ Office',
        deviceId: 'dev-test',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final siteRecord = AttendanceRecord(
        id: 'rec-test-night-site',
        employeeId: testUserEmpId,
        employeeName: 'Active Night Tester',
        workflowStep: WorkflowStep.siteCheckIn,
        eventTimestamp: siteInTime,
        latitude: 24.36,
        longitude: 54.50,
        gpsAccuracy: 5.0,
        address: 'Field Site Alpha',
        deviceId: 'dev-test',
        photoBase64: '',
        isGeofenceValid: true,
        siteName: 'Field Site Alpha',
      );

      db.addAttendanceRecord(inRecord);
      db.addAttendanceRecord(siteRecord);

      // Even across midnight, the active shift records must be returned!
      final activeRecords = db.getTodayAttendanceRecords(testUserEmpId);
      expect(activeRecords.isNotEmpty, isTrue);
      expect(activeRecords.length, greaterThanOrEqualTo(2));
      expect(activeRecords.first.workflowStep, WorkflowStep.officeCheckIn);

      // Workflow step must remain in progress (at site -> siteCheckOut)
      final currentStep = db.getWorkflowStepForEmployee(testUserEmpId);
      expect(currentStep, WorkflowStep.siteCheckOut);

      // Site status is recognized
      expect(db.isCurrentlyAtSite(testUserEmpId), isTrue);
      expect(db.getActiveSiteNameToday(testUserEmpId), 'Field Site Alpha');
    });

    test('Employee checks in at 2 PM Day 1, closes at 2 AM Day 2, and checks in at 2 PM Day 2 for Day 2 duty', () {
      final db = LocalDatabaseService();
      final empId = 'emp-consecutive-night';

      final day1In = DateTime.now().subtract(const Duration(hours: 24));
      final day2Out = DateTime.now().subtract(const Duration(hours: 12));

      // Day 1 shift: 2:00 PM Day 1 to 2:00 AM Day 2
      final recDay1In = AttendanceRecord(
        id: 'c-night-in-1',
        employeeId: empId,
        employeeName: 'Consecutive Tester',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: day1In,
        latitude: 24.36,
        longitude: 54.50,
        gpsAccuracy: 5.0,
        address: 'HQ',
        deviceId: 'dev-1',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final recDay2Out = AttendanceRecord(
        id: 'c-night-out-1',
        employeeId: empId,
        employeeName: 'Consecutive Tester',
        workflowStep: WorkflowStep.officeCheckOut,
        eventTimestamp: day2Out,
        latitude: 24.36,
        longitude: 54.50,
        gpsAccuracy: 5.0,
        address: 'HQ',
        deviceId: 'dev-1',
        photoBase64: '',
        isGeofenceValid: true,
      );

      db.addAttendanceRecord(recDay1In);
      db.addAttendanceRecord(recDay2Out);

      // Now at 2:00 PM on Day 2 (12 hours after 2:00 AM checkout):
      // The employee is ready to start Day 2 duty! Workflow step must be officeCheckIn
      final stepBeforeDay2 = db.getWorkflowStepForEmployee(empId);
      expect(stepBeforeDay2, WorkflowStep.officeCheckIn);

      // Employee checks in at 2:00 PM on Day 2
      final recDay2In = AttendanceRecord(
        id: 'c-night-in-2',
        employeeId: empId,
        employeeName: 'Consecutive Tester',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: DateTime.now(),
        latitude: 24.36,
        longitude: 54.50,
        gpsAccuracy: 5.0,
        address: 'HQ',
        deviceId: 'dev-1',
        photoBase64: '',
        isGeofenceValid: true,
      );
      db.addAttendanceRecord(recDay2In);

      // Now Day 2 shift is active!
      final stepAfterDay2In = db.getWorkflowStepForEmployee(empId);
      expect(stepAfterDay2In, WorkflowStep.siteCheckIn);

      final activeDay2Records = db.getTodayAttendanceRecords(empId);
      expect(activeDay2Records.length, 1);
      expect(activeDay2Records.first.id, 'c-night-in-2');
    });
  });
}
