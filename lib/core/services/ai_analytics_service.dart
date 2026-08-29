import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/admin/domain/employee_entity.dart';
import '../../features/attendance/domain/attendance_record.dart';
import '../utils/timesheet_calculator.dart';

enum InsightSeverity { info, warning, success }

class AiInsightBullet {
  final String title;
  final String description;
  final InsightSeverity severity;

  AiInsightBullet({
    required this.title,
    required this.description,
    required this.severity,
  });
}

class ExecutiveAnalyticsMetrics {
  final double geofenceComplianceRate; // Percentage (e.g. 96.5)
  final int totalRecordsCount;
  final int overtimeSpikeCount;
  final int unclosedShiftCount;
  final double totalManHours;
  final double averageDailyHours;
  final List<AiInsightBullet> insights;

  ExecutiveAnalyticsMetrics({
    required this.geofenceComplianceRate,
    required this.totalRecordsCount,
    required this.overtimeSpikeCount,
    required this.unclosedShiftCount,
    required this.totalManHours,
    required this.averageDailyHours,
    required this.insights,
  });
}

class AiAnalyticsService {
  static const String _defaultApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Computes structured executive analytics, geofence compliance, and anomaly flags locally.
  ExecutiveAnalyticsMetrics computeExecutiveMetrics(
    List<AttendanceRecord> records,
    List<EmployeeEntity> employees,
  ) {
    if (records.isEmpty) {
      return ExecutiveAnalyticsMetrics(
        geofenceComplianceRate: 100.0,
        totalRecordsCount: 0,
        overtimeSpikeCount: 0,
        unclosedShiftCount: 0,
        totalManHours: 0.0,
        averageDailyHours: 0.0,
        insights: [
          AiInsightBullet(
            title: 'No Active Attendance Records',
            description:
                'Logging attendance records will enable AI analytics and anomaly detection.',
            severity: InsightSeverity.info,
          ),
        ],
      );
    }

    // 1. Geofence Compliance Rate
    int geofenceValidCount = 0;
    for (final r in records) {
      if (r.isGeofenceValid) geofenceValidCount++;
    }
    final geofenceComplianceRate =
        (geofenceValidCount / records.length) * 100.0;

    // 2. Timesheet calculation via TimesheetCalculator
    final dailyEntries = TimesheetCalculator.calculateDailyTimesheets(records);

    double totalHoursSum = 0.0;
    int overtimeSpikes = 0;
    int unclosedShifts = 0;

    for (final entry in dailyEntries) {
      totalHoursSum += entry.totalHours;
      if (entry.overtimeHours >= 2.0) {
        overtimeSpikes++;
      }
      if (!entry.isCompleted && entry.checkInTime != null) {
        final hoursSinceCheckIn =
            DateTime.now().difference(entry.checkInTime!).inHours;
        if (hoursSinceCheckIn >= 24) {
          unclosedShifts++;
        }
      }
    }

    final avgDailyHours = dailyEntries.isNotEmpty
        ? (totalHoursSum / dailyEntries.length)
        : 0.0;

    // 3. Generate Insight Bullets
    final List<AiInsightBullet> insights = [];

    // Geofence insight
    if (geofenceComplianceRate >= 95.0) {
      insights.add(AiInsightBullet(
        title: 'High Geofence Compliance (${geofenceComplianceRate.toStringAsFixed(1)}%)',
        description:
            'Field employees are consistently checking in within designated GPS work site radii.',
        severity: InsightSeverity.success,
      ));
    } else if (geofenceComplianceRate >= 80.0) {
      insights.add(AiInsightBullet(
        title: 'Moderate Geofence Adherence (${geofenceComplianceRate.toStringAsFixed(1)}%)',
        description:
            'Some check-in records occurred outside geofenced boundaries.',
        severity: InsightSeverity.info,
      ));
    } else {
      insights.add(AiInsightBullet(
        title: 'Geofence Compliance Alert (${geofenceComplianceRate.toStringAsFixed(1)}%)',
        description:
            'Multiple check-ins occurred outside geofenced work site perimeters.',
        severity: InsightSeverity.warning,
      ));
    }

    // Overtime insight
    if (overtimeSpikes > 0) {
      insights.add(AiInsightBullet(
        title: '$overtimeSpikes Overtime Spike(s) Detected',
        description:
            '$overtimeSpikes shift(s) exceeded 2+ hours of overtime. Consider reviewing resource allocation.',
        severity: InsightSeverity.warning,
      ));
    } else {
      insights.add(AiInsightBullet(
        title: 'Optimal Working Hours',
        description:
            'No excessive overtime spikes recorded in the current period.',
        severity: InsightSeverity.success,
      ));
    }

    // Unclosed shifts insight
    if (unclosedShifts > 0) {
      insights.add(AiInsightBullet(
        title: '$unclosedShifts Unclosed Active Shift(s) (>24h)',
        description:
            '$unclosedShifts shift(s) remain open beyond 24 hours and will auto-cap at 8.0 regular hours.',
        severity: InsightSeverity.warning,
      ));
    }

    return ExecutiveAnalyticsMetrics(
      geofenceComplianceRate: geofenceComplianceRate,
      totalRecordsCount: records.length,
      overtimeSpikeCount: overtimeSpikes,
      unclosedShiftCount: unclosedShifts,
      totalManHours: double.parse(totalHoursSum.toStringAsFixed(1)),
      averageDailyHours: double.parse(avgDailyHours.toStringAsFixed(1)),
      insights: insights,
    );
  }

  /// Answers freeform natural language queries about attendance analytics using Gemini AI (or local fallback).
  Future<String> queryAnalyticsWithAi(
    String userQuery,
    List<AttendanceRecord> records, {
    String? customApiKey,
  }) async {
    final query = userQuery.trim();
    if (query.isEmpty) {
      return 'Please type a question or search query for AI analytics.';
    }

    final apiKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : _defaultApiKey;

    final metrics = computeExecutiveMetrics(records, []);

    if (apiKey.isNotEmpty) {
      try {
        final answer = await _queryGemini(query, metrics, records, apiKey);
        if (answer != null && answer.isNotEmpty) return answer;
      } catch (e) {
        debugPrint('Gemini Analytics Query Note: $e');
      }
    }

    // Local Fallback NLP Query Matcher
    return _queryLocally(query, metrics, records);
  }

  Future<String?> _queryGemini(
    String query,
    ExecutiveAnalyticsMetrics metrics,
    List<AttendanceRecord> records,
    String apiKey,
  ) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final summaryContext = '''
Organization Attendance Summary:
- Total Attendance Records: ${metrics.totalRecordsCount}
- Geofence Compliance Rate: ${metrics.geofenceComplianceRate.toStringAsFixed(1)}%
- Total Man-Hours: ${metrics.totalManHours} hours
- Average Daily Hours/Shift: ${metrics.averageDailyHours} hours
- Overtime Spikes (>2h OT): ${metrics.overtimeSpikeCount}
- Unclosed Active Shifts (>24h): ${metrics.unclosedShiftCount}

Recent Record Samples:
${records.take(15).map((r) => "- ${r.employeeName} (${r.workflowStep.name}) at ${r.siteName ?? r.address} on ${r.eventTimestamp.toIso8601String()} [Geofence: ${r.isGeofenceValid ? 'Valid' : 'Invalid'}]").join('\n')}
''';

    final prompt = '''
You are an executive AI workforce analyst for Fusion 360 app.
Answer the executive admin's query concise, professional, and directly using the data summary provided.

Data Summary:
$summaryContext

Admin Query:
"$query"
''';

    final response = await model.generateContent([Content.text(prompt)]);
    return response.text?.trim();
  }

  String _queryLocally(
    String query,
    ExecutiveAnalyticsMetrics metrics,
    List<AttendanceRecord> records,
  ) {
    final qLower = query.toLowerCase();

    if (qLower.contains('overtime') || qLower.contains('ot')) {
      if (metrics.overtimeSpikeCount > 0) {
        return '⚠️ Overtime Summary: ${metrics.overtimeSpikeCount} shift(s) exceeded 2+ hours of overtime out of ${metrics.totalRecordsCount} total records. Total man-hours logged: ${metrics.totalManHours} hrs.';
      }
      return '✅ Overtime Summary: No excessive overtime spikes detected. All shift durations are within standard working limits.';
    }

    if (qLower.contains('geofence') || qLower.contains('gps') || qLower.contains('location')) {
      return '📍 Geofence Compliance: The overall GPS geofence compliance rate is ${metrics.geofenceComplianceRate.toStringAsFixed(1)}% across ${metrics.totalRecordsCount} check-in events.';
    }

    if (qLower.contains('unclosed') || qLower.contains('active') || qLower.contains('open')) {
      if (metrics.unclosedShiftCount > 0) {
        return '🚨 Unclosed Shifts: ${metrics.unclosedShiftCount} active shift(s) have been open for over 24 hours without checkout. They will automatically cap at 8.0 regular hours.';
      }
      return '✅ Shift Status: All completed shifts have been properly checked out with zero expired active shifts.';
    }

    if (qLower.contains('hour') || qLower.contains('total') || qLower.contains('average')) {
      return '⏱️ Labor Hours Summary: Total accumulated man-hours are ${metrics.totalManHours} hrs across completed shifts, with an average daily shift length of ${metrics.averageDailyHours} hrs.';
    }

    return '📊 Executive Overview: Total Records: ${metrics.totalRecordsCount} | Geofence Compliance: ${metrics.geofenceComplianceRate.toStringAsFixed(1)}% | Total Hours: ${metrics.totalManHours} hrs | Overtime Spikes: ${metrics.overtimeSpikeCount}.';
  }
}
