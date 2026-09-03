import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/timesheet_calculator.dart';
import 'package:attendance_app/features/admin/domain/employee_entity.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';

void main() {
  group('Employee Attendance Attribution & Timesheet Tests', () {
    final shabi = EmployeeEntity(
      id: 'emp-shabi-001',
      employeeCode: 'EMP001',
      name: 'Shabi',
      mobileNumber: '1234567890',
      email: 'shabi@test.com',
      designation: 'Technician',
      department: 'Operations',
    );

    final anandh = EmployeeEntity(
      id: 'emp-anand-002',
      employeeCode: 'EMP-ANA',
      name: 'Anandh Veeramani',
      mobileNumber: '9876543210',
      email: 'anand@gmail.com',
      designation: 'Supervisor',
      department: 'Field Engineering',
    );

    test('Strict matching ensures Shabi and Anandh records do not cross-contaminate', () {
      final now = DateTime(2026, 9, 3, 8, 0);

      final shabiCheckIn = AttendanceRecord(
        id: 'rec-1',
        employeeId: shabi.id,
        employeeName: shabi.name,
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Site A',
        deviceId: 'device-hw-shabi',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final anandhCheckIn = AttendanceRecord(
        id: 'rec-2',
        employeeId: anandh.id,
        employeeName: anandh.name,
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now.add(const Duration(minutes: 15)),
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Site B',
        deviceId: 'device-hw-anand',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final allRecords = [shabiCheckIn, anandhCheckIn];

      // Verify TimesheetCalculator separates records strictly
      final shabiTimesheets = TimesheetCalculator.calculateDailyTimesheets(
        allRecords.where((r) => r.employeeId == shabi.id).toList(),
      );
      final anandhTimesheets = TimesheetCalculator.calculateDailyTimesheets(
        allRecords.where((r) => r.employeeId == anandh.id).toList(),
      );

      expect(shabiTimesheets.length, 1);
      expect(anandhTimesheets.length, 1);
      expect(shabiTimesheets.first.date, DateTime(2026, 9, 3));
      expect(anandhTimesheets.first.date, DateTime(2026, 9, 3));
    });

    test('Reassigning records from Shabi to Anandh updates identity and timesheet correctly', () {
      final checkInTime = DateTime(2026, 9, 3, 8, 0);
      final checkOutTime = DateTime(2026, 9, 3, 17, 0);

      final misattributedCheckIn = AttendanceRecord(
        id: 'rec-mis-in',
        employeeId: shabi.id,
        employeeName: shabi.name,
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: checkInTime,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Substation Alpha',
        deviceId: 'device-hw-${anandh.id}',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final misattributedCheckOut = AttendanceRecord(
        id: 'rec-mis-out',
        employeeId: shabi.id,
        employeeName: shabi.name,
        workflowStep: WorkflowStep.officeCheckOut,
        eventTimestamp: checkOutTime,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Substation Alpha',
        deviceId: 'device-hw-${anandh.id}',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final records = [misattributedCheckIn, misattributedCheckOut];

      final reassignedRecords = records.map((r) {
        return r.copyWith(
          employeeId: anandh.id,
          employeeName: anandh.name,
          isEdited: true,
          editedBy: 'Admin Reassignment',
        );
      }).toList();

      for (final r in reassignedRecords) {
        expect(r.employeeId, anandh.id);
        expect(r.employeeName, anandh.name);
        expect(r.isEdited, isTrue);
        expect(r.editedBy, 'Admin Reassignment');
      }

      final anandhTimesheets = TimesheetCalculator.calculateDailyTimesheets(reassignedRecords);
      expect(anandhTimesheets.length, 1);
      expect(anandhTimesheets.first.regularHours, 8.0);
    });

    test('Consolidating legacy "Anand" records into Anandh Veeramani preserves all dates under Anandh', () {
      final day1 = DateTime(2026, 8, 1, 8, 0);
      final day2 = DateTime(2026, 8, 2, 8, 0);

      // Legacy record with short name "Anand" and fallback code
      final legacyRec = AttendanceRecord(
        id: 'rec-legacy-1',
        employeeId: 'emp-anan',
        employeeName: 'Anand',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: day1,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Site A',
        deviceId: 'device-hw-${anandh.id}',
        photoBase64: '',
        isGeofenceValid: true,
      );

      // Official record under "Anandh Veeramani"
      final officialRec = AttendanceRecord(
        id: 'rec-official-2',
        employeeId: anandh.id,
        employeeName: anandh.name,
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: day2,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Site B',
        deviceId: 'device-hw-${anandh.id}',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final allRecords = [legacyRec, officialRec];

      // Simulated migration: consolidate 'Anand' records into 'Anandh Veeramani'
      final consolidated = allRecords.map((r) {
        if (r.employeeName.toLowerCase() == 'anand' || r.employeeId == 'emp-anan') {
          return r.copyWith(
            employeeId: anandh.id,
            employeeName: anandh.name,
            isEdited: true,
            editedBy: 'System Consolidation',
          );
        }
        return r;
      }).toList();

      // All records are now under Anandh Veeramani
      for (final r in consolidated) {
        expect(r.employeeId, anandh.id);
        expect(r.employeeName, 'Anandh Veeramani');
      }

      final timesheets = TimesheetCalculator.calculateDailyTimesheets(consolidated);
      expect(timesheets.length, 2);
    });
  });
}
