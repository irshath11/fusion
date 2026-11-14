import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/salary_cycle_helper.dart';
import 'package:attendance_app/features/admin/domain/employee_entity.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';
import 'package:attendance_app/features/salary/domain/employee_salary_config.dart';
import 'package:attendance_app/features/salary/domain/daily_salary_record.dart';
import 'package:attendance_app/features/salary/utils/salary_calculator.dart';

void main() {
  group('SalaryCalculator & Day-Wise Payroll Tests', () {
    final employee = EmployeeEntity(
      id: 'emp-1012',
      employeeCode: '1012',
      name: 'Raja Mohammed Mohammed Ali',
      mobileNumber: '+971501234567',
      email: 'raja@gmail.com',
      designation: 'Supervisor',
      department: 'Fusion',
    );

    final salaryConfig = EmployeeSalaryConfig(
      employeeCode: '1012',
      employeeName: 'Raja Mohammed Mohammed Ali',
      department: 'Fusion',
      fixedSalary: 1500.0,
      variableSalary: 1100.0,
      dailyDivisor: 30.0,
      standardDailyHours: 8.0,
    );

    test('Rate calculations: daily fixed, daily variable, daily base, hourly OT', () {
      // Fixed: 1500 => Daily Fixed = 1500 / 30 = 50.0
      expect(salaryConfig.dailyFixedRate, 50.0);

      // Variable: 1100 => Daily Variable = 1100 / 30 = 36.6666...
      expect(salaryConfig.dailyVariableRate, closeTo(36.67, 0.01));

      // Base Daily = 50 + 36.67 = 86.67
      expect(salaryConfig.dailyBaseRate, closeTo(86.67, 0.01));

      // Hourly OT Rate: Fixed / 240 = 1500 / 240 = 6.25 AED/hour
      expect(salaryConfig.otHourlyRate, 6.25);
    });

    test('In-between Sunday Rule: 6 days worked + Sunday off + 2 days worked = 9 days paid', () {
      // User scenario:
      // Works 6 days (Mon-Sat), Sunday is off, works 2 days (Mon-Tue).
      // Total 8 days physically worked, but in-between Sunday is credited => 9 days paid!

      // Choose cycle September 2026: 25 Aug to 24 Sep 2026.
      final cycle = SalaryCycle.forMonth(2026, 9);

      // Monday 2026-08-31 to Saturday 2026-09-05: 6 working days
      // Sunday 2026-09-06: Sunday off (no records)
      // Monday 2026-09-07 & Tuesday 2026-09-08: 2 working days
      final List<AttendanceRecord> records = [];

      // Add check-ins for the 6 days before Sunday
      for (int day = 31; day <= 31; day++) {
        records.add(AttendanceRecord(
          id: 'rec-aug-$day',
          employeeId: employee.id,
          employeeName: employee.name,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 8, day, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
        ));
      }
      for (int day = 1; day <= 5; day++) {
        records.add(AttendanceRecord(
          id: 'rec-sep-$day',
          employeeId: employee.id,
          employeeName: employee.name,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 9, day, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
        ));
      }

      // 2026-09-06 is Sunday (no attendance record)

      // Add check-ins for Monday 2026-09-07 and Tuesday 2026-09-08
      for (int day = 7; day <= 8; day++) {
        records.add(AttendanceRecord(
          id: 'rec-sep-$day',
          employeeId: employee.id,
          employeeName: employee.name,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 9, day, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
        ));
      }

      // Calculate salary summary
      final summary = SalaryCalculator.calculateEmployeeSalary(
        config: salaryConfig,
        employee: employee,
        records: records,
        cycle: cycle,
        referenceDate: DateTime(2026, 9, 25), // after cycle completed
      );

      // Verify days count:
      // Worked days = 6 + 2 = 8 days
      expect(summary.daysWorked, 8);

      // In-between paid Sundays = 1 (the Sunday on Sep 6 surrounded by worked days)
      expect(summary.paidSundays, 1);

      // Total payable days = 8 + 1 = 9 days!
      expect(summary.totalPayableDays, 9);

      // Day-wise check on Sunday 2026-09-06:
      final sundayRecord = summary.dailyRecords.firstWhere(
        (r) => r.date.year == 2026 && r.date.month == 9 && r.date.day == 6,
      );
      expect(sundayRecord.status, DailySalaryStatus.paidSundayOff);
      expect(sundayRecord.isPayable, true);
      expect(sundayRecord.dailyFixedCredit, 50.0);
      expect(sundayRecord.dailyVariableCredit, closeTo(36.67, 0.01));
      expect(sundayRecord.dailyTotalSalary, closeTo(86.67, 0.01));

      // Financial verification:
      // Earned Fixed = 9 * 50 = 450.0
      expect(summary.earnedFixedSalary, 450.0);

      // Earned Variable = 9 * (1100 / 30) = 330.0
      expect(summary.earnedVariableSalary, closeTo(330.0, 0.01));

      // Total Gross Salary = 450 + 330 = 780.0
      expect(summary.grossTotalSalary, closeTo(780.0, 0.01));
    });

    test('Handwritten sheet case: Ramesh Gopal (Fixed: 1500, Variable: 500, 5 days, 12.5h OT = 411.46)', () {
      final rameshConfig = EmployeeSalaryConfig(
        employeeCode: '1024',
        employeeName: 'Ramesh Gopal Gopal',
        department: 'Fusion',
        fixedSalary: 1500.0,
        variableSalary: 500.0,
      );

      // 5 days worked:
      // Fixed: 1500 / 30 * 5 = 250.0
      // Variable: 500 / 30 * 5 = 83.33
      // OT rate: 1500 / 240 = 6.25 / hr
      // OT hours: 12.5h * 6.25 = 78.125
      // Total = 250 + 83.33 + 78.13 = 411.46 (Matches ~411 on the sheet!)

      final earnedFixed = 5 * rameshConfig.dailyFixedRate;
      final earnedVar = 5 * rameshConfig.dailyVariableRate;
      final earnedOt = 12.5 * rameshConfig.otHourlyRate;
      final total = earnedFixed + earnedVar + earnedOt;

      expect(earnedFixed, 250.0);
      expect(earnedVar, closeTo(83.33, 0.01));
      expect(earnedOt, 78.125);
      expect(total, closeTo(411.46, 0.01));
    });

    test('Handwritten sheet case: Mohamed Azarudeen (Fixed: 1000, Variable: 800, 28 days, 8h OT = 1713.33)', () {
      final azarConfig = EmployeeSalaryConfig(
        employeeCode: '1021',
        employeeName: 'Mohamed Azarudheen Anvar Ali',
        department: 'Fusion',
        fixedSalary: 1000.0,
        variableSalary: 800.0,
      );

      // 28 days:
      // Fixed: 1000 / 30 * 28 = 933.33
      // Variable: 800 / 30 * 28 = 746.67
      // OT rate: 1000 / 240 = 4.1667 / hr
      // OT hours: 8h * 4.1667 = 33.33
      // Total = 933.33 + 746.67 + 33.33 = 1713.33 (Matches 1713 on sheet!)

      final earnedFixed = 28 * azarConfig.dailyFixedRate;
      final earnedVar = 28 * azarConfig.dailyVariableRate;
      final earnedOt = 8.0 * azarConfig.otHourlyRate;
      final total = earnedFixed + earnedVar + earnedOt;

      expect(earnedFixed, closeTo(933.33, 0.01));
      expect(earnedVar, closeTo(746.67, 0.01));
      expect(earnedOt, closeTo(33.33, 0.01));
      expect(total, closeTo(1713.33, 0.01));
    });

    test('Handwritten sheet case: Shabi (Full 30 days: Fixed 1200 + Var 1100 + OT 302 = 2602)', () {
      final shabiConfig = EmployeeSalaryConfig(
        employeeCode: 'N-1004',
        employeeName: 'Shabi Bismillah Bismillah',
        department: 'Neo',
        fixedSalary: 1200.0,
        variableSalary: 1100.0,
      );

      // Full month: 30 days payable
      final earnedFixed = 30 * shabiConfig.dailyFixedRate;
      final earnedVar = 30 * shabiConfig.dailyVariableRate;
      const double otAmount = 302.0;
      final total = earnedFixed + earnedVar + otAmount;

      expect(earnedFixed, 1200.0);
      expect(earnedVar, 1100.0);
      expect(total, 2602.0); // Exact match with 2,602 on sheet!
    });

    test('Strict OT Rule: OT hourly rate is derived from Basic Salary ONLY (never Total/Variable)', () {
      // User rule:
      // For Shabi: Fixed = 1200, Variable = 1100, Total = 2300.
      // OT rate is NOT calculated as (2300 / daysInMonth) / 8.
      // It is calculated as (1200 / daysInMonth) / 8.
      final shabiConfig = EmployeeSalaryConfig(
        employeeCode: 'N-1004',
        employeeName: 'Shabi Bismillah Bismillah',
        department: 'Neo',
        fixedSalary: 1200.0,
        variableSalary: 1100.0,
      );

      expect(shabiConfig.basicSalary, 1200.0);
      expect(shabiConfig.variableSalary, 1100.0);
      expect(shabiConfig.monthlyBaseTotal, 2300.0);

      // Case A: 30-day month (e.g. September, April, June, November)
      // Rate = (1200 / 30) / 8 = 40.0 / 8 = 5.00 AED/hr
      final otRate30Days = shabiConfig.computeHourlyOtRate(totalDaysOfCurrentMonth: 30);
      expect(otRate30Days, 5.00);

      // Verify that calculating from total (2300) would be 9.5833, which is NOT our rate
      final wrongRateFromTotal30 = (2300.0 / 30) / 8;
      expect(otRate30Days, isNot(closeTo(wrongRateFromTotal30, 0.01)));

      // OT Salary with 60.4 hours of OT in 30-day month:
      // 60.4 * 5.00 = 302.0 AED OT (Exactly matches the 302 OT on handwritten Neo sheet!)
      final otSalary30 = 60.4 * otRate30Days;
      expect(otSalary30, 302.0);

      // Total salary: 1200 + 1100 + 302 = 2602 AED (Matches 2602 total on handwritten sheet!)
      final totalSalary30 = shabiConfig.fixedSalary + shabiConfig.variableSalary + otSalary30;
      expect(totalSalary30, 2602.0);

      // Case B: 31-day month (e.g. October, August, January, etc.)
      // Rate = (1200 / 31) / 8 = 38.709677 / 8 = 4.8387 AED/hr
      final otRate31Days = shabiConfig.computeHourlyOtRate(totalDaysOfCurrentMonth: 31);
      expect(otRate31Days, closeTo(4.8387, 0.0001));

      // Again assert that variable is excluded
      final wrongRateFromTotal31 = (2300.0 / 31) / 8;
      expect(otRate31Days, isNot(closeTo(wrongRateFromTotal31, 0.01)));
    });

    test('Fixed OT Condition: When otIncludedInVariable is TRUE, OT is NOT calculated (credits AED 0.00)', () {
      // User requirement:
      // "need one additional condition/ button, if I press that button, the OT for employee
      // is not calculated or as 0, because we give fixed OT for some employees as already included in variable salary"
      // Example from sheet: Riyas (Fixed: 1200, Variable: 800, OT: '-', Total: 2000)
      final riyasConfig = EmployeeSalaryConfig(
        employeeCode: 'N-1003',
        employeeName: 'Muhammed Riyas Hussain Hussain Kasim',
        department: 'Neo',
        fixedSalary: 1200.0,
        variableSalary: 800.0,
        otIncludedInVariable: true, // Button pressed!
      );

      // Hourly OT rate should be strictly 0.0
      expect(riyasConfig.otIncludedInVariable, true);
      expect(riyasConfig.computeHourlyOtRate(totalDaysOfCurrentMonth: 30), 0.0);
      expect(riyasConfig.otHourlyRate, 0.0);

      // Create attendance records with 20.0 hours of OT for Riyas
      final cycle = SalaryCycle.forMonth(2026, 9);
      final List<AttendanceRecord> records = [];

      for (int day = 1; day <= 10; day++) {
        records.add(AttendanceRecord(
          id: 'rec-riyas-$day-in',
          employeeId: 'emp-riyas',
          employeeName: riyasConfig.employeeName,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 9, day, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
        ));
        records.add(AttendanceRecord(
          id: 'rec-riyas-$day-out',
          employeeId: 'emp-riyas',
          employeeName: riyasConfig.employeeName,
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: DateTime(2026, 9, day, 20, 0), // 12 hours shift => 8h regular + 4h OT
          latitude: 25.0,
          longitude: 55.0,
        ));
      }

      final summary = SalaryCalculator.calculateEmployeeSalary(
        config: riyasConfig,
        records: records,
        cycle: cycle,
        referenceDate: DateTime(2026, 9, 25),
      );

      // Verify OT hours are tracked from timesheet, but monetary OT earned is strictly 0.0
      expect(summary.totalOvertimeHours, greaterThan(0.0));
      expect(summary.hourlyOtRate, 0.0);
      expect(summary.earnedOtSalary, 0.0);

      // Every daily record must credit 0.0 for OT
      for (final r in summary.dailyRecords) {
        expect(r.dailyOtCredit, 0.0);
      }

      // Total salary consists strictly of basic + variable (no OT added)
      expect(summary.grossTotalSalary, summary.earnedFixedSalary + summary.earnedVariableSalary);
    });

    test('Monday Worked Rule: If employee worked on Monday, the preceding Sunday is credited as payable', () {
      // User rule:
      // "I need another condition like if employee worked in monday, then consider day before i.e sunday, consider as payable"

      // In Cycle Sep 2026 (25 Aug - 24 Sep 2026):
      // Sunday: 2026-09-06 (no attendance)
      // Monday: 2026-09-07 (worked!)
      // Suppose the employee did NOT work any day prior to this Sunday (e.g. joined or on leave Mon-Sat 31 Aug - 05 Sep).
      final cycle = SalaryCycle.forMonth(2026, 9);
      final employee = EmployeeEntity(
        id: 'emp-nowfal',
        employeeCode: '1054',
        name: 'Nowfal Rizwan',
        department: 'Fusion',
      );

      final nowfalConfig = EmployeeSalaryConfig(
        employeeCode: '1054',
        employeeName: 'Nowfal Rizwan',
        department: 'Fusion',
        fixedSalary: 1200.0,
        variableSalary: 600.0,
        paySundayIfMondayWorked: true,
      );

      // Only add attendance for Monday 2026-09-07
      final List<AttendanceRecord> records = [
        AttendanceRecord(
          id: 'rec-mon-1',
          employeeId: employee.id,
          employeeName: employee.name,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 9, 7, 8, 0), // Monday
          latitude: 25.0,
          longitude: 55.0,
        ),
      ];

      final summary = SalaryCalculator.calculateEmployeeSalary(
        config: nowfalConfig,
        employee: employee,
        records: records,
        cycle: cycle,
        referenceDate: DateTime(2026, 9, 25),
      );

      // Employee physically worked 1 day (Monday)
      expect(summary.daysWorked, 1);

      // The Sunday (2026-09-06) immediately before Monday must be credited as paid!
      expect(summary.paidSundays, greaterThanOrEqualTo(1));

      final sundayRecord = summary.dailyRecords.firstWhere(
        (r) => r.date.year == 2026 && r.date.month == 9 && r.date.day == 6,
      );

      expect(sundayRecord.status, DailySalaryStatus.paidSundayOff);
      expect(sundayRecord.isPayable, true);
      expect(sundayRecord.remarks, contains('Worked on Monday'));
      expect(sundayRecord.dailyFixedCredit, nowfalConfig.dailyFixedRate);
      expect(sundayRecord.dailyVariableCredit, nowfalConfig.dailyVariableRate);

      // Total payable days = 1 day worked + 1 paid Sunday = 2 payable days!
      expect(summary.totalPayableDays, greaterThanOrEqualTo(2));
    });

    test('Office Staff: 0 Days initial, then manual office attendance input calculates full salary', () {
      final cycle = SalaryCycle.forMonth(2026, 9);
      final officeEmployee = EmployeeEntity(
        id: 'emp-office-01',
        employeeCode: '2001',
        name: 'Sarah Office Manager',
        department: 'Fusion',
        designation: 'Office Admin',
      );

      final officeConfig = EmployeeSalaryConfig(
        employeeCode: '2001',
        employeeName: 'Sarah Office Manager',
        department: 'Fusion',
        fixedSalary: 1500.0,
        variableSalary: 1000.0,
      );

      // Phase 1: 0 days attendance (office employee does not use app)
      final zeroSummary = SalaryCalculator.calculateEmployeeSalary(
        config: officeConfig,
        employee: officeEmployee,
        records: [],
        cycle: cycle,
      );

      expect(zeroSummary.daysWorked, 0);
      expect(zeroSummary.totalPayableDays, 0);
      expect(zeroSummary.isManualAttendance, false);
      expect(zeroSummary.earnedFixedSalary, 0.0);
      expect(zeroSummary.earnedVariableSalary, 0.0);
      expect(zeroSummary.grossTotalSalary, 0.0);

      // Phase 2: Administrator puts 26 days of office attendance
      final List<AttendanceRecord> manualRecords = [];
      final DateTime start = cycle.startDate;
      int daysAdded = 0;
      for (int i = 0; i < cycle.totalDays && daysAdded < 26; i++) {
        final d = start.add(Duration(days: i));
        if (d.weekday == DateTime.sunday) continue;
        daysAdded++;
        manualRecords.add(AttendanceRecord(
          id: 'office_2001_${i}_in',
          employeeId: officeEmployee.id,
          employeeName: officeEmployee.name,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(d.year, d.month, d.day, 9, 0),
          deviceId: 'OFFICE_CALENDAR_ENTRY',
          remarks: 'Office Attendance (Calendar)',
        ));
      }

      final calculatedSummary = SalaryCalculator.calculateEmployeeSalary(
        config: officeConfig,
        employee: officeEmployee,
        records: manualRecords,
        cycle: cycle,
        referenceDate: DateTime(2026, 9, 25),
      );

      expect(calculatedSummary.daysWorked, 26);
      expect(calculatedSummary.totalPayableDays, greaterThanOrEqualTo(26));
      expect(calculatedSummary.isManualAttendance, true);
      expect(calculatedSummary.earnedFixedSalary, greaterThan(0.0));
      expect(calculatedSummary.earnedVariableSalary, greaterThan(0.0));
      expect(calculatedSummary.grossTotalSalary, greaterThan(0.0));
    });

    test('Custom Manual OT: Manual total OT amount of the month directly credited', () {
      final cycle = SalaryCycle.forMonth(2026, 9);
      final configWithManualOt = EmployeeSalaryConfig(
        employeeCode: '3001',
        employeeName: 'Ahmed Engineer',
        department: 'Fusion',
        fixedSalary: 1500.0,
        variableSalary: 1000.0,
        customMonthlyOtAmount: 450.0, // Manual monthly total OT
      );

      expect(configWithManualOt.hasCustomMonthlyOtAmount, true);
      expect(configWithManualOt.customMonthlyOtAmount, 450.0);

      // 1. If 0 days worked, earned OT is 0.0
      final zeroSummary = SalaryCalculator.calculateEmployeeSalary(
        config: configWithManualOt,
        records: [],
        cycle: cycle,
      );
      expect(zeroSummary.earnedOtSalary, 0.0);
      expect(zeroSummary.grossTotalSalary, 0.0);

      // 2. If employee worked (e.g. 5 days)
      final List<AttendanceRecord> records = [];
      for (int i = 0; i < 5; i++) {
        final d = cycle.startDate.add(Duration(days: i));
        records.add(AttendanceRecord(
          id: 'rec-manual-ot-$i-in',
          employeeId: 'emp-3001',
          employeeName: 'Ahmed Engineer',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(d.year, d.month, d.day, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
        ));
        records.add(AttendanceRecord(
          id: 'rec-manual-ot-$i-out',
          employeeId: 'emp-3001',
          employeeName: 'Ahmed Engineer',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: DateTime(d.year, d.month, d.day, 17, 0),
          latitude: 25.0,
          longitude: 55.0,
        ));
      }

      final summary = SalaryCalculator.calculateEmployeeSalary(
        config: configWithManualOt,
        records: records,
        cycle: cycle,
      );

      // Fixed: 1500 / 30 = 50/day * 5 = 250
      // Variable: 1000 / 30 = 33.33/day * 5 = 166.67
      // Manual OT: exactly 450.0
      expect(summary.daysWorked, 5);
      expect(summary.earnedOtSalary, 450.0);
      expect(summary.grossTotalSalary, closeTo(summary.earnedFixedSalary + summary.earnedVariableSalary + 450.0, 0.01));
    });

    test('Owner & personnel exclusion: Nasurudeen, Sirajudeen, and Asik Saheel are excluded from salary & payroll', () {
      // 1. isExcludedOwner checks
      expect(SalaryCalculator.isExcludedOwner(name: 'Nasurudeen'), true);
      expect(SalaryCalculator.isExcludedOwner(name: 'Nasrudeen'), true);
      expect(SalaryCalculator.isExcludedOwner(name: 'Alnaser Samsudeen', code: '1058'), true);
      expect(SalaryCalculator.isExcludedOwner(email: 'nasuru@fusionmaint.com'), true);
      expect(SalaryCalculator.isExcludedOwner(name: 'Sirajudeen'), true);
      expect(SalaryCalculator.isExcludedOwner(name: 'Siraj'), true);
      expect(SalaryCalculator.isExcludedOwner(email: 'siraj@gmail.com'), true);
      expect(SalaryCalculator.isExcludedOwner(name: 'Asik Saheel'), true);
      expect(SalaryCalculator.isExcludedOwner(name: 'Asik'), true);
      expect(SalaryCalculator.isExcludedOwner(name: 'Saheel'), true);
      expect(SalaryCalculator.isExcludedOwner(email: 'asik@gmail.com'), true);

      // Regular staff are NOT excluded
      expect(SalaryCalculator.isExcludedOwner(name: 'Raja Mohammed Mohammed Ali', code: '1012'), false);
      expect(SalaryCalculator.isExcludedOwner(name: 'Shabi Bismillah Bismillah', code: 'N-1004'), false);
      expect(SalaryCalculator.isExcludedOwner(name: 'Kajamohideen Samsudeen Samsudeen', code: 'N-1008'), false);

      // 2. Workforce payroll calculation strictly filters them out
      final cycle = SalaryCycle.forMonth(2026, 9);
      final employees = [
        EmployeeEntity(
          id: 'emp-1012',
          employeeCode: '1012',
          name: 'Raja Mohammed Mohammed Ali',
          mobileNumber: '0501111111',
          email: 'raja@fusionmaint.com',
          designation: 'Electrician',
          department: 'Maintenance',
        ),
        EmployeeEntity(
          id: 'emp-1058',
          employeeCode: '1058',
          name: 'Alnaser Samsudeen',
          mobileNumber: '0502222222',
          email: 'nasuru@fusionmaint.com',
          designation: 'Managing Director',
          department: 'Management',
        ),
        EmployeeEntity(
          id: 'emp-siraj',
          employeeCode: '9999',
          name: 'Sirajudeen',
          mobileNumber: '0503333333',
          email: 'siraj@fusionmaint.com',
          designation: 'Partner',
          department: 'Management',
        ),
        EmployeeEntity(
          id: 'emp-asik',
          employeeCode: '8888',
          name: 'Asik Saheel',
          mobileNumber: '0504444444',
          email: 'asik@gmail.com',
          designation: 'Staff',
          department: 'General',
        ),
        EmployeeEntity(
          id: 'emp-n-1004',
          employeeCode: 'N-1004',
          name: 'Shabi Bismillah Bismillah',
          mobileNumber: '0505555555',
          email: 'shabi@fusionmaint.com',
          designation: 'Electrician',
          department: 'Neo',
        ),
      ];

      final workforce = SalaryCalculator.calculateWorkforcePayroll(
        employees: employees,
        salaryConfigs: {},
        records: [],
        cycle: cycle,
      );

      final resultNames = workforce.employeeSummaries.map((s) => s.employeeName).toList();
      expect(resultNames, contains('Raja Mohammed Mohammed Ali'));
      expect(resultNames, contains('Shabi Bismillah Bismillah'));
      expect(resultNames, isNot(contains('Alnaser Samsudeen')));
      expect(resultNames, isNot(contains('Sirajudeen')));
      expect(resultNames, isNot(contains('Asik Saheel')));
      expect(workforce.employeeSummaries.length, 2);
    });
  });
}

