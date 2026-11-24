import 'package:intl/intl.dart';
import '../../features/attendance/domain/attendance_record.dart';
import '../../features/timesheet/domain/timesheet_entry.dart';

/// Represents an organizational Salary Cycle.
///
/// Company Cycle History:
/// - From November 2026 onwards: Full calendar month cycle (1st of month 00:00:00 to last day of month 23:59:59).
/// - 26 Oct 2026 – 31 Oct 2026: October Transition Period (6-day gap between legacy cycle and new calendar cycle, specifically tracking Interim OT).
/// - Prior to 26 Oct 2026: Legacy 25th-to-24th cycle (e.g. 25 Aug – 24 Sep, 25 Sep – 25 Oct).
class SalaryCycle {
  /// Start timestamp: 00:00:00.000 of cycle start date
  final DateTime startDate;

  /// End timestamp: 23:59:59.999 of cycle end date
  final DateTime endDate;

  /// The month for which this salary cycle applies
  final int salaryMonth;

  /// The year for which this salary cycle applies
  final int salaryYear;

  /// Indicates if this cycle is the 6-day October transition period (26 Oct - 31 Oct 2026)
  final bool isTransition;

  final String? customTitle;
  final String? customShortLabel;
  final String? customId;

  SalaryCycle({
    required this.startDate,
    required this.endDate,
    required this.salaryMonth,
    required this.salaryYear,
    this.isTransition = false,
    this.customTitle,
    this.customShortLabel,
    this.customId,
  });

  /// Factory to construct a SalaryCycle for a given target date.
  /// - From 1 Nov 2026 onwards: Calendar month cycle (1st to last day of month).
  /// - 26 Oct 2026 to 31 Oct 2026: October Transition cycle.
  /// - On or before 25 Oct 2026: Legacy 25th-to-24th cycle.
  factory SalaryCycle.fromDate(DateTime date) {
    final localDate = date.toLocal();
    final int year = localDate.year;
    final int month = localDate.month;
    final int day = localDate.day;

    // From 1 Nov 2026 onwards: calendar month cycle (1st to last day of month)
    if (year > 2026 || (year == 2026 && month >= 11)) {
      return SalaryCycle.forMonth(year, month);
    }

    // October transition window: 26 Oct 2026 to 31 Oct 2026
    if (year == 2026 && month == 10 && day >= 26) {
      return SalaryCycle.octoberTransition();
    }

    // Legacy 25th-to-24th cycle
    if (day >= 25) {
      final start = DateTime(year, month, 25, 0, 0, 0, 0);
      final nextMonthDt = DateTime(year, month + 1, 1);
      final end = (year == 2026 && month == 9)
          ? DateTime(2026, 10, 25, 23, 59, 59, 999)
          : DateTime(nextMonthDt.year, nextMonthDt.month, 24, 23, 59, 59, 999);
      return SalaryCycle(
        startDate: start,
        endDate: end,
        salaryMonth: nextMonthDt.month,
        salaryYear: nextMonthDt.year,
      );
    } else {
      final prevMonthDt = DateTime(year, month - 1, 1);
      final start = DateTime(prevMonthDt.year, prevMonthDt.month, 25, 0, 0, 0, 0);
      final end = (year == 2026 && month == 10)
          ? DateTime(2026, 10, 25, 23, 59, 59, 999)
          : DateTime(year, month, 24, 23, 59, 59, 999);
      return SalaryCycle(
        startDate: start,
        endDate: end,
        salaryMonth: month,
        salaryYear: year,
      );
    }
  }

  /// Current active salary cycle based on now()
  static SalaryCycle current([DateTime? referenceDate]) {
    return SalaryCycle.fromDate(referenceDate ?? DateTime.now());
  }

  /// Construct a SalaryCycle for a specific salary month and year.
  /// - Starting from November 2026: calendar month (01 Nov - 30 Nov 2026, 01 Dec - 31 Dec, etc.)
  /// - October 2026 (legacy): 25 Sep 2026 to 25 Oct 2026.
  /// - September 2026 (legacy): 25 Aug 2026 to 24 Sep 2026.
  factory SalaryCycle.forMonth(int year, int month) {
    if (year > 2026 || (year == 2026 && month >= 11)) {
      final start = DateTime(year, month, 1, 0, 0, 0, 0);
      final end = DateTime(year, month + 1, 0, 23, 59, 59, 999);
      return SalaryCycle(
        startDate: start,
        endDate: end,
        salaryMonth: month,
        salaryYear: year,
      );
    }

    if (year == 2026 && month == 10) {
      final start = DateTime(2026, 9, 25, 0, 0, 0, 0);
      final end = DateTime(2026, 10, 25, 23, 59, 59, 999);
      return SalaryCycle(
        startDate: start,
        endDate: end,
        salaryMonth: 10,
        salaryYear: 2026,
      );
    }

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

  /// October 2026 Transition Period: 26 Oct 2026 – 31 Oct 2026 (Interim Overtime).
  factory SalaryCycle.octoberTransition() {
    return SalaryCycle(
      startDate: DateTime(2026, 10, 26, 0, 0, 0, 0),
      endDate: DateTime(2026, 10, 31, 23, 59, 59, 999),
      salaryMonth: 10,
      salaryYear: 2026,
      isTransition: true,
      customId: '2026-10-transition',
      customTitle: 'Interim OT Cycle (26 Oct - 31 Oct 2026)',
      customShortLabel: '26 Oct - 31 Oct 2026',
    );
  }

  /// Earliest implemented salary cycle in the system (25 Aug 2026 - 24 Sep 2026).
  static const int earliestSalaryYear = 2026;
  static const int earliestSalaryMonth = 9;

  /// Generates a list of recent cycles down to the earliest implemented cycle.
  static List<SalaryCycle> getRecentCycles({int? count, DateTime? referenceDate}) {
    final currentCycle = SalaryCycle.current(referenceDate);
    final List<SalaryCycle> cycles = [];

    int curYear = currentCycle.salaryYear;
    int curMonth = currentCycle.salaryMonth;

    // 1. Calendar month cycles down to Nov 2026
    while (curYear > 2026 || (curYear == 2026 && curMonth >= 11)) {
      cycles.add(SalaryCycle.forMonth(curYear, curMonth));
      if (count != null && cycles.length >= count) return cycles;
      curMonth--;
      if (curMonth < 1) {
        curMonth = 12;
        curYear--;
      }
    }

    // 2. October transition interim OT cycle (26 Oct - 31 Oct 2026)
    cycles.add(SalaryCycle.octoberTransition());
    if (count != null && cycles.length >= count) return cycles;

    // 3. Historical October 2026 (25 Sep - 25 Oct 2026)
    cycles.add(SalaryCycle.forMonth(2026, 10));
    if (count != null && cycles.length >= count) return cycles;

    // 4. Historical September 2026 (25 Aug - 24 Sep 2026)
    cycles.add(SalaryCycle.forMonth(2026, 9));

    return cycles;
  }

  /// Check if a given date falls inside this salary cycle
  bool contains(DateTime date) {
    final t = date.toLocal();
    return !t.isBefore(startDate) && !t.isAfter(endDate);
  }

  /// Unique identifier key for dropdowns or caches (e.g. '2026-11' or '2026-10-transition')
  String get id =>
      customId ??
      (isTransition
          ? '2026-10-transition'
          : '$salaryYear-${salaryMonth.toString().padLeft(2, '0')}');

  /// Title for display: e.g. "November 2026 Cycle (01 Nov - 30 Nov)"
  String get title {
    if (customTitle != null) return customTitle!;
    if (isTransition) {
      return 'Interim OT Cycle (${DateFormat('dd MMM').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)})';
    }
    if (startDate.day == 1) {
      final mName = DateFormat('MMMM yyyy').format(startDate);
      final sStr = DateFormat('dd MMM').format(startDate);
      final eStr = DateFormat('dd MMM').format(endDate);
      return '$mName Cycle ($sStr - $eStr)';
    }
    final startM = DateFormat('MMM').format(startDate);
    final endM = DateFormat('MMM yyyy').format(endDate);
    return '$startM - $endM Cycle (${DateFormat('dd MMM').format(startDate)} - ${DateFormat('dd MMM').format(endDate)})';
  }

  /// Short label: e.g. "01 Nov - 30 Nov 2026"
  String get shortPeriodLabel {
    if (customShortLabel != null) return customShortLabel!;
    return '${DateFormat('dd MMM').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
  }

  /// Official primary salary month name (e.g. "November 2026" or "Interim OT (Oct 2026)")
  String get salaryMonthName {
    if (isTransition) return 'Interim OT (Oct 2026)';
    return DateFormat('MMMM yyyy').format(DateTime(salaryYear, salaryMonth, 1));
  }

  /// 3-letter abbreviation of the salary month (e.g. "Nov" or "OT")
  String get salaryMonthAbbr {
    if (isTransition) return 'OT';
    return DateFormat('MMM').format(DateTime(salaryYear, salaryMonth, 1));
  }

  /// Short format of the salary month (e.g. "Nov 2026" or "Oct OT")
  String get salaryMonthShort {
    if (isTransition) return 'Oct OT';
    return DateFormat('MMM yyyy').format(DateTime(salaryYear, salaryMonth, 1));
  }

  /// Dual-month cycle period name: e.g. "November 2026" or "26-31 Oct OT"
  String get dualMonthName {
    if (isTransition) return '26-31 Oct OT';
    if (startDate.day == 1) {
      return DateFormat('MMMM yyyy').format(startDate);
    }
    final startM = DateFormat('MMM').format(startDate);
    final endM = DateFormat('MMM yyyy').format(endDate);
    return '$startM - $endM';
  }

  /// Full period range string: e.g. "01 Nov 2026 - 30 Nov 2026"
  String get fullPeriodString {
    return '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
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
