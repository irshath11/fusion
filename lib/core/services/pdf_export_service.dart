import '../../features/attendance/domain/attendance_record.dart';

class PdfExportService {
  /// Generates a PDF attendance report string/document
  static Future<String> generateAttendancePdfReport({
    required String organizationName,
    required List<AttendanceRecord> records,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln("=================================================");
    buffer.writeln("ATTENDANCE & WORKFORCE REPORT - $organizationName");
    buffer.writeln("Generated On: ${DateTime.now().toIso8601String()}");
    buffer.writeln("=================================================\n");

    for (var record in records) {
      buffer.writeln("Employee Code: ${record.employeeId}");
      buffer.writeln("Step: ${record.workflowStep.name}");
      buffer.writeln("Event Time: ${record.eventTimestamp}");
      buffer.writeln("Location: ${record.latitude}, ${record.longitude}");
      buffer
          .writeln("Geofence Valid: ${record.isGeofenceValid ? 'YES' : 'NO'}");
      buffer.writeln("Sync Status: ${record.syncStatus.name}");
      buffer.writeln("-------------------------------------------------");
    }

    return buffer.toString();
  }
}
