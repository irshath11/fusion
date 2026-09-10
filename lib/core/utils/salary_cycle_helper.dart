import 'package:intl/intl.dart';
import '../../features/attendance/domain/attendance_record.dart';
import '../../features/timesheet/domain/timesheet_entry.dart';

/// Represents an organizational Salary Cycle running from 25th of a month to 24th of the next month.
class SalaryCycle {
  /// Start timestamp: 25th of the start month at 00:00:00.000
  final DateTime startDate;

  /// End timestamp: 24th of the end month at 23:59:59.999
  final DateTime endDate;

  /// The month for which this salary cycle applies (the ending month, where 24th occurs)
  final int salaryMonth;

  /// The year for which this salary cycle applies
  final int salaryYear;

  SalaryCycle({
    required this.startDate,
    required this.endDate,
    required this.salaryMonth,
    required this.salaryYear,
  });

  /// Factory to construct a SalaryCycle for a given target date.
  /// If day is >= 25, the cycle runs from 25th of current month to 24th of next month.
  /// If day is < 25, the cycle runs from 25th of previous month to 24th of current month.
  factory SalaryCycle.fromDate(DateTime date) {
    final localDate = date.toLocal();
    final int year = localDate.year;
    final int month = localDate.month;
    final int day = localDate.day;

    DateTime start;
    DateTime end;
    int salMonth;
    int salYear;

    if (day >= 25) {
      start = DateTime(year, month, 25, 0, 0, 0, 0);
      final nextMonthDt = DateTime(year, month + 1, 1);
      end = DateTime(nextMonthDt.year, nextMonthDt.month, 24, 23, 59, 59, 999);
      salMonth = nextMonthDt.month;
      salYear = nextMonthDt.year;
    } else {
      final prevMonthDt = DateTime(year, month - 1, 1);
      start = DateTime(prevMonthDt.year, prevMonthDt.month, 25, 0, 0, 0, 0);
      end = DateTime(year, month, 24, 23, 59, 59, 999);
      salMonth = month;
      salYear = year;
    }

    return SalaryCycle(
      startDate: start,
      endDate: end,
      salaryMonth: salMonth,
      salaryYear: salYear,
    );
  }

  /// Current active salary cycle based on now()
  static SalaryCycle current([DateTime? referenceDate]) {
    return SalaryCycle.fromDate(referenceDate ?? DateTime.now());
  }

  /// Construct a SalaryCycle for a specific salary month and year
  /// (e.g. month: 9, year: 2026 => 25 Aug 2026 to 24 Sep 2026)
  factory SalaryCycle.forMonth(int year, int month) {
    final prevMonthDt = DateTime(year, month - 1, 1);
    final start = DateTime(prevMonthDt.year, prevMonthDt.month, 25, 0, 0, 0, 0);
    final end = DateTime(year, month, 24, 23, 59, 59, 999);
    return SalaryCycle(
      startDate: start,
      endDate: end,
      salaryMonth: month,
      salaryYear: year,
    );
  }

  /// Generates a list of recent cycles (default: 12 cycles in reverse chronological order)
  static List<SalaryCycle> getRecentCycles({int count = 12, DateTime? referenceDate}) {
    final currentCycle = SalaryCycle.current(referenceDate);
    final List<SalaryCycle> cycles = [];

    int curYear = currentCycle.salaryYear;
    int curMonth = currentCycle.salaryMonth;

    for (int i = 0; i < count; i++) {
      cycles.add(SalaryCycle.forMonth(curYear, curMonth));
      curMonth--;
      if (curMonth < 1) {
        curMonth = 12;
        curYear--;
      }
    }
    return cycles;
  }

  /// Check if a given date falls inside this salary cycle
  bool contains(DateTime date) {
    final t = date.toLocal();
    return !t.isBefore(startDate) && !t.isAfter(endDate);
  }

  /// Unique identifier key for dropdowns or caches (e.g. '2026-09')
  String get id => '$salaryYear-${salaryMonth.toString().padLeft(2, '0')}';

  /// Title for display: e.g. "Sep 2026 Cycle (25 Aug – 24 Sep)"
  String get title {
    final monthName = DateFormat('MMM yyyy').format(DateTime(salaryYear, salaryMonth, 1));
    return '$monthName Cycle (${DateFormat('dd MMM').format(startDate)} – ${DateFormat('dd MMM').format(endDate)})';
  }

  /// Short label: e.g. "25 Aug – 24 Sep 2026"
  String get shortPeriodLabel {
    return '${DateFormat('dd MMM').format(startDate)} – ${DateFormat('dd MMM yyyy').format(endDate)}';
  }

  /// Single month cycle name: e.g. "September 2026"
  String get salaryMonthName {
    return DateFormat('MMMM yyyy').format(DateTime(salaryYear, salaryMonth, 1));
  }

  /// Full period range string: e.g. "25 Aug 2026 – 24 Sep 2026"
  String get fullPeriodString {
    return '${DateFormat('dd MMM yyyy').format(startDate)} – ${DateFormat('dd MMM yyyy').format(endDate)}';
  }

  /// Total days spanned by this cycle (normally 30 or 31 days)
  int get totalDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Days elapsed from start date up to now (clamped to 0..totalDays)
  int get daysElapsed {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 0;
    if (now.isAfter(endDate)) return totalDays;
    return now.difference(startDate).inDays + 1;
  }

  /// Days remaining in this cycle
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    if (now.isBefore(startDate)) return totalDays;
    return endDate.difference(now).inDays + 1;
  }

  /// Fraction of cycle elapsed (0.0 to 1.0)
  double get progressFraction {
    if (totalDays <= 0) return 0.0;
    return (daysElapsed / totalDays).clamp(0.0, 1.0);
  }

  /// Filters a list of attendance records to only those within this salary cycle
  List<AttendanceRecord> filterRecords(List<AttendanceRecord> records) {
    return records.where((r) => contains(r.eventTimestamp)).toList();
  }

  /// Filters a list of daily timesheet entries to only those within this salary cycle
  List<DailyTimesheetEntry> filterTimesheets(List<DailyTimesheetEntry> entries) {
    return entries.where((e) => contains(e.date)).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalaryCycle &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Aggregated metrics for an employee or workforce within a salary cycle
class SalaryCycleMetrics {
  final SalaryCycle cycle;
  final double regularHours;
  final double overtimeHours;
  final double emergencyDutyHours;
  final double combinedHours;
  final int daysWorked;

  SalaryCycleMetrics({
    required this.cycle,
    required this.regularHours,
    required this.overtimeHours,
    required this.emergencyDutyHours,
    required this.combinedHours,
    required this.daysWorked,
  });

  factory SalaryCycleMetrics.fromEntries(SalaryCycle cycle, List<DailyTimesheetEntry> entries) {
    final filtered = cycle.filterTimesheets(entries);
    double reg = 0.0;
    double ot = 0.0;
    double emg = 0.0;

    for (final e in filtered) {
      reg += e.regularHours;
      ot += e.overtimeHours;
      emg += e.emergencyDutyHours;
    }

    return SalaryCycleMetrics(
      cycle: cycle,
      regularHours: reg,
      overtimeHours: ot,
      emergencyDutyHours: emg,
      combinedHours: reg + ot,
      daysWorked: filtered.length,
    );
  }
}
