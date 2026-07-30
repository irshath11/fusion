import '../../features/attendance/domain/attendance_record.dart';

class ExcelCsvExportService {
  /// Generates CSV data for attendance logs
  static String generateCsv(List<AttendanceRecord> records) {
    StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln("Record ID,Employee ID,Workflow Step,Event Time,Latitude,Longitude,Address,Geofence Valid,Sync Status");

    for (var r in records) {
      csvBuffer.writeln(
        '"${r.id}","${r.employeeId}","${r.workflowStep.name}","${r.eventTimestamp}","${r.latitude}","${r.longitude}","${r.address}","${r.isGeofenceValid}","${r.syncStatus.name}"',
      );
    }
    return csvBuffer.toString();
  }

  /// Simulates Excel workbook generation
  static String generateExcelData(List<AttendanceRecord> records) {
    return generateCsv(records); // Formatted CSV string compatible with Excel imports
  }
}
