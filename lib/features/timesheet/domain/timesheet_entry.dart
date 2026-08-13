import 'package:equatable/equatable.dart';

class SiteVisitSummary extends Equatable {
  final String siteName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;

  const SiteVisitSummary({
    required this.siteName,
    required this.checkInTime,
    this.checkOutTime,
  });

  Duration get duration {
    if (checkOutTime == null) return Duration.zero;
    return checkOutTime!.difference(checkInTime);
  }

  @override
  List<Object?> get props => [siteName, checkInTime, checkOutTime];
}

class DailyTimesheetEntry extends Equatable {
  final DateTime date;
  final String employeeId;
  final String employeeName;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final Duration totalDuration;
  final double regularHours;
  final double overtimeHours;
  final int stepCount;
  final bool isCompleted;
  final bool isAutoCompleted;
  final List<SiteVisitSummary> siteVisits;

  const DailyTimesheetEntry({
    required this.date,
    required this.employeeId,
    required this.employeeName,
    this.checkInTime,
    this.checkOutTime,
    required this.totalDuration,
    required this.regularHours,
    required this.overtimeHours,
    this.stepCount = 0,
    this.isCompleted = false,
    this.isAutoCompleted = false,
    this.siteVisits = const [],
  });

  double get totalHours => totalDuration.inMinutes / 60.0;

  @override
  List<Object?> get props => [
        date,
        employeeId,
        employeeName,
        checkInTime,
        checkOutTime,
        totalDuration,
        regularHours,
        overtimeHours,
        stepCount,
        isCompleted,
        isAutoCompleted,
        siteVisits,
      ];
}

class SiteEmployeeContribution extends Equatable {
  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final String department;
  final double totalHours;
  final int visitCount;

  const SiteEmployeeContribution({
    required this.employeeId,
    required this.employeeName,
    this.employeeCode = 'EMP',
    this.department = 'Operations',
    required this.totalHours,
    required this.visitCount,
  });

  @override
  List<Object?> get props => [
        employeeId,
        employeeName,
        employeeCode,
        department,
        totalHours,
        visitCount,
      ];
}

class SiteManHourSummary extends Equatable {
  final String siteName;
  final String clientGroup;
  final double totalHours;
  final int totalVisits;
  final int distinctEmployeesCount;
  final List<SiteEmployeeContribution> employeeContributions;

  const SiteManHourSummary({
    required this.siteName,
    required this.clientGroup,
    required this.totalHours,
    required this.totalVisits,
    required this.distinctEmployeesCount,
    required this.employeeContributions,
  });

  @override
  List<Object?> get props => [
        siteName,
        clientGroup,
        totalHours,
        totalVisits,
        distinctEmployeesCount,
        employeeContributions,
      ];
}

