import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/attendance/domain/attendance_record.dart';
import '../utils/timesheet_calculator.dart';

class PdfExportService {
  /// Generates a formatted PDF binary document for cumulative employee hours report
  static Future<Uint8List> buildCumulativePdfBytes({
    required String organizationName,
    required List<dynamic> employees,
    required List<AttendanceRecord> records,
  }) async {
    final pdf = pw.Document();

    double grandReg = 0.0;
    double grandOt = 0.0;

    final List<Map<String, dynamic>> empRows = [];

    for (final emp in employees) {
      final empRecords = records.where((r) {
        return r.employeeId == emp.id ||
            r.employeeName.toLowerCase() == emp.name.toLowerCase();
      }).toList();

      final timesheets = TimesheetCalculator.calculateDailyTimesheets(empRecords);

      double regHours = 0.0;
      double otHours = 0.0;

      for (final t in timesheets) {
        regHours += t.regularHours;
        otHours += t.overtimeHours;
      }

      grandReg += regHours;
      grandOt += otHours;

      empRows.add({
        'code': emp.employeeCode ?? '',
        'name': emp.name ?? '',
        'dept': emp.department ?? 'General',
        'days': timesheets.length,
        'reg': regHours,
        'ot': otHours,
        'combined': regHours + otHours,
      });
    }

    final grandCombined = grandReg + grandOt;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'WORKFORCE CUMULATIVE WORK HOURS REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      organizationName,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Summary Header Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blueGrey200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [
                    pw.Text('Total Employees', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${employees.length}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Total Regular Hours', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${grandReg.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Total Overtime OT', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('+${grandOt.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Grand Combined Hrs', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${grandCombined.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Employee Cumulative Table
            pw.TableHelper.fromTextArray(
              headers: ['Emp Code', 'Employee Name', 'Department', 'Days', 'Regular', 'OT', 'Combined Total'],
              data: empRows.map((row) => [
                row['code'],
                row['name'],
                row['dept'],
                '${row['days']}',
                '${(row['reg'] as double).toStringAsFixed(1)} h',
                '+${(row['ot'] as double).toStringAsFixed(1)} h',
                '${(row['combined'] as double).toStringAsFixed(1)} h',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers native download / print / share dialog for Cumulative PDF File
  static Future<void> downloadCumulativePdfFile({
    required String organizationName,
    required List<dynamic> employees,
    required List<AttendanceRecord> records,
  }) async {
    final pdfBytes = await buildCumulativePdfBytes(
      organizationName: organizationName,
      employees: employees,
      records: records,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Cumulative_Workforce_Attendance_Report.pdf',
    );
  }

  /// Generates a binary PDF document for an individual employee's detailed attendance report
  static Future<Uint8List> buildEmployeeAttendancePdfBytes({
    required String organizationName,
    required dynamic employee,
    required List<AttendanceRecord> records,
  }) async {
    final pdf = pw.Document();
    final timesheets = TimesheetCalculator.calculateDailyTimesheets(records);

    double totalReg = 0.0;
    double totalOt = 0.0;
    for (final t in timesheets) {
      totalReg += t.regularHours;
      totalOt += t.overtimeHours;
    }

    final String empName = employee.name ?? 'Employee';
    final String empCode = employee.employeeCode ?? 'EMP';
    final String department = employee.department ?? 'General';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EMPLOYEE ATTENDANCE & TIMESHEET REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$organizationName • $empName ($empCode)',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Employee Executive Summary Card
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blueGrey200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [
                    pw.Text('Department', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text(department, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Logged Days', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${timesheets.length} Days', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Regular Hours', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${totalReg.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Overtime OT', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('+${totalOt.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Combined Total', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${(totalReg + totalOt).toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Daily Timesheet Logs Table
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'In Time', 'Out Time', 'Regular', 'OT', 'Site / Job Visits', 'Status'],
              data: timesheets.map((entry) {
                final dateStr = DateFormat('yyyy-MM-dd').format(entry.date);
                final inTime = entry.checkInTime != null
                    ? DateFormat('HH:mm').format(entry.checkInTime!)
                    : '--:--';
                final outTime = entry.checkOutTime != null
                    ? DateFormat('HH:mm').format(entry.checkOutTime!)
                    : '--:--';
                final reg = '${entry.regularHours.toStringAsFixed(1)} h';
                final ot = '+${entry.overtimeHours.toStringAsFixed(1)} h';
                final sitesStr = entry.siteVisits.isNotEmpty
                    ? entry.siteVisits.map((sv) => sv.siteName).join(', ')
                    : 'Main Location';
                final status = entry.isCompleted ? 'Complete' : 'In Progress';
                return [dateStr, inTime, outTime, reg, ot, sitesStr, status];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers native download / print for individual Employee PDF
  static Future<void> downloadEmployeeAttendancePdfFile({
    required String organizationName,
    required dynamic employee,
    required List<AttendanceRecord> records,
  }) async {
    final pdfBytes = await buildEmployeeAttendancePdfBytes(
      organizationName: organizationName,
      employee: employee,
      records: records,
    );

    final String rawName = (employee.name ?? 'Employee');
    final safeName = rawName.replaceAll(RegExp(r'[^\w\s]+'), '_');
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${safeName}_Attendance_Report.pdf',
    );
  }

  /// Legacy text-based cumulative generator
  static Future<String> generateCumulativePdfReport({
    required String organizationName,
    required List<dynamic> employees,
    required List<AttendanceRecord> records,
  }) async {
    final pdfBytes = await buildCumulativePdfBytes(
      organizationName: organizationName,
      employees: employees,
      records: records,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Cumulative_Workforce_Attendance_Report.pdf',
    );
    return 'Cumulative PDF report downloaded.';
  }
}
