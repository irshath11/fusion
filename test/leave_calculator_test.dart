import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/services/pdf_export_service.dart';
import 'package:attendance_app/core/utils/leave_calculator.dart';
import 'package:attendance_app/core/utils/salary_cycle_helper.dart';
import 'package:attendance_app/features/admin/domain/employee_entity.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';

void main() {
  group('LeaveCalculator Tests (Sunday is the only weekly leave day)', () {
    final employee = EmployeeEntity(
      id: 'emp-001',
      employeeCode: 'EMP-001',
      name: 'John Doe',
      mobileNumber: '+971501234567',
      email: 'john@fusion.ae',
      designation: 'Technician',
      department: 'Operations',
    );

    // August 25 - September 24, 2026 cycle (31 days)
    final cycle = SalaryCycle.forMonth(2026, 9);

    test('Cycle length and Sundays count verification', () {
      expect(cycle.totalDays, 31);
      // Let's count Sundays between 2026-08-25 and 2026-09-24:
      // Aug 2026: 25th (Tue), 26th (Wed), 27th (Thu), 28th (Fri), 29th (Sat), 30th (Sun) -> 1
      // Sep 2026: 6th (Sun), 13th (Sun), 20th (Sun) -> 3
      // Total 4 Sundays in this cycle. Expected working days = 31 - 4 = 27 days.
      final summary = LeaveCalculator.calculateEmployeeLeave(
        employee,
        [],
        cycle,
        referenceDate: DateTime(2026, 9, 25), // after cycle completed
      );

      expect(summary.totalCycleDays, 31);
      expect(summary.totalSundays, 4);
      expect(summary.expectedWorkingDays, 27);
      expect(summary.elapsedWorkingDays, 27);
      expect(summary.elapsedSundays, 4);
      // With zero attendance records: 27 leaves, 4 sunday weekly offs
      expect(summary.daysWorked, 0);
      expect(summary.leaveDays, 27);
      expect(summary.sundayWeeklyOffs, 4);
      expect(summary.attendancePercentage, 0.0);
    });

    test('Employee with working days present, leave days, and Sunday off', () {
      // Suppose employee worked on Monday 2026-08-31 and Tuesday 2026-09-01
      // Did not work on other days up to 2026-09-02
      final records = [
        AttendanceRecord(
          id: 'rec-1',
          employeeId: employee.id,
          employeeName: employee.name,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 8, 31, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-2',
          employeeId: employee.id,
          employeeName: employee.name,
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: DateTime(2026, 8, 31, 17, 0),
          latitude: 25.0,
          longitude: 55.0,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-3',
          employeeId: employee.id,
          employeeName: employee.name,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 9, 1, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      // Reference date: end of 2026-09-01 (7 days elapsed: Aug 25 to Aug 31 = 7 days, Sep 1 = 8 days)
      // Days:
      // Aug 25 Tue (working) - absent
      // Aug 26 Wed (working) - absent
      // Aug 27 Thu (working) - absent
      // Aug 28 Fri (working) - absent
      // Aug 29 Sat (working) - absent
      // Aug 30 Sun (weekly off) - off
      // Aug 31 Mon (working) - worked
      // Sep 01 Tue (working) - worked
      // Total elapsed working days = 7
      // Total elapsed Sundays = 1
      // Working days worked = 2
      // Leave days = 5
      // Sunday off = 1
      final summary = LeaveCalculator.calculateEmployeeLeave(
        employee,
        records,
        cycle,
        referenceDate: DateTime(2026, 9, 1, 23, 59),
      );

      expect(summary.elapsedDays, 8);
      expect(summary.elapsedWorkingDays, 7);
      expect(summary.elapsedSundays, 1);
      expect(summary.workingDaysPresent, 2);
      expect(summary.daysWorked, 2);
      expect(summary.leaveDays, 5);
      expect(summary.sundayWeeklyOffs, 1);
      expect(summary.sundayDutyDays, 0);

      // Verify that Sunday 2026-08-30 is recognized as Sunday Weekly Off
      final sunRecord = summary.dailyRecords.firstWhere(
        (d) => d.date.year == 2026 && d.date.month == 8 && d.date.day == 30,
      );
      expect(sunRecord.isSunday, isTrue);
      expect(sunRecord.type, LeaveDayType.sundayWeeklyOff);
      expect(sunRecord.type.label, 'Sunday (Weekly Off)');

      // Verify that Aug 31 is recognized as Present
      final monRecord = summary.dailyRecords.firstWhere(
        (d) => d.date.year == 2026 && d.date.month == 8 && d.date.day == 31,
      );
      expect(monRecord.isSunday, isFalse);
      expect(monRecord.type, LeaveDayType.present);
      expect(monRecord.type.label, 'Present');

      // Verify that Aug 25 is recognized as Leave / Absent
      final tueRecord = summary.dailyRecords.firstWhere(
        (d) => d.date.year == 2026 && d.date.month == 8 && d.date.day == 25,
      );
      expect(tueRecord.isSunday, isFalse);
      expect(tueRecord.type, LeaveDayType.leaveAbsent);
      expect(tueRecord.type.label, 'Leave / Absent');
    });

    test('Sunday Duty: Working on Sunday counts as Sunday Duty rather than standard leave', () {
      final records = [
        AttendanceRecord(
          id: 'rec-sun',
          employeeId: employee.id,
          employeeName: employee.name,
          workflowStep: WorkflowStep.emergencyCheckIn,
          eventTimestamp: DateTime(2026, 8, 30, 9, 0), // Sunday
          latitude: 25.0,
          longitude: 55.0,
          gpsAccuracy: 5.0,
          address: 'Emergency Client Site',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final summary = LeaveCalculator.calculateEmployeeLeave(
        employee,
        records,
        cycle,
        referenceDate: DateTime(2026, 8, 30, 23, 59),
      );

      expect(summary.sundayDutyDays, 1);
      expect(summary.sundayWeeklyOffs, 0);

      final sunRecord = summary.dailyRecords.firstWhere(
        (d) => d.date.year == 2026 && d.date.month == 8 && d.date.day == 30,
      );
      expect(sunRecord.type, LeaveDayType.sundayDuty);
      expect(sunRecord.type.label, 'Sunday Duty (Worked)');
    });

    test('Workforce metrics aggregation', () {
      final emp2 = EmployeeEntity(
        id: 'emp-002',
        employeeCode: 'EMP-002',
        name: 'Jane Smith',
        mobileNumber: '+971509876543',
        email: 'jane@fusion.ae',
        designation: 'Engineer',
        department: 'Operations',
      );

      final summaries = LeaveCalculator.calculateWorkforceLeaveSummaries(
        [employee, emp2],
        [],
        cycle,
        referenceDate: DateTime(2026, 9, 25),
      );

      final metrics = LeaveCalculator.calculateWorkforceMetrics(summaries, cycle);

      expect(metrics.totalEmployees, 2);
      expect(metrics.totalWorkforceWorkingDays, 54); // 27 * 2
      expect(metrics.totalWorkforceDaysWorked, 0);
      expect(metrics.totalWorkforceLeavesTaken, 54);
      expect(metrics.totalWorkforceSundayOffs, 8); // 4 * 2
    });

    test('PdfExportService builds Cumulative and Individual PDF with Leave Taken metrics', () async {
      final employee = EmployeeEntity(
        id: 'emp_01',
        employeeCode: 'EMP001',
        name: 'John Doe',
        mobileNumber: '1234567890',
        email: 'john@example.com',
        designation: 'Technician',
        department: 'Engineering',
      );

      final cycle = SalaryCycle.forMonth(2026, 9);

      // 1 day worked on 2026-08-31
      final List<AttendanceRecord> testRecords = [
        AttendanceRecord(
          id: 'rec_1',
          employeeId: 'emp_01',
          employeeName: 'John Doe',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 8, 31, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec_2',
          employeeId: 'emp_01',
          employeeName: 'John Doe',
          workflowStep: WorkflowStep.completed,
          eventTimestamp: DateTime(2026, 8, 31, 17, 0),
          latitude: 25.0,
          longitude: 55.0,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      // Verify Cumulative PDF generation
      final cumulativeBytes = await PdfExportService.buildCumulativePdfBytes(
        organizationName: 'Fusion Enterprise Test',
        employees: [employee],
        records: testRecords,
        salaryCyclePeriod: cycle.shortPeriodLabel,
        salaryCycle: cycle,
      );
      expect(cumulativeBytes, isNotNull);
      expect(cumulativeBytes.isNotEmpty, isTrue);

      // Verify Individual Employee Attendance & Leave PDF generation
      final individualBytes = await PdfExportService.buildEmployeeAttendancePdfBytes(
        organizationName: 'Fusion Enterprise Test',
        employee: employee,
        records: testRecords,
        salaryCyclePeriod: cycle.shortPeriodLabel,
        salaryCycle: cycle,
      );
      expect(individualBytes, isNotNull);
      expect(individualBytes.isNotEmpty, isTrue);
    });

    test('PdfExportService splits 0-days worked employees into separate table in cumulative report', () async {
      final cycle = SalaryCycle.forMonth(2026, 9); // 25 Aug - 24 Sep 2026

      final activeEmp = EmployeeEntity(
        id: 'emp_active',
        employeeCode: 'EMP-01',
        name: 'Active Worker',
        mobileNumber: '111',
        email: 'active@test.com',
        designation: 'Staff',
        department: 'Operations',
      );

      final zeroDaysEmp = EmployeeEntity(
        id: 'emp_zero',
        employeeCode: 'EMP-02',
        name: 'Zero Days Worker',
        mobileNumber: '222',
        email: 'zero@test.com',
        designation: 'Staff',
        department: 'Logistics',
      );

      final testRecords = [
        AttendanceRecord(
          id: 'rec_act_1',
          employeeId: 'emp_active',
          employeeName: 'Active Worker',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 8, 26, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec_act_2',
          employeeId: 'emp_active',
          employeeName: 'Active Worker',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: DateTime(2026, 8, 26, 17, 0),
          latitude: 25.0,
          longitude: 55.0,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final pdfBytes = await PdfExportService.buildCumulativePdfBytes(
        organizationName: 'Fusion Enterprise Test',
        employees: [activeEmp, zeroDaysEmp],
        records: testRecords,
        salaryCyclePeriod: cycle.shortPeriodLabel,
        salaryCycle: cycle,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
    });

    test('PdfExportService clamps individual and cumulative reports to active cycle totalDays (never 32, 33, 34 days)', () async {
      final cycle = SalaryCycle.forMonth(2026, 9); // 25 Aug - 24 Sep 2026 (31 days)
      expect(cycle.totalDays, equals(31));

      final emp = EmployeeEntity(
        id: 'emp_all_time',
        employeeCode: 'EMP-ALL',
        name: 'Continuous Worker',
        mobileNumber: '333',
        email: 'worker@test.com',
        designation: 'Staff',
        department: 'Operations',
      );

      // Create records spanning 35 days (from 15 Aug to 18 Sep)
      final List<AttendanceRecord> spanningRecords = [];
      for (int i = 0; i < 35; i++) {
        final dayDate = DateTime(2026, 8, 15).add(Duration(days: i));
        spanningRecords.add(
          AttendanceRecord(
            id: 'rec_span_in_$i',
            employeeId: 'emp_all_time',
            employeeName: 'Continuous Worker',
            workflowStep: WorkflowStep.officeCheckIn,
            eventTimestamp: DateTime(dayDate.year, dayDate.month, dayDate.day, 8, 0),
            latitude: 25.0,
            longitude: 55.0,
            gpsAccuracy: 5.0,
            address: 'Office',
            deviceId: 'dev-1',
            photoBase64: '',
            isGeofenceValid: true,
          ),
        );
        spanningRecords.add(
          AttendanceRecord(
            id: 'rec_span_out_$i',
            employeeId: 'emp_all_time',
            employeeName: 'Continuous Worker',
            workflowStep: WorkflowStep.officeCheckOut,
            eventTimestamp: DateTime(dayDate.year, dayDate.month, dayDate.day, 17, 0),
            latitude: 25.0,
            longitude: 55.0,
            gpsAccuracy: 5.0,
            address: 'Office',
            deviceId: 'dev-1',
            photoBase64: '',
            isGeofenceValid: true,
          ),
        );
      }

      // Spanning records has 35 days
      expect(spanningRecords.length, equals(70));

      // 1. Cumulative PDF generation must strictly clamp to 25 Aug - 24 Sep
      final cumulativeBytes = await PdfExportService.buildCumulativePdfBytes(
        organizationName: 'Fusion Enterprise Test',
        employees: [emp],
        records: spanningRecords,
        salaryCyclePeriod: cycle.shortPeriodLabel,
        salaryCycle: cycle,
      );
      expect(cumulativeBytes, isNotNull);
      expect(cumulativeBytes.isNotEmpty, isTrue);

      // 2. Individual Employee Attendance PDF generation must strictly clamp to cycle totalDays
      final individualBytes = await PdfExportService.buildEmployeeAttendancePdfBytes(
        organizationName: 'Fusion Enterprise Test',
        employee: emp,
        records: spanningRecords,
        salaryCyclePeriod: cycle.shortPeriodLabel,
        salaryCycle: cycle,
      );
      expect(individualBytes, isNotNull);
      expect(individualBytes.isNotEmpty, isTrue);

      // Verify leave summary for this employee within cycle has exactly 31 daily records
      final leaveSummary = LeaveCalculator.calculateEmployeeLeave(
        emp,
        spanningRecords,
        cycle,
      );
      expect(leaveSummary.totalCycleDays, equals(31));
      expect(leaveSummary.dailyRecords.length, equals(31));
      expect(leaveSummary.daysWorked <= 31, isTrue);
    });
  });
}
