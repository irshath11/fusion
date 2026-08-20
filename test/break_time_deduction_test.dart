import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/timesheet_calculator.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';

void main() {
  group('Break Option & Work Hour Calculation Tests', () {
    test('Calculates gross hours and deducts break duration correctly', () {
      final baseDate = DateTime(2026, 8, 13, 8, 0); // 08:00 AM

      final records = [
        // Office Check-In at 08:00
        AttendanceRecord(
          id: 'rec-1',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: baseDate,
          siteName: 'Main Office',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Break Start (Lunch) at 12:00 PM
        AttendanceRecord(
          id: 'rec-2',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.breakStart,
          eventTimestamp: baseDate.add(const Duration(hours: 4)), // 12:00 PM
          siteName: 'Lunch Break',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Lunch Area',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Break End at 01:00 PM (1 hour break)
        AttendanceRecord(
          id: 'rec-3',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.breakEnd,
          eventTimestamp: baseDate.add(const Duration(hours: 5)), // 01:00 PM
          siteName: 'Lunch Break',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Lunch Area',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Office Check-Out at 06:00 PM (10 hours gross: 08:00 to 18:00)
        AttendanceRecord(
          id: 'rec-4',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: baseDate.add(const Duration(hours: 10)), // 06:00 PM
          siteName: 'Main Office',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final timesheets = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(timesheets.length, 1);

      final entry = timesheets.first;
      // Gross time: 10.0 hours
      expect(entry.grossDuration.inMinutes, 600);
      // Food Break duration: 1 hour default (60 minutes)
      expect(entry.breakDuration.inMinutes, 60);
      expect(entry.breakHours, 1.0);
      // Travel Tolerance duration: 1 hour (60 minutes)
      expect(entry.travelToleranceDuration.inMinutes, 60);
      expect(entry.travelToleranceHours, 1.0);
      // Net working time (regular + OT): 8.0 hours
      expect(entry.totalHours, 8.0);
      // Regular hours: 8.0 hours
      expect(entry.regularHours, 8.0);
      // Overtime hours: 0.0 hours (OT starts after 10 gross hours)
      expect(entry.overtimeHours, 0.0);
    });

    test('Deducts break time overlapping with site visit from site man-hours', () {
      final baseDate = DateTime(2026, 8, 13, 8, 0); // 08:00 AM

      final records = [
        AttendanceRecord(
          id: 'rec-1',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: baseDate,
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Site Check-In at Site Alpha at 09:00 AM
        AttendanceRecord(
          id: 'rec-2',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.siteCheckIn,
          eventTimestamp: baseDate.add(const Duration(hours: 1)), // 09:00 AM
          siteName: 'Site Alpha (Dubai Mall)',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Site Alpha (Dubai Mall)',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Break Start during site visit at 12:00 PM
        AttendanceRecord(
          id: 'rec-3',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.breakStart,
          eventTimestamp: baseDate.add(const Duration(hours: 4)), // 12:00 PM
          siteName: 'Lunch Break',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Dubai Mall Food Court',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Break End at 12:45 PM (45 min break)
        AttendanceRecord(
          id: 'rec-4',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.breakEnd,
          eventTimestamp: baseDate.add(const Duration(minutes: 285)), // 12:45 PM
          siteName: 'Lunch Break',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Dubai Mall Food Court',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Site Check-Out at Site Alpha at 02:00 PM (Gross site stay: 5 hours, from 09:00 to 14:00)
        AttendanceRecord(
          id: 'rec-5',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.siteCheckOut,
          eventTimestamp: baseDate.add(const Duration(hours: 6)), // 02:00 PM
          siteName: 'Site Alpha (Dubai Mall)',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Site Alpha (Dubai Mall)',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Office Check-Out at 05:00 PM (08:00 to 17:00 = 9 gross hours, minus 45m break = 8.25 net hours)
        AttendanceRecord(
          id: 'rec-6',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: baseDate.add(const Duration(hours: 9)), // 05:00 PM
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final siteSummaries = TimesheetCalculator.calculateSiteManHours(records);
      expect(siteSummaries.length, 1);

      final siteAlpha = siteSummaries.first;
      expect(siteAlpha.siteName, 'Site Alpha (Dubai Mall)');
      // Gross site stay: 5.0 hours (300 mins)
      // Break taken during site visit: 45 mins (0.75 hours)
      // Net site man-hours: 5.0 - 0.75 = 4.25 hours
      expect(siteAlpha.totalHours, 4.25);
    });

    test('Multiple breaks in a single day accumulate properly', () {
      final baseDate = DateTime(2026, 8, 13, 8, 0); // 08:00 AM

      final records = [
        AttendanceRecord(
          id: 'rec-1',
          employeeId: 'emp-1',
          employeeName: 'Bob',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: baseDate,
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Tea Break: 10:00 - 10:15 (15 mins)
        AttendanceRecord(
          id: 'rec-2',
          employeeId: 'emp-1',
          employeeName: 'Bob',
          workflowStep: WorkflowStep.breakStart,
          eventTimestamp: baseDate.add(const Duration(hours: 2)), // 10:00 AM
          siteName: 'Tea Break',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Pantry / Break Area',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-3',
          employeeId: 'emp-1',
          employeeName: 'Bob',
          workflowStep: WorkflowStep.breakEnd,
          eventTimestamp: baseDate.add(const Duration(minutes: 135)), // 10:15 AM
          siteName: 'Tea Break',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Pantry / Break Area',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Lunch Break: 12:30 - 13:15 (45 mins)
        AttendanceRecord(
          id: 'rec-4',
          employeeId: 'emp-1',
          employeeName: 'Bob',
          workflowStep: WorkflowStep.breakStart,
          eventTimestamp: baseDate.add(const Duration(minutes: 270)), // 12:30 PM
          siteName: 'Lunch Break',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Cafeteria',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-5',
          employeeId: 'emp-1',
          employeeName: 'Bob',
          workflowStep: WorkflowStep.breakEnd,
          eventTimestamp: baseDate.add(const Duration(minutes: 315)), // 01:15 PM
          siteName: 'Lunch Break',
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Cafeteria',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        // Office Check-Out at 17:00 (9.0 gross hours)
        AttendanceRecord(
          id: 'rec-6',
          employeeId: 'emp-1',
          employeeName: 'Bob',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: baseDate.add(const Duration(hours: 9)), // 05:00 PM
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 5.0,
          address: 'Main Office HQ',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final timesheets = TimesheetCalculator.calculateDailyTimesheets(records);
      expect(timesheets.length, 1);

      final entry = timesheets.first;
      // Total break = 15m + 45m = 60m (1.0 hour)
      expect(entry.breakDuration.inMinutes, 60);
      expect(entry.breakHours, 1.0);
      // Gross = 9.0h, Net = 8.0h
      expect(entry.totalHours, 8.0);
      expect(entry.regularHours, 8.0);
      expect(entry.overtimeHours, 0.0);
    });
  });
}

