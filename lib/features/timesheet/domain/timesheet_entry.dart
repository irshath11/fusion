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
  final Duration breakDuration;
  final double regularHours;
  final double overtimeHours;
  final int stepCount;
  final bool isCompleted;
  final List<SiteVisitSummary> siteVisits;

  const DailyTimesheetEntry({
    required this.date,
    required this.employeeId,
    required this.employeeName,
    this.checkInTime,
    this.checkOutTime,
    required this.totalDuration,
    this.breakDuration = Duration.zero,
    required this.regularHours,
    required this.overtimeHours,
    this.stepCount = 0,
    this.isCompleted = false,
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
        breakDuration,
        regularHours,
        overtimeHours,
        stepCount,
        isCompleted,
        siteVisits,
      ];
}
