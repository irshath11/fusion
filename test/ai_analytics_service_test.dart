import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/services/ai_analytics_service.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';

void main() {
  group('AiAnalyticsService Unit Tests', () {
    final analyticsService = AiAnalyticsService();
    final baseDate = DateTime(2026, 8, 29, 8, 0);

    test('Calculates geofence compliance rate correctly', () {
      final records = [
        AttendanceRecord(
          id: 'rec-1',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: baseDate,
          latitude: 25.2,
          longitude: 55.2,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
        AttendanceRecord(
          id: 'rec-2',
          employeeId: 'emp-1',
          employeeName: 'Alice',
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: baseDate.add(const Duration(hours: 9)),
          latitude: 25.2,
          longitude: 55.2,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: false,
        ),
      ];

      final metrics = analyticsService.computeExecutiveMetrics(records, []);

      // 1 out of 2 valid = 50.0%
      expect(metrics.geofenceComplianceRate, 50.0);
      expect(metrics.totalRecordsCount, 2);
      expect(metrics.insights, isNotEmpty);
    });

    test('Responds to local NLP query for overtime', () async {
      final records = <AttendanceRecord>[];
      final response = await analyticsService.queryAnalyticsWithAi('overtime summary', records);

      expect(response, contains('Overtime Summary'));
    });

    test('Responds to local NLP query for geofence compliance', () async {
      final records = <AttendanceRecord>[];
      final response = await analyticsService.queryAnalyticsWithAi('geofence compliance rate', records);

      expect(response, contains('Geofence Compliance'));
    });
  });
}
