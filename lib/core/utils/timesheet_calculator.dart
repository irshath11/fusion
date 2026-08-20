import '../../database/local_database_service.dart';
import '../../features/attendance/domain/attendance_record.dart';
import '../../features/timesheet/domain/timesheet_entry.dart';
import '../constants/app_enums.dart';

class TimesheetCalculator {
  /// Standard max regular work hours per day before overtime applies
  static const double standardRegularHoursPerDay = 8.0;

  /// Resolves exact human-readable site or location name for an attendance record
  static String resolveSiteName(AttendanceRecord r) {
    if (r.siteName != null && r.siteName!.trim().isNotEmpty) {
      return r.siteName!.trim();
    }
    final db = LocalDatabaseService();
    if (r.workSiteId != null && r.workSiteId!.isNotEmpty) {
      final siteMatches = db.getWorkSites().where((w) => w.id == r.workSiteId);
      if (siteMatches.isNotEmpty) {
        return siteMatches.first.siteName;
      }
    }
    if (r.officeId != null && r.officeId!.isNotEmpty) {
      final officeMatches = db.getOffices().where((o) => o.id == r.officeId);
      if (officeMatches.isNotEmpty) {
        return officeMatches.first.name;
      }
    }
    if (r.address.trim().isNotEmpty &&
        !r.address.contains('Live Field Location') &&
        !r.address.contains('Timeout') &&
        !r.address.contains('Error')) {
      return r.address.trim();
    }
    final empMatches = db.getEmployees().where((e) => e.id == r.employeeId);
    if (empMatches.isNotEmpty) {
      final emp = empMatches.first;
      if (emp.assignedOfficeName != null && emp.assignedOfficeName!.isNotEmpty) {
        return emp.assignedOfficeName!;
      }
    }
    if (r.workflowStep == WorkflowStep.officeCheckIn ||
        r.workflowStep == WorkflowStep.officeCheckOut) {
      return 'Main Office';
    }
    return 'Work Site';
  }

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

      // 3. Calculate Total Break Duration for this day
      Duration totalBreakDuration = Duration.zero;
      for (int i = 0; i < dayRecords.length; i++) {
        final r = dayRecords[i];
        if (r.workflowStep == WorkflowStep.breakStart) {
          DateTime bStart = r.eventTimestamp;
          DateTime? bEnd;
          for (int j = i + 1; j < dayRecords.length; j++) {
            final nextStep = dayRecords[j].workflowStep;
            if (nextStep == WorkflowStep.breakEnd ||
                nextStep == WorkflowStep.officeCheckOut) {
              bEnd = dayRecords[j].eventTimestamp;
              break;
            }
          }
          if (bEnd == null) {
            if (checkOutTimestamp != null && checkOutTimestamp.isAfter(bStart)) {
              bEnd = checkOutTimestamp;
            } else if (DateTime.now().difference(bStart).inHours < 24) {
              bEnd = DateTime.now();
            }
          }
          if (bEnd != null && bEnd.isAfter(bStart)) {
            totalBreakDuration += bEnd.difference(bStart);
          }
        }
      }

      // 4. Build Site Visits List (excluding any breaks during site visits)
      final List<SiteVisitSummary> siteVisits = [];
      for (int i = 0; i < dayRecords.length; i++) {
        final r = dayRecords[i];
        if (r.workflowStep == WorkflowStep.siteCheckIn) {
          final sName = resolveSiteName(r);
          DateTime sIn = r.eventTimestamp;
          DateTime? sOut;

          // Find matching siteCheckOut or next workflow step
          for (int j = i + 1; j < dayRecords.length; j++) {
            final nextStep = dayRecords[j].workflowStep;
            if (nextStep == WorkflowStep.siteCheckOut ||
                nextStep == WorkflowStep.siteCheckIn ||
                nextStep == WorkflowStep.officeCheckOut) {
              sOut = dayRecords[j].eventTimestamp;
              break;
            }
          }

          if (sOut == null) {
            if (checkOutTimestamp != null && checkOutTimestamp.isAfter(sIn)) {
              sOut = checkOutTimestamp;
            } else if (DateTime.now().difference(sIn).inHours < 24) {
              sOut = DateTime.now();
            }
          }

          siteVisits.add(SiteVisitSummary(
            siteName: sName,
            checkInTime: sIn,
            checkOutTime: sOut,
          ));
        }
      }

      final DateTime? checkInTimestamp = checkInRecord.eventTimestamp;
      final bool hasExplicitOfficeCheckOut = officeOutMatches.isNotEmpty;
      final bool isPreviouslyAutoCompleted = officeOutMatches.any((r) =>
          r.address.contains('Auto Check-Out') ||
          (r.siteName != null && r.siteName!.contains('Auto Completed')));

      bool isAutoCompleted = isPreviouslyAutoCompleted;
      bool isCompleted = hasExplicitOfficeCheckOut;

      Duration netWorkedDuration = Duration.zero;
      Duration finalBreakDuration = totalBreakDuration;
      Duration travelToleranceDuration = Duration.zero;
      double regularHours = 0.0;
      double overtimeHours = 0.0;

      if (checkInTimestamp != null) {
        final now = DateTime.now();
        final elapsedSinceCheckIn = now.difference(checkInTimestamp);

        // If no explicit office check-out and elapsed time crosses 24 hours:
        // Automatically capture data after 8 hrs from check-in time, complete only regular time (8h), and check out.
        if (!hasExplicitOfficeCheckOut && elapsedSinceCheckIn >= const Duration(hours: 24)) {
          checkOutTimestamp = checkInTimestamp.add(const Duration(hours: 8));
          netWorkedDuration = const Duration(hours: 8);
          finalBreakDuration = Duration.zero;
          travelToleranceDuration = Duration.zero;
          regularHours = standardRegularHoursPerDay;
          overtimeHours = 0.0;
          isCompleted = true;
          isAutoCompleted = true;
        } else {
          final DateTime effectiveEnd = checkOutTimestamp ?? now;
          Duration grossDuration = Duration.zero;
          if (effectiveEnd.isAfter(checkInTimestamp)) {
            grossDuration = effectiveEnd.difference(checkInTimestamp);
          }

          if (isPreviouslyAutoCompleted) {
            netWorkedDuration = const Duration(hours: 8);
            finalBreakDuration = Duration.zero;
            travelToleranceDuration = Duration.zero;
            regularHours = standardRegularHoursPerDay;
            overtimeHours = 0.0;
          } else {
            final int grossMins = grossDuration.inMinutes;
            final int loggedBreakMins = totalBreakDuration.inMinutes;

            if (grossMins <= 480) {
              // Up to 8.0 hours gross: regular duty only
              final int breakMins = loggedBreakMins;
              final int netMins = (grossMins > breakMins) ? (grossMins - breakMins) : 0;
              netWorkedDuration = Duration(minutes: netMins);
              finalBreakDuration = Duration(minutes: breakMins);
              travelToleranceDuration = Duration.zero;
              regularHours = netMins / 60.0;
              overtimeHours = 0.0;
            } else {
              // Beyond 8.0 hours gross:
              // 1. Default Food Break: 1 hour (60 mins) or logged break if greater
              const int defaultFoodBreakMins = 60;
              final int effectiveFoodBreakMins = loggedBreakMins > defaultFoodBreakMins
                  ? loggedBreakMins
                  : defaultFoodBreakMins;
              finalBreakDuration = Duration(minutes: effectiveFoodBreakMins);

              // 2. Regular Hours: Capped at 8.0 hours (480 mins)
              regularHours = standardRegularHoursPerDay;
              const int regularMins = 480;

              // 3. Remaining minutes after 8h regular and food break
              final int remainingMins = (grossMins > (regularMins + effectiveFoodBreakMins))
                  ? (grossMins - regularMins - effectiveFoodBreakMins)
                  : 0;

              // 4. Travel Tolerance: Up to 1 hour (60 mins)
              final int travelMins = remainingMins > 60 ? 60 : remainingMins;
              travelToleranceDuration = Duration(minutes: travelMins);

              // 5. Overtime: Starts after 10 gross hours (8h regular + 1h food break + 1h travel tolerance)
              final int otMins = (remainingMins > travelMins) ? (remainingMins - travelMins) : 0;
              overtimeHours = otMins / 60.0;

              // 6. Net Worked Duration = Regular (8h) + Overtime
              netWorkedDuration = Duration(minutes: regularMins + otMins);
            }
          }
        }
      }

      entries.add(
        DailyTimesheetEntry(
          date: date,
          employeeId: empId,
          employeeName: empName,
          checkInTime: checkInTimestamp,
          checkOutTime: checkOutTimestamp,
          totalDuration: netWorkedDuration,
          breakDuration: finalBreakDuration,
          travelToleranceDuration: travelToleranceDuration,
          regularHours: regularHours,
          overtimeHours: overtimeHours,
          stepCount: dayRecords.length,
          isCompleted: isCompleted,
          isAutoCompleted: isAutoCompleted,
          siteVisits: siteVisits,
        ),
      );
    });

    // Sort entries by date descending
    entries.sort((a, b) => b.date.compareTo(a.date));

    return entries;
  }

  /// Resolves the standardized client group name from a site name (e.g. Reelam, Carrier, Mopa, MPM, ELV, Others)
  static String resolveClientGroup(String siteName) {
    final clean = siteName.trim();
    if (clean.isEmpty) return 'General';

    final upper = clean.toUpperCase();
    if (upper.contains('RELAAM') || upper.contains('REELAM')) {
      return 'REELAM';
    } else if (upper.contains('CARRIER')) {
      return 'CARRIER';
    } else if (upper.contains('MOPA')) {
      return 'MOPA';
    } else if (upper.contains('MPM')) {
      return 'MPM';
    } else if (upper.contains('ELV')) {
      return 'ELV';
    } else if (upper.contains('OTHERS')) {
      return 'OTHERS';
    }

    final db = LocalDatabaseService();
    final siteMatches = db.getWorkSites().where((w) =>
        w.siteName.toLowerCase() == clean.toLowerCase() ||
        clean.toLowerCase().contains(w.siteName.toLowerCase()));
    if (siteMatches.isNotEmpty && siteMatches.first.clientName.trim().isNotEmpty) {
      return siteMatches.first.clientName.trim().toUpperCase();
    }

    if (clean.contains('(')) {
      return clean.split('(').first.trim().toUpperCase();
    }
    if (clean.contains('-')) {
      return clean.split('-').first.trim().toUpperCase();
    }

    return clean.toUpperCase();
  }

  /// Calculates aggregated site man-hours across all attendance records, with optional date range & client grouping
  static List<SiteManHourSummary> calculateSiteManHours(
    List<AttendanceRecord> records, {
    DateTime? startDate,
    DateTime? endDate,
    bool groupByClient = false,
  }) {
    final db = LocalDatabaseService();
    final allEmployees = db.getEmployees();
    final Map<String, dynamic> empLookup = {
      for (final e in allEmployees) e.id: e,
    };

    // Filter records by date range if specified
    final filtered = records.where((r) {
      if (startDate != null) {
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        if (r.eventTimestamp.isBefore(start)) return false;
      }
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (r.eventTimestamp.isAfter(end)) return false;
      }
      return true;
    }).toList();

    // Group records by (employeeId + date) to process each day session
    final Map<String, List<AttendanceRecord>> dailySessionMap = {};
    for (final r in filtered) {
      final dateKey =
          "${r.employeeId}_${r.eventTimestamp.year}-${r.eventTimestamp.month.toString().padLeft(2, '0')}-${r.eventTimestamp.day.toString().padLeft(2, '0')}";
      dailySessionMap.putIfAbsent(dateKey, () => []).add(r);
    }

    // Accumulator map: key is (groupByClient ? clientGroup : siteName)
    final Map<String, _SiteAcc> accMap = {};

    dailySessionMap.forEach((_, dayRecords) {
      if (dayRecords.isEmpty) return;
      dayRecords.sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

      final firstRecord = dayRecords.first;
      final empId = firstRecord.employeeId;
      final empName = firstRecord.employeeName;
      final empEntity = empLookup[empId];
      final empCode = empEntity != null
          ? empEntity.employeeCode
          : (empId.length >= 4 ? 'EMP-${empId.substring(0, 4).toUpperCase()}' : 'EMP');
      final department = empEntity != null ? empEntity.department : 'Operations';

      DateTime? checkOutTimestamp;
      final officeOutMatches =
          dayRecords.where((r) => r.workflowStep == WorkflowStep.officeCheckOut);
      if (officeOutMatches.isNotEmpty) {
        checkOutTimestamp = officeOutMatches.last.eventTimestamp;
      } else {
        final siteOutMatches =
            dayRecords.where((r) => r.workflowStep == WorkflowStep.siteCheckOut);
        if (siteOutMatches.isNotEmpty) {
          checkOutTimestamp = siteOutMatches.last.eventTimestamp;
        }
      }

      for (int i = 0; i < dayRecords.length; i++) {
        final r = dayRecords[i];
        if (r.workflowStep == WorkflowStep.siteCheckIn) {
          final sName = resolveSiteName(r);
          final cGroup = resolveClientGroup(sName);
          final key = groupByClient ? cGroup : sName;

          DateTime sIn = r.eventTimestamp;
          DateTime? sOut;

          for (int j = i + 1; j < dayRecords.length; j++) {
            final nextStep = dayRecords[j].workflowStep;
            if (nextStep == WorkflowStep.siteCheckOut ||
                nextStep == WorkflowStep.siteCheckIn ||
                nextStep == WorkflowStep.officeCheckOut) {
              sOut = dayRecords[j].eventTimestamp;
              break;
            }
          }

          if (sOut == null) {
            if (checkOutTimestamp != null && checkOutTimestamp.isAfter(sIn)) {
              sOut = checkOutTimestamp;
            } else if (DateTime.now().difference(sIn).inHours < 24) {
              sOut = DateTime.now();
            } else {
              sOut = sIn.add(const Duration(hours: 4));
            }
          }

          // Calculate any breaks that occurred during this site session
          Duration siteBreak = Duration.zero;
          for (int b = 0; b < dayRecords.length; b++) {
            if (dayRecords[b].workflowStep == WorkflowStep.breakStart) {
              DateTime bStart = dayRecords[b].eventTimestamp;
              DateTime? bEnd;
              for (int k = b + 1; k < dayRecords.length; k++) {
                final nextStep = dayRecords[k].workflowStep;
                if (nextStep == WorkflowStep.breakEnd ||
                    nextStep == WorkflowStep.siteCheckOut ||
                    nextStep == WorkflowStep.officeCheckOut) {
                  bEnd = dayRecords[k].eventTimestamp;
                  break;
                }
              }
              bEnd ??= sOut;
              final overlapStart = bStart.isAfter(sIn) ? bStart : sIn;
              final overlapEnd = bEnd.isBefore(sOut) ? bEnd : sOut;
              if (overlapEnd.isAfter(overlapStart)) {
                siteBreak += overlapEnd.difference(overlapStart);
              }
            }
          }

          final diff = sOut.difference(sIn);
          final netSiteDuration = diff > siteBreak ? (diff - siteBreak) : Duration.zero;
          final durationHours = (netSiteDuration.inMinutes / 60.0).clamp(0.0, 24.0);

          final acc = accMap.putIfAbsent(
            key,
            () => _SiteAcc(
              name: key,
              clientGroup: cGroup,
            ),
          );

          acc.totalHours += durationHours;
          acc.totalVisits += 1;

          final empAcc = acc.empContributions.putIfAbsent(
            empId,
            () => _EmpContributionAcc(
              employeeId: empId,
              employeeName: empName,
              employeeCode: empCode,
              department: department,
            ),
          );

          empAcc.totalHours += durationHours;
          empAcc.visitCount += 1;
        }
      }
    });

    final List<SiteManHourSummary> summaries = [];
    accMap.forEach((key, acc) {
      final contributions = acc.empContributions.values
          .map((e) => SiteEmployeeContribution(
                employeeId: e.employeeId,
                employeeName: e.employeeName,
                employeeCode: e.employeeCode,
                department: e.department,
                totalHours: e.totalHours,
                visitCount: e.visitCount,
              ))
          .toList()
        ..sort((a, b) => b.totalHours.compareTo(a.totalHours));

      summaries.add(
        SiteManHourSummary(
          siteName: acc.name,
          clientGroup: acc.clientGroup,
          totalHours: acc.totalHours,
          totalVisits: acc.totalVisits,
          distinctEmployeesCount: contributions.length,
          employeeContributions: contributions,
        ),
      );
    });

    // Sort by total hours descending
    summaries.sort((a, b) => b.totalHours.compareTo(a.totalHours));
    return summaries;
  }

  /// Calculates individual employee site hours breakdown
  static Map<String, double> calculateEmployeeSiteHours(
    String employeeId,
    List<AttendanceRecord> records,
  ) {
    final empRecords = records
        .where((r) =>
            r.employeeId == employeeId ||
            r.employeeName.toLowerCase() == employeeId.toLowerCase())
        .toList();

    final summaries = calculateSiteManHours(empRecords);

    final Map<String, double> result = {};
    for (final s in summaries) {
      result[s.siteName] = s.totalHours;
    }
    return result;
  }
}

class _SiteAcc {
  final String name;
  final String clientGroup;
  double totalHours = 0.0;
  int totalVisits = 0;
  final Map<String, _EmpContributionAcc> empContributions = {};

  _SiteAcc({
    required this.name,
    required this.clientGroup,
  });
}

class _EmpContributionAcc {
  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final String department;
  double totalHours = 0.0;
  int visitCount = 0;

  _EmpContributionAcc({
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.department,
  });
}

