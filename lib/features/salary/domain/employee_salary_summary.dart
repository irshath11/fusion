import '../../../core/utils/salary_cycle_helper.dart';
import 'employee_salary_config.dart';
import 'daily_salary_record.dart';

/// Aggregated salary cycle summary and day-by-day calculations for an individual employee
class EmployeeSalarySummary {
  final String employeeCode;
  final String? employeeId;
  final String employeeName;
  final String department;
  final String designation;
  final SalaryCycle cycle;
  final EmployeeSalaryConfig config;

  /// Actual days the employee clocked in and worked
  final int daysWorked;

  /// Number of qualifying in-between Sunday weekly offs credited
  final int paidSundays;

  /// Total payable days (daysWorked + paidSundays, e.g. 8 + 1 = 9)
  final int totalPayableDays;

  /// Non-qualifying unpaid Sundays
  final int unpaidSundays;

  /// Working days missed (absent)
  final int absentDays;

  /// Total regular hours logged
  final double totalRegularHours;

  /// Total overtime (OT) hours logged
  final double totalOvertimeHours;

  /// Emergency callout duty hours logged
  final double totalEmergencyHours;

  /// Overtime hourly rate (Fixed / 240 or custom)
  final double hourlyOtRate;

  /// Earned Fixed Salary = totalPayableDays * (fixedSalary / 30)
  final double earnedFixedSalary;

  /// Earned Variable Salary = totalPayableDays * (variableSalary / 30) + interimOtSalary (for Nov 2026)
  final double earnedVariableSalary;

  /// Base earned variable before interim OT addition
  final double baseVariableSalary;

  /// Interim Overtime hours earned during 26-31 Oct 2026 transition period (credited to Nov)
  final double interimOtHours;

  /// Interim Overtime salary amount earned during 26-31 Oct 2026 transition period (credited to Nov)
  final double interimOtSalary;

  /// Earned Overtime Salary = totalOvertimeHours * hourlyOtRate
  final double earnedOtSalary;

  /// Gross Total Salary = earnedFixedSalary + earnedVariableSalary + earnedOtSalary
  final double grossTotalSalary;

  /// Complete day-wise ledger for each day in the salary cycle
  final List<DailySalaryRecord> dailyRecords;

  /// True strictly if attendance was entered via the newly added calendar-type date-only dialog (deviceId: 'OFFICE_CALENDAR_ENTRY')
  final bool isCalendarAttendance;

  /// Alias for backward compatibility with manual attendance references
  bool get isManualAttendance => isCalendarAttendance;

  EmployeeSalarySummary({
    required this.employeeCode,
    this.employeeId,
    required this.employeeName,
    required this.department,
    this.designation = '',
    required this.cycle,
    required this.config,
    required this.daysWorked,
    required this.paidSundays,
    required this.totalPayableDays,
    required this.unpaidSundays,
    required this.absentDays,
    required this.totalRegularHours,
    required this.totalOvertimeHours,
    required this.totalEmergencyHours,
    required this.hourlyOtRate,
    required this.earnedFixedSalary,
    required this.earnedVariableSalary,
    double? baseVariableSalary,
    this.interimOtHours = 0.0,
    this.interimOtSalary = 0.0,
    required this.earnedOtSalary,
    required this.grossTotalSalary,
    required this.dailyRecords,
    this.isCalendarAttendance = false,
  }) : baseVariableSalary = baseVariableSalary ?? earnedVariableSalary;

  /// Base base salary configuration (Fixed + Variable)
  double get monthlyBaseTotal => config.monthlyBaseTotal;

  /// Total combined hours (Regular + OT)
  double get totalCombinedHours => totalRegularHours + totalOvertimeHours;

  /// Base earned before OT (Fixed + Variable)
  double get earnedBaseTotal => earnedFixedSalary + earnedVariableSalary;
}

/// Aggregated workforce-level payroll totals for an organization or division
class WorkforceSalarySummary {
  final SalaryCycle cycle;
  final List<EmployeeSalarySummary> employeeSummaries;
  final double totalPayroll;
  final double totalFixedEarned;
  final double totalVariableEarned;
  final double totalOtEarned;
  final double totalOtHours;
  final double totalInterimOtEarned;
  final double totalInterimOtHours;
  final int totalWorkforceDaysWorked;
  final int totalWorkforcePaidSundays;
  final int totalWorkforcePayableDays;

  WorkforceSalarySummary({
    required this.cycle,
    required this.employeeSummaries,
    required this.totalPayroll,
    required this.totalFixedEarned,
    required this.totalVariableEarned,
    required this.totalOtEarned,
    required this.totalOtHours,
    this.totalInterimOtEarned = 0.0,
    this.totalInterimOtHours = 0.0,
    required this.totalWorkforceDaysWorked,
    required this.totalWorkforcePaidSundays,
    required this.totalWorkforcePayableDays,
  });

  factory WorkforceSalarySummary.fromSummaries(
    SalaryCycle cycle,
    List<EmployeeSalarySummary> summaries,
  ) {
    double payroll = 0.0;
    double fixed = 0.0;
    double variable = 0.0;
    double ot = 0.0;
    double otHours = 0.0;
    double interimOt = 0.0;
    double interimOtHours = 0.0;
    int worked = 0;
    int sundays = 0;
    int payable = 0;

    for (final s in summaries) {
      payroll += s.grossTotalSalary;
      fixed += s.earnedFixedSalary;
      variable += s.earnedVariableSalary;
      ot += s.earnedOtSalary;
      otHours += s.totalOvertimeHours;
      interimOt += s.interimOtSalary;
      interimOtHours += s.interimOtHours;
      worked += s.daysWorked;
      sundays += s.paidSundays;
      payable += s.totalPayableDays;
    }

    return WorkforceSalarySummary(
      cycle: cycle,
      employeeSummaries: summaries,
      totalPayroll: payroll,
      totalFixedEarned: fixed,
      totalVariableEarned: variable,
      totalOtEarned: ot,
      totalOtHours: otHours,
      totalInterimOtEarned: interimOt,
      totalInterimOtHours: interimOtHours,
      totalWorkforceDaysWorked: worked,
      totalWorkforcePaidSundays: sundays,
      totalWorkforcePayableDays: payable,
    );
  }
}

