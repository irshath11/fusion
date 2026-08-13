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
            pw.SizedBox(height: 16),

            // Site / Client Man-Hours Breakdown in Cumulative Report
            () {
              final siteSummaries = TimesheetCalculator.calculateSiteManHours(records);
              final totalSiteHours = siteSummaries.fold(0.0, (acc, s) => acc + s.totalHours);

              if (siteSummaries.isEmpty) return pw.SizedBox.shrink();

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SITE & CLIENT MAN-HOURS BREAKDOWN',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.TableHelper.fromTextArray(
                    headers: ['Site / Client Name', 'Category', 'Total Man-Hours', '% Share', 'Visits', 'Personnel Count'],
                    data: siteSummaries.map((s) {
                      final pct = totalSiteHours > 0 ? (s.totalHours / totalSiteHours * 100).toStringAsFixed(1) : '0.0';
                      return [
                        s.siteName,
                        s.clientGroup,
                        '${s.totalHours.toStringAsFixed(1)} hrs',
                        '$pct%',
                        '${s.totalVisits}',
                        '${s.distinctEmployeesCount} Staff',
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                    cellStyle: const pw.TextStyle(fontSize: 8.5),
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
                ],
              );
            }(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a dedicated binary PDF document for Site & Client Man-Hours Report
  static Future<Uint8List> buildSiteManHoursPdfBytes({
    required String organizationName,
    required List<AttendanceRecord> records,
    DateTime? startDate,
    DateTime? endDate,
    bool groupByClient = false,
  }) async {
    final pdf = pw.Document();

    final summaries = TimesheetCalculator.calculateSiteManHours(
      records,
      startDate: startDate,
      endDate: endDate,
      groupByClient: groupByClient,
    );

    final totalManHours = summaries.fold(0.0, (acc, s) => acc + s.totalHours);
    final totalVisits = summaries.fold(0, (acc, s) => acc + s.totalVisits);
    final topSite = summaries.isNotEmpty ? summaries.first.siteName : 'None';

    String periodStr = 'All Recorded Time';
    if (startDate != null && endDate != null) {
      periodStr = '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
    } else if (startDate != null) {
      periodStr = 'From ${DateFormat('dd MMM yyyy').format(startDate)}';
    }

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
                      groupByClient
                          ? 'CLIENT MAN-HOURS EXECUTIVE REPORT'
                          : 'SITE & CLIENT MAN-HOURS DETAILED REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$organizationName • Period: $periodStr',
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
                    pw.Text('Total Site Man-Hours', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${totalManHours.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Active Sites/Clients', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${summaries.length}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Total Site Visits', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('$totalVisits', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Top Client / Site', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text(topSite, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Site & Client Table
            pw.TableHelper.fromTextArray(
              headers: ['Site / Client Name', 'Category', 'Total Man-Hours', '% Share', 'Visits', 'Staff Count', 'Top Contributing Personnel'],
              data: summaries.map((s) {
                final pct = totalManHours > 0 ? (s.totalHours / totalManHours * 100).toStringAsFixed(1) : '0.0';
                final topStaff = s.employeeContributions
                    .take(2)
                    .map((e) => '${e.employeeName} (${e.totalHours.toStringAsFixed(1)}h)')
                    .join(', ');

                return [
                  s.siteName,
                  s.clientGroup,
                  '${s.totalHours.toStringAsFixed(1)} hrs',
                  '$pct%',
                  '${s.totalVisits}',
                  '${s.distinctEmployeesCount}',
                  topStaff.isNotEmpty ? topStaff : '--',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers native download / print / share dialog for Site Man-Hours PDF
  static Future<void> downloadSiteManHoursPdfFile({
    required String organizationName,
    required List<AttendanceRecord> records,
    DateTime? startDate,
    DateTime? endDate,
    bool groupByClient = false,
  }) async {
    final pdfBytes = await buildSiteManHoursPdfBytes(
      organizationName: organizationName,
      records: records,
      startDate: startDate,
      endDate: endDate,
      groupByClient: groupByClient,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Site_and_Client_Man_Hours_Report.pdf',
    );
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
    int totalBreakMinutes = 0;
    for (final t in timesheets) {
      totalReg += t.regularHours;
      totalOt += t.overtimeHours;
      totalBreakMinutes += t.breakDuration.inMinutes;
    }

    final String empName = employee.name ?? 'Employee';
    final String empCode = employee.employeeCode ?? 'EMP';
    final String department = employee.department ?? 'General';
    final String empId = employee.id ?? '';

    final employeeSiteHours = TimesheetCalculator.calculateEmployeeSiteHours(empId, records);

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
                    pw.Text(department, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Logged Days', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${timesheets.length} Days', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Regular Hours', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${totalReg.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Overtime OT', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('+${totalOt.toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                  ]),
                  if (totalBreakMinutes > 0)
                    pw.Column(children: [
                      pw.Text('Total Break', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('${totalBreakMinutes}m', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                    ]),
                  pw.Column(children: [
                    pw.Text('Net Working', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${(totalReg + totalOt).toStringAsFixed(1)} hrs', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Daily Timesheet Logs Table
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'In Time', 'Out Time', 'Regular', 'OT', 'Break', 'Site / Job Visits', 'Status'],
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
                final breakStr = entry.breakDuration > Duration.zero
                    ? '${entry.breakDuration.inMinutes}m'
                    : '--';
                final dayRecs = records.where((r) {
                  final rDate = DateFormat('yyyy-MM-dd').format(r.eventTimestamp);
                  return rDate == dateStr;
                }).toList();
                final resolvedSites = dayRecs
                    .map((r) => TimesheetCalculator.resolveSiteName(r))
                    .toSet()
                    .where((s) => s.isNotEmpty && s != 'Work Site')
                    .join(', ');
                final sitesStr = entry.siteVisits.isNotEmpty
                    ? entry.siteVisits.map((sv) => sv.siteName).join(', ')
                    : (resolvedSites.isNotEmpty ? resolvedSites : 'Main Office');
                final status = entry.isCompleted ? 'Complete' : 'In Progress';
                return [dateStr, inTime, outTime, reg, ot, breakStr, sitesStr, status];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
              cellAlignment: pw.Alignment.centerLeft,
            ),

            if (employeeSiteHours.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'SITE & CLIENT HOURS SUMMARY FOR ${empName.toUpperCase()}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Site / Client Name', 'Category', 'Logged Hours'],
                data: employeeSiteHours.entries.map((e) {
                  return [
                    e.key,
                    TimesheetCalculator.resolveClientGroup(e.key),
                    '${e.value.toStringAsFixed(1)} hrs',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
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

