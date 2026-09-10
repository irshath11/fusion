import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/salary_cycle_helper.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';
import 'package:attendance_app/features/timesheet/domain/timesheet_entry.dart';

void main() {
  group('SalaryCycle Tests (25th to 24th Organization Cycle)', () {
    test('Date on or after 25th belongs to current month 25th to next month 24th', () {
      // 25 August 2026 -> 25 Aug 2026 to 24 Sep 2026 (September 2026 Cycle)
      final date = DateTime(2026, 8, 25, 10, 30);
      final cycle = SalaryCycle.fromDate(date);

      expect(cycle.startDate, equals(DateTime(2026, 8, 25, 0, 0, 0, 0)));
      expect(cycle.endDate, equals(DateTime(2026, 9, 24, 23, 59, 59, 999)));
      expect(cycle.salaryYear, equals(2026));
      expect(cycle.salaryMonth, equals(9));
      expect(cycle.title, contains('Sep 2026'));
      expect(cycle.fullPeriodString, contains('25 Aug 2026 – 24 Sep 2026'));
    });

    test('Date before 25th belongs to previous month 25th to current month 24th', () {
      // 24 September 2026 -> 25 Aug 2026 to 24 Sep 2026 (September 2026 Cycle)
      final date = DateTime(2026, 9, 24, 18, 45);
      final cycle = SalaryCycle.fromDate(date);

      expect(cycle.startDate, equals(DateTime(2026, 8, 25, 0, 0, 0, 0)));
      expect(cycle.endDate, equals(DateTime(2026, 9, 24, 23, 59, 59, 999)));
      expect(cycle.salaryYear, equals(2026));
      expect(cycle.salaryMonth, equals(9));
    });

    test('Year rollover across December and January works seamlessly', () {
      // 25 Dec 2026 -> 25 Dec 2026 to 24 Jan 2027 (January 2027 Cycle)
      final dec25 = DateTime(2026, 12, 25, 8, 0);
      final cycleJan = SalaryCycle.fromDate(dec25);

      expect(cycleJan.startDate, equals(DateTime(2026, 12, 25, 0, 0, 0, 0)));
      expect(cycleJan.endDate, equals(DateTime(2027, 1, 24, 23, 59, 59, 999)));
      expect(cycleJan.salaryYear, equals(2027));
      expect(cycleJan.salaryMonth, equals(1));
      expect(cycleJan.fullPeriodString, contains('25 Dec 2026 – 24 Jan 2027'));

      // 10 Jan 2027 -> same cycle
      final jan10 = DateTime(2027, 1, 10, 14, 0);
      final cycleFromJan = SalaryCycle.fromDate(jan10);
      expect(cycleFromJan.startDate, equals(cycleJan.startDate));
      expect(cycleFromJan.endDate, equals(cycleJan.endDate));
    });

    test('Boundary containment tests (contains method)', () {
      final cycle = SalaryCycle.fromDate(DateTime(2026, 9, 9)); // 25 Aug to 24 Sep

      // Exactly at start boundary
      expect(cycle.contains(DateTime(2026, 8, 25, 0, 0, 0, 0)), isTrue);
      // Just before start boundary (24 Aug 23:59:59)
      expect(cycle.contains(DateTime(2026, 8, 24, 23, 59, 59)), isFalse);

      // Exactly at end boundary
      expect(cycle.contains(DateTime(2026, 9, 24, 23, 59, 59, 999)), isTrue);
      // Just after end boundary (25 Sep 00:00:00)
      expect(cycle.contains(DateTime(2026, 9, 25, 0, 0, 0, 0)), isFalse);
    });

    test('Recent cycles generator returns correct chronological sequence', () {
      final cycles = SalaryCycle.getRecentCycles(
        count: 6,
        referenceDate: DateTime(2027, 2, 1),
      );
      expect(cycles.length, equals(6));

      // Each cycle should start immediately after the previous one ends
      for (int i = 0; i < cycles.length - 1; i++) {
        final current = cycles[i];
        final previous = cycles[i + 1];

        // The day before current.startDate should be previous.endDate day (24th)
        final dayBeforeCurrentStart = current.startDate.subtract(const Duration(days: 1));
        expect(dayBeforeCurrentStart.day, equals(24));
        expect(previous.endDate.day, equals(24));
        expect(previous.startDate.day, equals(25));
      }
    });

    test('Recent cycles generator respects earliest implemented cycle cutoff (Aug-Sep 2026)', () {
      final cycles = SalaryCycle.getRecentCycles(referenceDate: DateTime(2026, 9, 10));
      expect(cycles.length, equals(1));
      expect(cycles.first.salaryYear, equals(2026));
      expect(cycles.first.salaryMonth, equals(9));
      expect(cycles.first.startDate.day, equals(25));
      expect(cycles.first.startDate.month, equals(8));
      expect(cycles.first.endDate.day, equals(24));
      expect(cycles.first.endDate.month, equals(9));
    });

    test('filterRecords filters attendance records according to cycle bounds', () {
      final cycle = SalaryCycle(
        startDate: DateTime(2026, 8, 25, 0, 0, 0),
        endDate: DateTime(2026, 9, 24, 23, 59, 59, 999),
        salaryMonth: 9,
        salaryYear: 2026,
      );

      final recBefore = AttendanceRecord(
        id: '1',
        employeeId: 'u1',
        employeeName: 'Emp 1',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: DateTime(2026, 8, 24, 15, 0),
        latitude: 0,
        longitude: 0,
        gpsAccuracy: 5.0,
        address: 'Test Address',
        deviceId: 'dev1',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final recIn = AttendanceRecord(
        id: '2',
        employeeId: 'u1',
        employeeName: 'Emp 1',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: DateTime(2026, 8, 26, 8, 0),
        latitude: 0,
        longitude: 0,
        gpsAccuracy: 5.0,
        address: 'Test Address',
        deviceId: 'dev1',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final recAfter = AttendanceRecord(
        id: '3',
        employeeId: 'u1',
        employeeName: 'Emp 1',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: DateTime(2026, 9, 25, 9, 0),
        latitude: 0,
        longitude: 0,
        gpsAccuracy: 5.0,
        address: 'Test Address',
        deviceId: 'dev1',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final filtered = cycle.filterRecords([recBefore, recIn, recAfter]);
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('2'));
    });

    test('filterTimesheets filters DailyTimesheetEntry entries according to cycle bounds', () {
      final cycle = SalaryCycle(
        startDate: DateTime(2026, 8, 25, 0, 0, 0),
        endDate: DateTime(2026, 9, 24, 23, 59, 59, 999),
        salaryMonth: 9,
        salaryYear: 2026,
      );

      final ts1 = DailyTimesheetEntry(
        date: DateTime(2026, 8, 20),
        employeeId: 'u1',
        employeeName: 'Emp 1',
        totalDuration: const Duration(hours: 8),
        regularHours: 8.0,
        overtimeHours: 0.0,
      );

      final ts2 = DailyTimesheetEntry(
        date: DateTime(2026, 9, 1),
        employeeId: 'u1',
        employeeName: 'Emp 1',
        totalDuration: const Duration(hours: 10),
        regularHours: 8.0,
        overtimeHours: 2.0,
      );

      final filtered = cycle.filterTimesheets([ts1, ts2]);
      expect(filtered.length, equals(1));
      expect(filtered.first.date.day, equals(1));
    });

    test('SalaryCycleMetrics calculations match timesheet hours accurately', () {
      final cycle = SalaryCycle(
        startDate: DateTime(2026, 8, 25, 0, 0, 0),
        endDate: DateTime(2026, 9, 24, 23, 59, 59, 999),
        salaryMonth: 9,
        salaryYear: 2026,
      );

      final timesheets = [
        DailyTimesheetEntry(
          date: DateTime(2026, 8, 26),
          employeeId: 'u1',
          employeeName: 'Emp 1',
          totalDuration: const Duration(hours: 9, minutes: 30),
          regularHours: 8.0,
          overtimeHours: 1.5,
        ),
        DailyTimesheetEntry(
          date: DateTime(2026, 8, 27),
          employeeId: 'u1',
          employeeName: 'Emp 1',
          totalDuration: const Duration(hours: 8),
          regularHours: 7.5,
          overtimeHours: 0.5,
        ),
      ];

      final metrics = SalaryCycleMetrics.fromEntries(
        cycle,
        timesheets,
      );

      expect(metrics.regularHours, equals(15.5));
      expect(metrics.overtimeHours, equals(2.0));
      expect(metrics.combinedHours, equals(17.5));
      expect(metrics.daysWorked, equals(2));
    });
  });
}
