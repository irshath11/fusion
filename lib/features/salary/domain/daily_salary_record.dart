enum DailySalaryStatus {
  present,
  paidSundayOff,
  sundayDuty,
  absent,
  unpaidSundayOff,
  futureDay,
}

extension DailySalaryStatusExtension on DailySalaryStatus {
  String get label {
    switch (this) {
      case DailySalaryStatus.present:
        return 'Present';
      case DailySalaryStatus.paidSundayOff:
        return 'Paid Sunday Off';
      case DailySalaryStatus.sundayDuty:
        return 'Sunday Duty';
      case DailySalaryStatus.absent:
        return 'Absent / Leave';
      case DailySalaryStatus.unpaidSundayOff:
        return 'Unpaid Sunday';
      case DailySalaryStatus.futureDay:
        return 'Upcoming';
    }
  }

  bool get isPayable {
    switch (this) {
      case DailySalaryStatus.present:
      case DailySalaryStatus.paidSundayOff:
      case DailySalaryStatus.sundayDuty:
        return true;
      case DailySalaryStatus.absent:
      case DailySalaryStatus.unpaidSundayOff:
      case DailySalaryStatus.futureDay:
        return false;
    }
  }
}

/// Represents the day-wise salary calculation and breakdown for a single calendar day
class DailySalaryRecord {
  final DateTime date;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final DailySalaryStatus status;
  final double regularHours;
  final double overtimeHours;
  final double emergencyDutyHours;
  final bool isPayable;

  /// Fixed salary earned for this day (Fixed / 30 if payable, else 0.0)
  final double dailyFixedCredit;

  /// Variable salary earned for this day (Variable / 30 if payable, else 0.0)
  final double dailyVariableCredit;

  /// Overtime amount earned for this day (overtimeHours * otHourlyRate)
  final double dailyOtCredit;

  /// Total salary credited for this specific day (Fixed + Variable + OT)
  final double dailyTotalSalary;

  /// Running count of cumulative payable days up to this day
  final int cumulativePayableDays;

  /// Running sum of cumulative salary earned up to this day
  final double cumulativeSalary;

  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? remarks;
  final int siteVisitsCount;

  DailySalaryRecord({
    required this.date,
    required this.dayOfWeek,
    required this.status,
    this.regularHours = 0.0,
    this.overtimeHours = 0.0,
    this.emergencyDutyHours = 0.0,
    required this.isPayable,
    required this.dailyFixedCredit,
    required this.dailyVariableCredit,
    required this.dailyOtCredit,
    required this.dailyTotalSalary,
    required this.cumulativePayableDays,
    required this.cumulativeSalary,
    this.checkInTime,
    this.checkOutTime,
    this.remarks,
    this.siteVisitsCount = 0,
  });

  bool get isSunday => date.weekday == DateTime.sunday;
  double get totalHours => regularHours + overtimeHours;
}

