import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/timesheet_calculator.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';

void main() {
  group('Emergency Duty Calculation Tests', () {
    test('Calculates Emergency Duty hours as 100% overtime hours', () {
      final baseDate = DateTime(2026, 8, 15, 20, 0); // 08:00 PM Emergency Callout

      final records = [
        AttendanceRecord(
          id: 'emg-1',
          employeeId: 'emp-101',
          employeeName: 'Charlie',
          workflowStep: WorkflowStep.emergencyCheckIn,
          eventTimestamp: baseDate,
          siteName: 'Emergency Site Callout - Electrical Substation',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Substation B',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          remarks: 'Emergency Substation Repair',
        ),
        AttendanceRecord(
          id: 'emg-2',
          employeeId: 'emp-101',
          employeeName: 'Charlie',
          workflowStep: WorkflowStep.emergencyCheckOut,
          eventTimestamp: baseDate.add(const Duration(hours: 3)), // 11:00 PM
          siteName: 'Emergency Site Callout - Electrical Substation',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Substation B',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
          remarks: 'Emergency Substation Repair Completed',
        ),
      ];

      final timesheets = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(timesheets.length, 1);

      final entry = timesheets.first;
      expect(entry.emergencyDutyHours, 3.0);
      expect(entry.overtimeHours, 3.0);
    });

    test('WorkflowStep extension correctly maps emergency steps', () {
      expect(WorkflowStep.emergencyCheckIn.dbValue, 'EMERGENCY_CHECK_IN');
      expect(WorkflowStep.emergencyCheckOut.dbValue, 'EMERGENCY_CHECK_OUT');
      expect(WorkflowStep.emergencyCheckIn.displayName, 'Emergency Duty Check-In');
      expect(WorkflowStep.emergencyCheckOut.displayName, 'Emergency Duty Check-Out');
      expect(WorkflowStep.emergencyCheckIn.nextStep, WorkflowStep.emergencyCheckOut);
      expect(WorkflowStep.emergencyCheckOut.nextStep, WorkflowStep.completed);
      expect(WorkflowStepExtension.fromString('emergencyCheckIn'), WorkflowStep.emergencyCheckIn);
      expect(WorkflowStepExtension.fromString('emergencyCheckOut'), WorkflowStep.emergencyCheckOut);
      expect(WorkflowStepExtension.fromString('EMERGENCY_CHECK_IN'), WorkflowStep.emergencyCheckIn);
      expect(WorkflowStepExtension.fromString('EMERGENCY_CHECK_OUT'), WorkflowStep.emergencyCheckOut);
    });

    test('Combines regular working hours with emergency callout overtime', () {
      final workDate = DateTime(2026, 8, 15, 8, 0); // 8:00 AM Check-In

      final records = [
        // Regular Shift (8:00 AM to 5:00 PM = 9 gross hours, net 8 regular, 1 break)
        AttendanceRecord(
          id: 'rec-1',
          employeeId: 'emp-101',
          employeeName: 'Charlie',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: workDate,
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-2',
          employeeId: 'emp-101',
          employeeName: 'Charlie',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: workDate.add(const Duration(hours: 9)),
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Emergency Callout Duty at Night (9:00 PM to 11:30 PM = 2.5 hours)
        AttendanceRecord(
          id: 'rec-3',
          employeeId: 'emp-101',
          employeeName: 'Charlie',
          workflowStep: WorkflowStep.emergencyCheckIn,
          eventTimestamp: workDate.add(const Duration(hours: 13)), // 9:00 PM
          siteName: 'Emergency Generator Failure - Hospital',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Hospital Ward C',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-4',
          employeeId: 'emp-101',
          employeeName: 'Charlie',
          workflowStep: WorkflowStep.emergencyCheckOut,
          eventTimestamp: workDate.add(const Duration(hours: 15, minutes: 30)), // 11:30 PM
          siteName: 'Emergency Generator Failure - Hospital',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Hospital Ward C',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final timesheets = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(timesheets.length, 1);

      final entry = timesheets.first;
      expect(entry.regularHours, 8.0);
      expect(entry.emergencyDutyHours, 2.5);
      expect(entry.overtimeHours, 2.5); // 100% of emergency duty is OT
      expect(entry.totalHours, 10.5);
    });

    test('Editing an emergency log updates hours, remarks, and sets isEdited flag', () {
      final baseDate = DateTime(2026, 8, 15, 20, 0); // 08:00 PM

      final originalIn = AttendanceRecord(
        id: 'emg-1',
        employeeId: 'emp-101',
        employeeName: 'Charlie',
        workflowStep: WorkflowStep.emergencyCheckIn,
        eventTimestamp: baseDate,
        siteName: 'Substation B',
        latitude: 25.2048,
        longitude: 55.2708,
        gpsAccuracy: 5.0,
        address: 'Substation B',
        deviceId: 'dev-1',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final originalOut = AttendanceRecord(
        id: 'emg-2',
        employeeId: 'emp-101',
        employeeName: 'Charlie',
        workflowStep: WorkflowStep.emergencyCheckOut,
        eventTimestamp: baseDate.add(const Duration(hours: 2)), // 10:00 PM (2 hours)
        siteName: 'Substation B',
        latitude: 25.2048,
        longitude: 55.2708,
        gpsAccuracy: 5.0,
        address: 'Substation B',
        deviceId: 'dev-1',
        photoBase64: '',
        isGeofenceValid: true,
      );

      // Initial timesheet calculation
      var timesheets = TimesheetCalculator.calculateDailyTimesheets([originalIn, originalOut]);
      expect(timesheets.first.emergencyDutyHours, 2.0);
      expect(timesheets.first.overtimeHours, 2.0);
      expect(timesheets.first.isEdited, false);

      // Simulate Admin editing the emergency log: extended to 3.5 hours, updated site and added remarks
      final newOutTime = baseDate.add(const Duration(hours: 3, minutes: 30));
      final updatedIn = originalIn.copyWith(
        siteName: 'Substation B - High Voltage Transformer',
        address: 'Substation B - High Voltage Transformer',
        remarks: 'Extended emergency shift approved by Admin',
        isEdited: true,
        editedBy: 'Admin',
      );
      final updatedOut = originalOut.copyWith(
        eventTimestamp: newOutTime,
        siteName: 'Substation B - High Voltage Transformer',
        address: 'Substation B - High Voltage Transformer',
        remarks: 'Extended emergency shift approved by Admin',
        isEdited: true,
        editedBy: 'Admin',
      );

      expect(updatedIn.isEdited, true);
      expect(updatedIn.editedBy, 'Admin');
      expect(updatedIn.siteName, 'Substation B - High Voltage Transformer');
      expect(updatedOut.isEdited, true);

      // Recalculate timesheets with edited emergency duty records
      timesheets = TimesheetCalculator.calculateDailyTimesheets([updatedIn, updatedOut]);
      expect(timesheets.first.emergencyDutyHours, 3.5);
      expect(timesheets.first.overtimeHours, 3.5);
      expect(timesheets.first.isEdited, true);
      expect(timesheets.first.totalHours, 3.5);
    });
  });
}
