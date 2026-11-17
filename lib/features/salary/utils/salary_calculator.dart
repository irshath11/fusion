import 'package:intl/intl.dart';
import '../../../core/utils/employee_directory_helper.dart';
import '../../../core/utils/salary_cycle_helper.dart';
import '../../../core/utils/timesheet_calculator.dart';
import '../../admin/domain/employee_entity.dart';
import '../../attendance/domain/attendance_record.dart';
import '../domain/employee_salary_config.dart';
import '../domain/daily_salary_record.dart';
import '../domain/employee_salary_summary.dart';

class SalaryCalculator {
  /// Matches an attendance record to an employee by id, name, or employeeCode
  static bool _recordMatchesEmployee(
    AttendanceRecord r, {
    String? employeeId,
    String? employeeCode,
    String? employeeName,
  }) {
    return EmployeeDirectoryHelper.matchesEmployeeIdentity(
      recordEmployeeId: r.employeeId,
      recordEmployeeName: r.employeeName,
      employeeId: employeeId,
      employeeCode: employeeCode,
      employeeName: employeeName,
    );
  }

  /// Calculates the day-wise salary breakdown and cycle totals for an individual employee
  static EmployeeSalarySummary calculateEmployeeSalary({
    required EmployeeSalaryConfig config,
    EmployeeEntity? employee,
    required List<AttendanceRecord> records,
    required SalaryCycle cycle,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    final empId = employee?.id ?? config.employeeId ?? '';
    final empCode = employee?.employeeCode ?? config.employeeCode;
    final empName = employee?.name.isNotEmpty == true
        ? employee!.name
        : config.employeeName;
    final empDept = employee?.department.isNotEmpty == true
        ? employee!.department
        : config.department;
    final empDesig = employee?.designation ?? '';

    // Filter records within this salary cycle matching this employee
    final cycleRecords = records.where((r) {
      if (!cycle.contains(r.eventTimestamp)) return false;
      return _recordMatchesEmployee(
        r,
        employeeId: empId,
        employeeCode: empCode,
        employeeName: empName,
      );
    }).toList();

    // Map records by calendar date (yyyy-MM-dd)
    final Map<String, List<AttendanceRecord>> recordsByDate = {};
    for (final r in cycleRecords) {
      final dateKey =
          DateFormat('yyyy-MM-dd').format(r.eventTimestamp.toLocal());
      recordsByDate.putIfAbsent(dateKey, () => []).add(r);
    }

    // Determine all calendar dates in this cycle
    final int cycleDaysCount = cycle.totalDays;
    final DateTime startMidnight = DateTime(
      cycle.startDate.year,
      cycle.startDate.month,
      cycle.startDate.day,
    );

    final List<DateTime> allDates = [];
    final Set<String> workedDateKeys = {};

    for (int i = 0; i < cycleDaysCount; i++) {
      final d = startMidnight.add(Duration(days: i));
      allDates.add(d);
      final key = DateFormat('yyyy-MM-dd').format(d);
      if (recordsByDate.containsKey(key) && recordsByDate[key]!.isNotEmpty) {
        workedDateKeys.add(key);
      }
    }

    // All records matching this employee (including dates just across the cycle border, e.g. following Monday)
    final Set<String> allWorkedDateKeys = Set<String>.from(workedDateKeys);
    for (final r in records) {
      if (_recordMatchesEmployee(
        r,
        employeeId: empId,
        employeeCode: empCode,
        employeeName: empName,
      )) {
        final key = DateFormat('yyyy-MM-dd').format(r.eventTimestamp.toLocal());
        allWorkedDateKeys.add(key);
      }
    }

    final List<DailySalaryRecord> dailyRecords = [];

    int daysWorked = 0;
    int paidSundays = 0;
    int unpaidSundays = 0;
    int absentDays = 0;
    double totalRegularHours = 0.0;
    double totalOvertimeHours = 0.0;
    double totalEmergencyHours = 0.0;

    int cumulativePayableDays = 0;
    double cumulativeSalary = 0.0;

    // Total days in the current month (e.g. 30 in Sep, 31 in Oct/Aug, 28/29 in Feb)
    final int daysInCurrentMonth = DateTime(cycle.salaryYear, cycle.salaryMonth + 1, 0).day;
    final int totalDaysOfCurrentMonth = daysInCurrentMonth > 0 ? daysInCurrentMonth : cycle.totalDays;

    // Daily Fixed / Basic Rate: (Basic Salary / total days of current month)
    final double dailyFixedRate = config.basicSalary / totalDaysOfCurrentMonth;

    // Daily Variable Rate: (Variable Salary / total days of current month)
    final double dailyVariableRate = config.variableSalary / totalDaysOfCurrentMonth;

    // Hourly OT Rate: Calculated strictly from Basic Salary ONLY (variable allowance is excluded).
    // Formula: (Basic Salary / total days of current month) / 8 hours.
    // If OT is fixed / included in variable allowance (otIncludedInVariable == true),
    // the OT rate is strictly 0.0 (no OT calculated or credited).
    // For example, for Shabi: Basic = 1200, Variable = 1100 (Total = 2300).
    // OT Hourly Rate = (1200 / totalDaysOfCurrentMonth) / 8.
    final double otHourlyRate = config.otIncludedInVariable
        ? 0.0
        : (config.customOtHourlyRate ??
            ((config.basicSalary / totalDaysOfCurrentMonth) / config.standardDailyHours));

    for (int i = 0; i < allDates.length; i++) {
      final date = allDates[i];
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final isSunday = date.weekday == DateTime.sunday;
      final isFuture = date.isAfter(todayMidnight);

      final dayRecords = recordsByDate[dateKey] ?? [];
      final hasAttendance = dayRecords.isNotEmpty;

      DailySalaryStatus status;
      double dayRegular = 0.0;
      double dayOt = 0.0;
      double dayEmergency = 0.0;
      bool isPayable = false;
      double fixedCredit = 0.0;
      double varCredit = 0.0;
      double otCredit = 0.0;
      DateTime? checkIn;
      DateTime? checkOut;
      String? remarks;
      int siteVisits = 0;

      if (hasAttendance) {
        final dayTimesheets = TimesheetCalculator.calculateDailyTimesheets(
          dayRecords,
          targetEmployeeId: empId,
          targetEmployeeName: empName,
        );

        if (dayTimesheets.isNotEmpty) {
          final t = dayTimesheets.first;
          dayRegular = t.regularHours;
          dayOt = t.overtimeHours;
          dayEmergency = t.emergencyDutyHours;
          checkIn = t.checkInTime;
          checkOut = t.checkOutTime;
          remarks = t.remarks;
          siteVisits = t.siteVisits.length;
        }

        totalRegularHours += dayRegular;
        totalOvertimeHours += dayOt;
        totalEmergencyHours += dayEmergency;
        daysWorked++;

        if (isSunday) {
          status = DailySalaryStatus.sundayDuty;
        } else {
          status = DailySalaryStatus.present;
        }

        isPayable = true;
        fixedCredit = dailyFixedRate;
        varCredit = dailyVariableRate;
        otCredit = dayOt * otHourlyRate;
      } else if (isFuture) {
        status = DailySalaryStatus.futureDay;
        isPayable = false;
      } else if (isSunday) {
        // Condition 1: Did the employee work on Monday (the day immediately after this Sunday)?
        // User rule: "if employee worked in monday, then consider day before i.e sunday, consider as payable"
        final nextMonday = date.add(const Duration(days: 1));
        final nextMondayKey = DateFormat('yyyy-MM-dd').format(nextMonday);
        final bool workedOnMonday = config.paySundayIfMondayWorked &&
            (workedDateKeys.contains(nextMondayKey) || allWorkedDateKeys.contains(nextMondayKey));

        // Condition 2: In-between Sunday weekly off rule:
        // A Sunday is paid if the employee worked prior to this Sunday (in cycle)
        // AND worked after this Sunday (in cycle or within subsequent working days).
        bool hasWorkedBefore = false;
        for (int b = i - 1; b >= 0; b--) {
          final prevKey = DateFormat('yyyy-MM-dd').format(allDates[b]);
          if (workedDateKeys.contains(prevKey) || allWorkedDateKeys.contains(prevKey)) {
            hasWorkedBefore = true;
            break;
          }
        }

        bool hasWorkedAfter = false;
        for (int a = i + 1; a < allDates.length; a++) {
          final nextKey = DateFormat('yyyy-MM-dd').format(allDates[a]);
          if (workedDateKeys.contains(nextKey) || allWorkedDateKeys.contains(nextKey)) {
            hasWorkedAfter = true;
            break;
          }
        }

        final bool isPaidSunday = workedOnMonday || (hasWorkedBefore && hasWorkedAfter);

        // An in-between Sunday or Sunday preceding a worked Monday is credited as paid
        if (isPaidSunday) {
          status = DailySalaryStatus.paidSundayOff;
          isPayable = true;
          fixedCredit = dailyFixedRate;
          varCredit = dailyVariableRate;
          otCredit = 0.0;
          paidSundays++;
          remarks = workedOnMonday
              ? 'Paid Sunday Off (Worked on Monday)'
              : 'Paid Sunday Off (In-Between Weekly Off)';
        } else {
          status = DailySalaryStatus.unpaidSundayOff;
          isPayable = false;
          unpaidSundays++;
          remarks = 'Unpaid Sunday';
        }
      } else {
        // Monday through Saturday without attendance
        status = DailySalaryStatus.absent;
        isPayable = false;
        absentDays++;
      }

      final double dayTotal = fixedCredit + varCredit + otCredit;

      if (isPayable) {
        cumulativePayableDays++;
        cumulativeSalary += dayTotal;
      }

      dailyRecords.add(
        DailySalaryRecord(
          date: date,
          dayOfWeek: date.weekday,
          status: status,
          regularHours: dayRegular,
          overtimeHours: dayOt,
          emergencyDutyHours: dayEmergency,
          isPayable: isPayable,
          dailyFixedCredit: fixedCredit,
          dailyVariableCredit: varCredit,
          dailyOtCredit: otCredit,
          dailyTotalSalary: dayTotal,
          cumulativePayableDays: cumulativePayableDays,
          cumulativeSalary: cumulativeSalary,
          checkInTime: checkIn,
          checkOutTime: checkOut,
          remarks: remarks,
          siteVisitsCount: siteVisits,
        ),
      );
    }

    final totalPayableDays = daysWorked + paidSundays;
    final earnedFixed = totalPayableDays * dailyFixedRate;
    final earnedVariable = totalPayableDays * dailyVariableRate;
    final double earnedOt;
    if (config.otIncludedInVariable || totalPayableDays == 0) {
      earnedOt = 0.0;
    } else if (config.customMonthlyOtAmount != null) {
      earnedOt = config.customMonthlyOtAmount!;
    } else {
      earnedOt = totalOvertimeHours * otHourlyRate;
    }
    final grossTotal = earnedFixed + earnedVariable + earnedOt;

    // If a custom monthly OT amount is set, adjust daily records' OT credit and cumulative salary
    if (config.customMonthlyOtAmount != null && !config.otIncludedInVariable && totalPayableDays > 0) {
      int cumDays = 0;
      double cumSal = 0.0;
      for (int i = 0; i < dailyRecords.length; i++) {
        final r = dailyRecords[i];
        double adjustedOt = 0.0;
        if (totalOvertimeHours > 0 && r.overtimeHours > 0) {
          adjustedOt = (r.overtimeHours / totalOvertimeHours) * config.customMonthlyOtAmount!;
        }
        final dayTotal = r.dailyFixedCredit + r.dailyVariableCredit + adjustedOt;
        if (r.isPayable) {
          cumDays++;
          cumSal += dayTotal;
        }
        dailyRecords[i] = DailySalaryRecord(
          date: r.date,
          dayOfWeek: r.dayOfWeek,
          status: r.status,
          regularHours: r.regularHours,
          overtimeHours: r.overtimeHours,
          emergencyDutyHours: r.emergencyDutyHours,
          isPayable: r.isPayable,
          dailyFixedCredit: r.dailyFixedCredit,
          dailyVariableCredit: r.dailyVariableCredit,
          dailyOtCredit: adjustedOt,
          dailyTotalSalary: dayTotal,
          cumulativePayableDays: cumDays,
          cumulativeSalary: cumSal,
          checkInTime: r.checkInTime,
          checkOutTime: r.checkOutTime,
          remarks: r.remarks,
          siteVisitsCount: r.siteVisitsCount,
        );
      }
    }

    // Strictly checks for attendance entered via the calendar-type date-only dialog.
    final bool isCalendarAttendance = cycleRecords.isNotEmpty &&
        cycleRecords.any((r) =>
            r.deviceId == 'OFFICE_CALENDAR_ENTRY' ||
            r.remarks == 'Office Attendance (Calendar)' ||
            r.id.startsWith('office_') ||
            r.address.contains('Calendar Entry'));

    return EmployeeSalarySummary(
      employeeCode: empCode,
      employeeId: empId,
      employeeName: empName,
      department: empDept,
      designation: empDesig,
      cycle: cycle,
      config: config,
      daysWorked: daysWorked,
      paidSundays: paidSundays,
      totalPayableDays: totalPayableDays,
      unpaidSundays: unpaidSundays,
      absentDays: absentDays,
      totalRegularHours: totalRegularHours,
      totalOvertimeHours: totalOvertimeHours,
      totalEmergencyHours: totalEmergencyHours,
      hourlyOtRate: otHourlyRate,
      earnedFixedSalary: earnedFixed,
      earnedVariableSalary: earnedVariable,
      earnedOtSalary: earnedOt,
      grossTotalSalary: grossTotal,
      dailyRecords: dailyRecords,
      isCalendarAttendance: isCalendarAttendance,
    );
  }

  /// Checks if an employee is an owner or non-salary personnel (e.g. Nasurudeen, Sirajudeen, Asik Saheel) who is not involved in monthly salary.
  static bool isExcludedOwner({
    String? name,
    String? code,
    String? email,
    String? id,
  }) {
    if (EmployeeDirectoryHelper.isRelievedEmployee(name: name, code: code, email: email, id: id)) {
      return true;
    }
    final n = (name ?? '').trim().toLowerCase();
    final c = (code ?? '').trim().toLowerCase();
    final em = (email ?? '').trim().toLowerCase();
    final i = (id ?? '').trim().toLowerCase();

    // Employee Alnaser Samsudeen (code 1058, naser@gmail.com) is an active technician entitled to salary
    if (c == '1058' || c == 'emp-1058' || i == '1058' || i == 'emp-1058') return false;
    if (n.contains('alnaser') || n.contains('al naser') || n.contains('al-naser') || n == 'naser') return false;
    if (em == 'naser@gmail.com' || em.startsWith('naser@')) return false;

    // Company Partner / Director: Nasurudeen (nasuru@fusionmaint.com)
    if (n.contains('nasurudeen') ||
        n.contains('nasrudeen') ||
        n.contains('nasruddin') ||
        n.contains('nasirudeen')) {
      return true;
    }
    if (em.contains('nasuru@') || em.contains('nasur@fusionmaint')) {
      return true;
    }

    // Sirajudeen / Siraj
    if (n.contains('siraj') || n.contains('sirajudeen') || n.contains('sirajuddin')) {
      return true;
    }
    if (em.contains('siraj')) {
      return true;
    }

    // Asik Saheel
    if (n.contains('asik') || n.contains('saheel') || n.contains('ashik') || n.contains('sahil')) {
      return true;
    }
    if (em.contains('asik') || em.contains('saheel') || em.contains('ashik') || em.contains('sahil')) {
      return true;
    }

    return false;
  }

  /// Resolves the EmployeeSalaryConfig for a given employee from the configurations map,
  /// falling back to matching by employeeCode, id, name, or a default 1200/600 config.
  static EmployeeSalaryConfig resolveConfig({
    required EmployeeEntity employee,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) {
    EmployeeSalaryConfig? config = salaryConfigs[employee.employeeCode] ??
        salaryConfigs[employee.id] ??
        salaryConfigs[employee.name.toLowerCase().trim()];

    if (config == null) {
      for (final entry in salaryConfigs.entries) {
        if (EmployeeDirectoryHelper.matchesEmployeeIdentity(
          recordEmployeeId: entry.key,
          recordEmployeeName: entry.value.employeeName,
          employeeId: employee.id,
          employeeCode: employee.employeeCode,
          employeeName: employee.name,
          employeeEmail: employee.email,
        )) {
          config = entry.value;
          break;
        }
      }
    }

    return config ??
        EmployeeSalaryConfig(
          employeeCode: employee.employeeCode,
          employeeId: employee.id,
          employeeName: employee.name,
          department: employee.department.isNotEmpty ? employee.department : 'General',
          fixedSalary: 1200.0,
          variableSalary: 600.0,
        );
  }

  /// Calculates salary summaries for all employees in a list
  static WorkforceSalarySummary calculateWorkforcePayroll({
    required List<EmployeeEntity> employees,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
    required List<AttendanceRecord> records,
    required SalaryCycle cycle,
    DateTime? referenceDate,
  }) {
    final List<EmployeeSalarySummary> summaries = [];

    for (final emp in employees) {
      // Exclude company owners and non-payroll personnel (Nasurudeen, Sirajudeen, Asik Saheel)
      if (isExcludedOwner(name: emp.name, code: emp.employeeCode, email: emp.email, id: emp.id)) {
        continue;
      }
      final config = resolveConfig(employee: emp, salaryConfigs: salaryConfigs);

      final summary = calculateEmployeeSalary(
        config: config,
        employee: emp,
        records: records,
        cycle: cycle,
        referenceDate: referenceDate,
      );
      summaries.add(summary);
    }

    return WorkforceSalarySummary.fromSummaries(cycle, summaries);
  }
}

