import '../../features/attendance/domain/attendance_record.dart';
import '../../features/timesheet/domain/timesheet_entry.dart';
import '../constants/app_enums.dart';

class TimesheetCalculator {
  /// Standard max regular work hours per day before overtime applies
  static const double standardRegularHoursPerDay = 8.0;

  /// Calculates daily timesheet entries from raw attendance records for an employee or all employees
  static List<DailyTimesheetEntry> calculateDailyTimesheets(
    List<AttendanceRecord> records, {
    String? targetEmployeeId,
    String? targetFirebaseUid,
    String? targetEmployeeName,
  }) {
    final filteredRecords = records.where((r) {
      if (targetEmployeeId == null || targetEmployeeId.isEmpty) return true;
      final idMatch = r.employeeId == targetEmployeeId ||
          (targetFirebaseUid != null && targetFirebaseUid.isNotEmpty && r.employeeId == targetFirebaseUid);
      final nameMatch = targetEmployeeName != null &&
          targetEmployeeName.isNotEmpty &&
          r.employeeName.trim().toLowerCase() == targetEmployeeName.trim().toLowerCase();
      return idMatch || nameMatch;
    }).toList();

    // Map key: "yyyy-MM-dd"
    final Map<String, List<AttendanceRecord>> groupedMap = {};

    for (final record in filteredRecords) {
      final dateStr =
          "${record.eventTimestamp.year}-${record.eventTimestamp.month.toString().padLeft(2, '0')}-${record.eventTimestamp.day.toString().padLeft(2, '0')}";
      groupedMap.putIfAbsent(dateStr, () => []).add(record);
    }

    final List<DailyTimesheetEntry> entries = [];

    groupedMap.forEach((dateStr, dayRecords) {
      if (dayRecords.isEmpty) return;

      // Sort by timestamp ascending
      dayRecords.sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

      final firstRecord = dayRecords.first;
      final empId = firstRecord.employeeId;
      final empName = firstRecord.employeeName;
      final date = DateTime(
        firstRecord.eventTimestamp.year,
        firstRecord.eventTimestamp.month,
        firstRecord.eventTimestamp.day,
      );

      // 1. Office Check-In as primary start time
      final checkInRecordIndex = dayRecords.indexWhere(
        (r) => r.workflowStep == WorkflowStep.officeCheckIn,
      );
      final checkInRecord = checkInRecordIndex != -1
          ? dayRecords[checkInRecordIndex]
          : dayRecords.firstWhere(
              (r) => r.workflowStep == WorkflowStep.siteCheckIn,
              orElse: () => dayRecords.first,
            );

      // 2. Office Check-Out or Last Site Check-Out as effective end time
      DateTime? checkOutTimestamp;
      final officeOutMatches = dayRecords.where((r) => r.workflowStep == WorkflowStep.officeCheckOut);
      if (officeOutMatches.isNotEmpty) {
        checkOutTimestamp = officeOutMatches.last.eventTimestamp;
      } else {
        final siteOutMatches = dayRecords.where((r) => r.workflowStep == WorkflowStep.siteCheckOut);
        if (siteOutMatches.isNotEmpty) {
          checkOutTimestamp = siteOutMatches.last.eventTimestamp;
        }
      }

      // 3. Build Site Visits List
      final List<SiteVisitSummary> siteVisits = [];
      for (int i = 0; i < dayRecords.length; i++) {
        final r = dayRecords[i];
        if (r.workflowStep == WorkflowStep.siteCheckIn || (r.siteName != null && r.siteName!.trim().isNotEmpty)) {
          final sName = (r.siteName != null && r.siteName!.trim().isNotEmpty) ? r.siteName!.trim() : 'Work Site';
          DateTime sIn = r.eventTimestamp;
          DateTime? sOut;

          // Find matching siteCheckOut
          for (int j = i + 1; j < dayRecords.length; j++) {
            if (dayRecords[j].workflowStep == WorkflowStep.siteCheckOut) {
              sOut = dayRecords[j].eventTimestamp;
              break;
            } else if (dayRecords[j].workflowStep == WorkflowStep.siteCheckIn) {
              // Intervening site check-in without explicit check-out
              break;
            }
          }

          if (!siteVisits.any((sv) => sv.siteName == sName && sv.checkInTime == sIn)) {
            siteVisits.add(SiteVisitSummary(
              siteName: sName,
              checkInTime: sIn,
              checkOutTime: sOut,
            ));
          }
        }
      }

      final DateTime? checkInTimestamp = checkInRecord.eventTimestamp;
      final DateTime effectiveEnd = checkOutTimestamp ?? DateTime.now();

      Duration totalWorkedDuration = Duration.zero;
      if (checkInTimestamp != null && effectiveEnd.isAfter(checkInTimestamp)) {
        totalWorkedDuration = effectiveEnd.difference(checkInTimestamp);
      }

      final totalHours = totalWorkedDuration.inMinutes / 60.0;
      double regularHours = 0.0;
      double overtimeHours = 0.0;

      if (totalHours > 0) {
        if (totalHours <= standardRegularHoursPerDay) {
          regularHours = totalHours;
          overtimeHours = 0.0;
        } else {
          regularHours = standardRegularHoursPerDay;
          overtimeHours = totalHours - standardRegularHoursPerDay;
        }
      }

      final bool isCompleted = dayRecords.any((r) => r.workflowStep == WorkflowStep.officeCheckOut);

      entries.add(
        DailyTimesheetEntry(
          date: date,
          employeeId: empId,
          employeeName: empName,
          checkInTime: checkInTimestamp,
          checkOutTime: checkOutTimestamp,
          totalDuration: totalWorkedDuration,
          regularHours: regularHours,
          overtimeHours: overtimeHours,
          stepCount: dayRecords.length,
          isCompleted: isCompleted,
          siteVisits: siteVisits,
        ),
      );
    });

    // Sort entries by date descending
    entries.sort((a, b) => b.date.compareTo(a.date));

    return entries;
  }
}
