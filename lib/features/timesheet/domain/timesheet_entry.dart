import 'package:equatable/equatable.dart';

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
      ];
}
