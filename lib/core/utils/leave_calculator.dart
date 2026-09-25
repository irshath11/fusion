import 'package:intl/intl.dart';
import '../../features/admin/domain/employee_entity.dart';
import '../../features/attendance/domain/attendance_record.dart';
import 'salary_cycle_helper.dart';
import 'timesheet_calculator.dart';

/// Categorization of a specific calendar day in the leave and attendance ledger.
/// Sunday is the only designated weekly off / leave day in each week.
enum LeaveDayType {
  /// Regular working day (Mon–Sat) with attendance logged.
  present,

  /// Scheduled working day (Mon–Sat) with NO attendance logged (Leave / Absent).
  leaveAbsent,

  /// Sunday with NO attendance logged (Standard Weekly Off / Leave).
  sundayWeeklyOff,

  /// Sunday WITH attendance logged (Duty worked on Weekly Off).
  sundayDuty,

  /// Future date within the cycle that has not occurred yet.
  futureDay,
}

extension LeaveDayTypeExtension on LeaveDayType {
  String get label {
    switch (this) {
      case LeaveDayType.present:
        return 'Present';
      case LeaveDayType.leaveAbsent:
        return 'Leave / Absent';
      case LeaveDayType.sundayWeeklyOff:
        return 'Sunday (Weekly Off)';
      case LeaveDayType.sundayDuty:
        return 'Sunday Duty (Worked)';
      case LeaveDayType.futureDay:
        return 'Upcoming';
    }
  }

  String get shortLabel {
    switch (this) {
      case LeaveDayType.present:
        return 'Present';
      case LeaveDayType.leaveAbsent:
        return 'Leave';
      case LeaveDayType.sundayWeeklyOff:
        return 'Weekly Off';
      case LeaveDayType.sundayDuty:
        return 'Sun Duty';
      case LeaveDayType.futureDay:
        return 'Upcoming';
    }
  }
}

/// Representation of a single calendar day's leave or attendance status for an employee.
class DailyLeaveRecord {
  final DateTime date;
  final LeaveDayType type;
  final double regularHours;
  final double overtimeHours;
  final double totalHours;
  final String? remarks;
  final List<AttendanceRecord> records;

  DailyLeaveRecord({
    required this.date,
    required this.type,
    this.regularHours = 0.0,
    this.overtimeHours = 0.0,
    this.totalHours = 0.0,
    this.remarks,
    this.records = const [],
  });

  bool get isSunday => date.weekday == DateTime.sunday;
  bool get isWorkingDay => !isSunday;
  bool get isWorked =>
      type == LeaveDayType.present || type == LeaveDayType.sundayDuty;
  bool get isLeave => type == LeaveDayType.leaveAbsent;
  bool get isWeeklyOff => type == LeaveDayType.sundayWeeklyOff;
  bool get isFuture => type == LeaveDayType.futureDay;

  String get formattedDate => DateFormat('yyyy-MM-dd').format(date);
  String get dayOfWeek => DateFormat('EEEE').format(date);
  String get shortDayOfWeek => DateFormat('EEE').format(date);
  String get displayDate => DateFormat('dd MMM yyyy').format(date);
  String get fullDisplay => '$dayOfWeek, $displayDate';
}

/// Comprehensive leave and attendance summary for an employee within a Salary Cycle.
class EmployeeLeaveSummary {
  final EmployeeEntity employee;
  final SalaryCycle cycle;

  /// Total calendar days spanned by this cycle (typically 30 or 31).
  final int totalCycleDays;

  /// Total number of Sundays in the cycle.
  final int totalSundays;

  /// Expected working days in the entire cycle (Mon–Sat = totalCycleDays - totalSundays).
  final int expectedWorkingDays;

  /// Calendar days elapsed from cycle start up to current date (clamped to cycle).
  final int elapsedDays;

  /// Expected working days elapsed up to current date.
  final int elapsedWorkingDays;

  /// Sundays elapsed up to current date.
  final int elapsedSundays;

  /// Total days the employee logged attendance (Mon–Sat + Sundays).
  final int daysWorked;

  /// Working days (Mon–Sat) the employee logged attendance.
  final int workingDaysPresent;

  /// Sundays on which the employee logged attendance.
  final int sundayDutyDays;

  /// Leave days taken: Elapsed working days (Mon–Sat) where employee did NOT work.
  final int leaveDays;

  /// Sundays elapsed where employee took the scheduled weekly off.
  final int sundayWeeklyOffs;

  /// Total leaves recorded: Working days missed (leaves) + Sunday weekly offs taken.
  final int totalLeaveDays;

  /// Attendance percentage on elapsed working days (0.0 to 100.0).
  final double attendancePercentage;

  /// Detailed day-by-day record list for the entire cycle.
  final List<DailyLeaveRecord> dailyRecords;

  EmployeeLeaveSummary({
    required this.employee,
    required this.cycle,
    required this.totalCycleDays,
    required this.totalSundays,
    required this.expectedWorkingDays,
    required this.elapsedDays,
    required this.elapsedWorkingDays,
    required this.elapsedSundays,
    required this.daysWorked,
    required this.workingDaysPresent,
    required this.sundayDutyDays,
    required this.leaveDays,
    required this.sundayWeeklyOffs,
    required this.totalLeaveDays,
    required this.attendancePercentage,
    required this.dailyRecords,
  });

  /// Filtered list of only the days where employee took leave / was absent.
  List<DailyLeaveRecord> get leaveDaysOnly =>
      dailyRecords.where((d) => d.type == LeaveDayType.leaveAbsent).toList();

  /// Filtered list of all Sunday weekly offs.
  List<DailyLeaveRecord> get sundayOffsOnly =>
      dailyRecords.where((d) => d.type == LeaveDayType.sundayWeeklyOff).toList();

  /// Filtered list of all present days (including Sunday duties).
  List<DailyLeaveRecord> get workedDaysOnly =>
      dailyRecords.where((d) => d.isWorked).toList();
}

/// Aggregate workforce leave statistics.
class WorkforceLeaveMetrics {
  final SalaryCycle cycle;
  final int totalEmployees;
  final int totalWorkforceWorkingDays;
  final int totalWorkforceDaysWorked;
  final int totalWorkforceLeavesTaken;
  final int totalWorkforceSundayOffs;
  final int totalWorkforceSundayDuties;
  final double averageAttendanceRate;

  WorkforceLeaveMetrics({
    required this.cycle,
    required this.totalEmployees,
    required this.totalWorkforceWorkingDays,
    required this.totalWorkforceDaysWorked,
    required this.totalWorkforceLeavesTaken,
    required this.totalWorkforceSundayOffs,
    required this.totalWorkforceSundayDuties,
    required this.averageAttendanceRate,
  });
}

/// Core Calculator for Employee Leave Records based on:
/// - Sunday is the ONLY designated day of leave / weekly off in a week.
/// - Monday through Saturday are scheduled working days.
class LeaveCalculator {
  /// Matches an attendance record to an employee by id, name, or employeeCode
  static bool _recordMatchesEmployee(AttendanceRecord r, EmployeeEntity emp) {
    if (r.employeeId.isNotEmpty &&
        (r.employeeId == emp.id || r.employeeId == emp.employeeCode)) {
      return true;
    }
    if (r.employeeName.trim().isNotEmpty &&
        emp.name.trim().isNotEmpty &&
        r.employeeName.trim().toLowerCase() == emp.name.trim().toLowerCase()) {
      return true;
    }
    return false;
  }

  /// Calculates the complete Leave Summary and day-by-day ledger for an employee
  static EmployeeLeaveSummary calculateEmployeeLeave(
    EmployeeEntity employee,
    List<AttendanceRecord> records,
    SalaryCycle cycle, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Filter records belonging to this employee within the cycle
    final empRecords = records
        .where((r) =>
            cycle.contains(r.eventTimestamp) &&
            _recordMatchesEmployee(r, employee))
        .toList();

    // Map records by calendar date (yyyy-MM-dd)
    final Map<String, List<AttendanceRecord>> recordsByDate = {};
    for (final r in empRecords) {
      final key = DateFormat('yyyy-MM-dd').format(r.eventTimestamp.toLocal());
      recordsByDate.putIfAbsent(key, () => []).add(r);
    }

    final List<DailyLeaveRecord> dailyRecords = [];

    int totalSundays = 0;
    int elapsedDays = 0;
    int elapsedWorkingDays = 0;
    int elapsedSundays = 0;

    int daysWorked = 0;
    int workingDaysPresent = 0;
    int sundayDutyDays = 0;
    int leaveDays = 0;
    int sundayWeeklyOffs = 0;

    // Iterate day-by-day from cycle.startDate to cycle.endDate
    final int cycleDaysCount = cycle.totalDays;
    final DateTime startMidnight = DateTime(
      cycle.startDate.year,
      cycle.startDate.month,
      cycle.startDate.day,
    );

    for (int i = 0; i < cycleDaysCount; i++) {
      final date = startMidnight.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final isSunday = date.weekday == DateTime.sunday;
      if (isSunday) totalSundays++;

      final isPastOrToday = !date.isAfter(todayMidnight);
      if (isPastOrToday) {
        elapsedDays++;
        if (isSunday) {
          elapsedSundays++;
        } else {
          elapsedWorkingDays++;
        }
      }

      final dayRecords = recordsByDate[dateKey] ?? [];
      final hasAttendance = dayRecords.isNotEmpty;

      LeaveDayType dayType;
      double regHours = 0.0;
      double otHours = 0.0;

      if (!isPastOrToday) {
        dayType = LeaveDayType.futureDay;
      } else if (isSunday) {
        if (hasAttendance) {
          dayType = LeaveDayType.sundayDuty;
          sundayDutyDays++;
          daysWorked++;
        } else {
          dayType = LeaveDayType.sundayWeeklyOff;
          sundayWeeklyOffs++;
        }
      } else {
        // Monday through Saturday (Working Day)
        if (hasAttendance) {
          dayType = LeaveDayType.present;
          workingDaysPresent++;
          daysWorked++;
        } else {
          dayType = LeaveDayType.leaveAbsent;
          leaveDays++;
        }
      }

      if (hasAttendance) {
        final dayTimesheets =
            TimesheetCalculator.calculateDailyTimesheets(dayRecords);
        if (dayTimesheets.isNotEmpty) {
          regHours = dayTimesheets.first.regularHours;
          otHours = dayTimesheets.first.overtimeHours;
        }
      }

      dailyRecords.add(
        DailyLeaveRecord(
          date: date,
          type: dayType,
          regularHours: regHours,
          overtimeHours: otHours,
          totalHours: regHours + otHours,
          remarks: dayRecords.isNotEmpty ? dayRecords.first.remarks : null,
          records: dayRecords,
        ),
      );
    }

    final int expectedWorkingDays = cycleDaysCount - totalSundays;
    final double attendancePct = elapsedWorkingDays > 0
        ? (workingDaysPresent / elapsedWorkingDays * 100.0).clamp(0.0, 100.0)
        : 100.0;

    return EmployeeLeaveSummary(
      employee: employee,
      cycle: cycle,
      totalCycleDays: cycleDaysCount,
      totalSundays: totalSundays,
      expectedWorkingDays: expectedWorkingDays,
      elapsedDays: elapsedDays,
      elapsedWorkingDays: elapsedWorkingDays,
      elapsedSundays: elapsedSundays,
      daysWorked: daysWorked,
      workingDaysPresent: workingDaysPresent,
      sundayDutyDays: sundayDutyDays,
      leaveDays: leaveDays,
      sundayWeeklyOffs: sundayWeeklyOffs,
      totalLeaveDays: leaveDays + sundayWeeklyOffs,
      attendancePercentage: attendancePct,
      dailyRecords: dailyRecords,
    );
  }

  /// Calculates leave summaries for all employees in a list
  static List<EmployeeLeaveSummary> calculateWorkforceLeaveSummaries(
    List<EmployeeEntity> employees,
    List<AttendanceRecord> allRecords,
    SalaryCycle cycle, {
    DateTime? referenceDate,
  }) {
    return employees
        .map((emp) => calculateEmployeeLeave(
              emp,
              allRecords,
              cycle,
              referenceDate: referenceDate,
            ))
        .toList();
  }

  /// Calculates aggregate metrics across all employees
  static WorkforceLeaveMetrics calculateWorkforceMetrics(
    List<EmployeeLeaveSummary> summaries,
    SalaryCycle cycle,
  ) {
    if (summaries.isEmpty) {
      return WorkforceLeaveMetrics(
        cycle: cycle,
        totalEmployees: 0,
        totalWorkforceWorkingDays: 0,
        totalWorkforceDaysWorked: 0,
        totalWorkforceLeavesTaken: 0,
        totalWorkforceSundayOffs: 0,
        totalWorkforceSundayDuties: 0,
        averageAttendanceRate: 100.0,
      );
    }

    int totalWorkingDays = 0;
    int totalDaysWorked = 0;
    int totalLeaves = 0;
    int totalSundayOffs = 0;
    int totalSundayDuties = 0;
    double sumAttendanceRate = 0.0;

    for (final s in summaries) {
      totalWorkingDays += s.elapsedWorkingDays;
      totalDaysWorked += s.daysWorked;
      totalLeaves += s.leaveDays;
      totalSundayOffs += s.sundayWeeklyOffs;
      totalSundayDuties += s.sundayDutyDays;
      sumAttendanceRate += s.attendancePercentage;
    }

    return WorkforceLeaveMetrics(
      cycle: cycle,
      totalEmployees: summaries.length,
      totalWorkforceWorkingDays: totalWorkingDays,
      totalWorkforceDaysWorked: totalDaysWorked,
      totalWorkforceLeavesTaken: totalLeaves,
      totalWorkforceSundayOffs: totalSundayOffs,
      totalWorkforceSundayDuties: totalSundayDuties,
      averageAttendanceRate: sumAttendanceRate / summaries.length,
    );
  }
}
